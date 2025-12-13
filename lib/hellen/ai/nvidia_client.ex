defmodule Hellen.AI.NvidiaClient do
  @moduledoc """
  Client for AI APIs.
  - Transcription: Groq Whisper (fast, OpenAI-compatible REST API)
  - Analysis: NVIDIA NIM Qwen3 (pedagogical feedback)

  Uses optimized audio extraction for video files (10x faster with FFmpeg stream copy).

  ## Analysis Methods (v3.0 MASTERCLASS)

  - `analyze_v3/2` - Full 13-dimension analysis with legal compliance
  - `analyze_v2/2` - Legacy 13-dimension analysis with Chain-of-Thought
  - `check_legal_compliance/1` - Lei 13.185 + Lei 13.718 verification
  - `analyze_socioemotional/1` - OCDE 5 pillars analysis
  - `quick_compliance_check/1` - Fast 10-point compliance verification
  - `generate_practical_examples/3` - Before/after improvement examples
  - `generate_coaching_email/1` - Personalized coaching email

  ## Legal Compliance (v3.0)

  - Lei 13.185/2015 (Anti-bullying - 9 types, 7 obligations)
  - Lei 13.718/2018 (Digital crimes, internet safety)
  - BNCC (10 general competencies)
  - SEDUC-SP Resolutions 84, 85, 86/2024

  ## Self-Consistency Support

  For critical analyses, use `analyze_with_self_consistency/2` to generate
  multiple analyses and aggregate via majority voting (+17.9% accuracy).
  """

  require Logger

  alias Hellen.AI.AudioExtractor
  alias Hellen.AI.Prompts

  # Groq for transcription (OpenAI-compatible REST API)
  @transcription_base_url "https://api.groq.com/openai/v1"
  @transcription_model "whisper-large-v3-turbo"

  # NVIDIA for LLM analysis
  @analysis_base_url "https://integrate.api.nvidia.com/v1"
  @analysis_model "qwen/qwen3-next-80b-a3b-instruct"
  @fast_analysis_model "meta/llama-3.1-8b-instruct"

  # Video extensions that need audio extraction
  @video_extensions ~w(.mp4 .mkv .avi .mov .webm .flv .wmv .m4v)

  @doc """
  Transcribes audio using Groq Whisper.

  The audio_url should be a publicly accessible URL to the audio file.
  This function downloads the file, extracts audio if needed (using FFmpeg),
  and sends it as multipart/form-data.

  For video files, uses optimized FFmpeg extraction:
  - Stream copy when codec is compatible (10x faster)
  - Re-encode to MP3 16kHz mono when needed (optimized for ASR)
  """
  def transcribe(audio_url, opts \\ []) do
    language = Keyword.get(opts, :language, "pt")

    Logger.info("Starting transcription for URL: #{audio_url}")

    start_time = System.monotonic_time(:millisecond)

    # Download and process the file (extract audio if video)
    with {:ok, audio_binary, content_type} <- download_and_process(audio_url),
         {:ok, response} <- send_transcription_request(audio_binary, content_type, language) do
      processing_time = System.monotonic_time(:millisecond) - start_time
      Logger.info("Transcription completed in #{processing_time}ms")

      {:ok,
       %{
         text: response["text"],
         segments: parse_segments(response["segments"] || []),
         language: response["language"] || language,
         duration: response["duration"],
         processing_time_ms: processing_time
       }}
    else
      {:error, reason} = error ->
        Logger.error("Transcription failed: #{inspect(reason)}")
        error
    end
  end

  # Downloads file and extracts audio if it's a video
  defp download_and_process(url) do
    Logger.info("Downloading media from: #{url}")

    filename = extract_filename(url)
    ext = Path.extname(filename) |> String.downcase()
    is_video = ext in @video_extensions

    case Req.get(url, receive_timeout: 300_000) do
      {:ok, %{status: 200, body: body, headers: headers}} ->
        Logger.info("Downloaded #{format_bytes(byte_size(body))}, file: #{filename}")
        process_downloaded_media(body, headers, url, filename, is_video)

      {:ok, %{status: status}} ->
        {:error, {:download_failed, status}}

      {:error, reason} ->
        {:error, {:download_error, reason}}
    end
  end

  # Process downloaded media - extract audio if video, return as-is if audio
  defp process_downloaded_media(body, _headers, _url, filename, true = _is_video) do
    Logger.info("Video detected - extracting audio with FFmpeg...")
    original_size = byte_size(body)
    extraction_start = System.monotonic_time(:millisecond)

    case AudioExtractor.process_for_transcription(body, filename) do
      {:ok, audio_binary, content_type} ->
        log_extraction_result(extraction_start, original_size, byte_size(audio_binary))
        {:ok, audio_binary, content_type}

      {:error, reason} ->
        Logger.error("Audio extraction failed: #{inspect(reason)}")
        {:error, {:extraction_failed, reason}}
    end
  end

  defp process_downloaded_media(body, headers, url, _filename, false = _is_video) do
    content_type = get_content_type(headers, url)
    Logger.info("Audio file - using directly (#{content_type})")
    {:ok, body, content_type}
  end

  defp log_extraction_result(start_time, original_size, audio_size) do
    extraction_time = System.monotonic_time(:millisecond) - start_time
    reduction = Float.round((1 - audio_size / original_size) * 100, 1)

    Logger.info("""
    Audio extraction complete:
      - Time: #{extraction_time}ms
      - Original: #{format_bytes(original_size)}
      - Audio: #{format_bytes(audio_size)}
      - Size reduction: #{reduction}%
    """)
  end

  defp get_content_type(headers, url) do
    headers
    |> Enum.find(fn {k, _v} -> String.downcase(k) == "content-type" end)
    |> case do
      {_, ct} -> ct
      nil -> guess_content_type(url)
    end
  end

  defp extract_filename(url) do
    url
    |> URI.parse()
    |> Map.get(:path, "")
    |> Path.basename()
    |> URI.decode()
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp send_transcription_request(audio_binary, content_type, language) do
    filename = "audio.#{content_type_to_extension(content_type)}"

    Logger.info(
      "Sending transcription request with filename: #{filename}, size: #{byte_size(audio_binary)} bytes"
    )

    "#{@transcription_base_url}/audio/transcriptions"
    |> Req.post(
      form_multipart: [
        file: {audio_binary, filename: filename, content_type: content_type},
        model: @transcription_model,
        language: language,
        response_format: "verbose_json"
      ],
      headers: groq_auth_headers(),
      receive_timeout: 300_000
    )
    |> handle_transcription_response()
  end

  @content_type_extensions %{
    "audio/mpeg" => "mp3",
    "audio/mp3" => "mp3",
    "audio/wav" => "wav",
    "audio/x-wav" => "wav",
    "audio/mp4" => "m4a",
    "audio/m4a" => "m4a",
    "video/mp4" => "mp4",
    "audio/ogg" => "ogg",
    "audio/flac" => "flac",
    "video/webm" => "webm"
  }

  defp content_type_to_extension(content_type) do
    Map.get(@content_type_extensions, content_type, "mp3")
  end

  defp handle_transcription_response({:ok, %{status: 200, body: body}}) do
    Logger.info("Transcription API returned success")
    {:ok, body}
  end

  defp handle_transcription_response({:ok, %{status: status, body: body}}) do
    error_msg = if is_map(body), do: body["error"] || body, else: body
    Logger.error("Transcription API error #{status}: #{inspect(error_msg)}")
    {:error, %{status: status, message: error_msg}}
  end

  defp handle_transcription_response({:error, reason}) do
    Logger.error("Transcription request failed: #{inspect(reason)}")
    {:error, reason}
  end

  defp guess_content_type(url) do
    ext = url |> URI.parse() |> Map.get(:path, "") |> Path.extname() |> String.downcase()

    case ext do
      ".mp3" -> "audio/mpeg"
      ".wav" -> "audio/wav"
      ".m4a" -> "audio/mp4"
      ".mp4" -> "video/mp4"
      ".ogg" -> "audio/ogg"
      ".flac" -> "audio/flac"
      ".webm" -> "video/webm"
      _ -> "audio/mpeg"
    end
  end

  defp groq_auth_headers do
    api_key = Application.get_env(:hellen, :groq_api_key)

    [
      {"Authorization", "Bearer #{api_key}"}
    ]
  end

  @doc """
  Analyzes transcription using Qwen3 for pedagogical feedback.
  Legacy method - use `analyze_v2/2` for enhanced analysis.
  """
  def analyze_pedagogy(transcription, context \\ %{}) do
    system_prompt = build_pedagogical_prompt(context)

    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@analysis_base_url}/chat/completions",
        json: %{
          model: @analysis_model,
          messages: [
            %{role: "system", content: system_prompt},
            %{role: "user", content: build_analysis_request(transcription, context)}
          ],
          temperature: 0.3,
          max_tokens: 4096,
          response_format: %{type: "json_object"}
        },
        headers: nvidia_auth_headers(),
        receive_timeout: 300_000
      )

    processing_time = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{status: 200, body: body}} ->
        message = get_in(body, ["choices", Access.at(0), "message", "content"])
        usage = body["usage"]

        {:ok,
         %{
           raw: message,
           structured: parse_analysis_response(message),
           model: @analysis_model,
           tokens_used: (usage["prompt_tokens"] || 0) + (usage["completion_tokens"] || 0),
           processing_time_ms: processing_time
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # Analysis v2.0 Methods (Chain-of-Thought + Few-Shot + Structured JSON)
  # ============================================================================

  @doc """
  Full 13-dimension pedagogical analysis with Chain-of-Thought reasoning.

  Uses v2.0 prompts with:
  - Chain-of-Thought for reasoning transparency
  - Few-Shot examples for consistent output
  - Structured JSON schema for 95%+ parsing success

  ## Context Options
  - `:discipline` - Subject name
  - `:theme` - Lesson topic
  - `:grade` - Grade level (e.g., "8o ano")
  - `:average_age` - Average student age
  - `:duration_minutes` - Lesson duration
  - `:date` - Lesson date
  """
  def analyze_v2(transcription, context \\ %{}) do
    system_prompt = Prompts.core_analysis_system_prompt(context)
    user_prompt = Prompts.core_analysis_user_prompt(transcription)
    temperature = Prompts.temperature(:core_analysis)
    max_tokens = Prompts.max_tokens(:core_analysis)

    Logger.info("[NvidiaClient] Starting v2 analysis with CoT+FewShot, temp=#{temperature}")
    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@analysis_base_url}/chat/completions",
        json: %{
          model: @analysis_model,
          messages: [
            %{role: "system", content: system_prompt},
            %{role: "user", content: user_prompt}
          ],
          temperature: temperature,
          max_tokens: max_tokens,
          response_format: %{type: "json_object"}
        },
        headers: nvidia_auth_headers(),
        receive_timeout: 180_000
      )

    processing_time = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{status: 200, body: body}} ->
        message = get_in(body, ["choices", Access.at(0), "message", "content"])
        usage = body["usage"]

        Logger.info("[NvidiaClient] v2 analysis completed in #{processing_time}ms")

        {:ok,
         %{
           raw: message,
           structured: parse_analysis_response(message),
           model: @analysis_model,
           version: "2.0",
           technique: "CoT+FewShot",
           tokens_used: (usage["prompt_tokens"] || 0) + (usage["completion_tokens"] || 0),
           processing_time_ms: processing_time
         }}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[NvidiaClient] v2 analysis failed: #{status}")
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        Logger.error("[NvidiaClient] v2 analysis error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Quick 10-point compliance check for fast feedback.
  Returns conformity percentage and urgency level.
  Uses lighter model for speed (#{@fast_analysis_model}).
  """
  def quick_compliance_check(transcription) do
    system_prompt = Prompts.quick_check_system_prompt()
    user_prompt = Prompts.quick_check_user_prompt(transcription)
    temperature = Prompts.temperature(:quick_check)
    max_tokens = Prompts.max_tokens(:quick_check)

    Logger.info("[NvidiaClient] Starting quick compliance check (Model: #{@fast_analysis_model})")
    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@analysis_base_url}/chat/completions",
        json: %{
          model: @fast_analysis_model,
          messages: [
            %{role: "system", content: system_prompt},
            %{role: "user", content: user_prompt}
          ],
          temperature: temperature,
          max_tokens: max_tokens,
          response_format: %{type: "json_object"}
        },
        headers: nvidia_auth_headers(),
        receive_timeout: 60_000
      )

    processing_time = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{status: 200, body: body}} ->
        message = get_in(body, ["choices", Access.at(0), "message", "content"])
        usage = body["usage"]

        Logger.info("[NvidiaClient] Quick check completed in #{processing_time}ms")

        {:ok,
         %{
           raw: message,
           structured: parse_analysis_response(message),
           type: :quick_check,
           model: @fast_analysis_model,
           tokens_used: (usage["prompt_tokens"] || 0) + (usage["completion_tokens"] || 0),
           processing_time_ms: processing_time
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generates practical before/after examples for a specific dimension.
  Uses ReAct pattern for actionable improvements.
  """
  def generate_practical_examples(transcription, dimension, gap) do
    system_prompt = Prompts.practical_examples_system_prompt()
    user_prompt = Prompts.practical_examples_user_prompt(transcription, dimension, gap)
    temperature = Prompts.temperature(:practical_examples)
    max_tokens = Prompts.max_tokens(:practical_examples)

    Logger.info("[NvidiaClient] Generating practical examples for dimension: #{dimension}")
    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@analysis_base_url}/chat/completions",
        json: %{
          model: @analysis_model,
          messages: [
            %{role: "system", content: system_prompt},
            %{role: "user", content: user_prompt}
          ],
          temperature: temperature,
          max_tokens: max_tokens,
          response_format: %{type: "json_object"}
        },
        headers: nvidia_auth_headers(),
        receive_timeout: 90_000
      )

    processing_time = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{status: 200, body: body}} ->
        message = get_in(body, ["choices", Access.at(0), "message", "content"])
        usage = body["usage"]

        {:ok,
         %{
           raw: message,
           structured: parse_analysis_response(message),
           type: :practical_examples,
           dimension: dimension,
           tokens_used: (usage["prompt_tokens"] || 0) + (usage["completion_tokens"] || 0),
           processing_time_ms: processing_time
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generates a personalized coaching email for the teacher.
  Uses Few-Shot + Tone Conditioning for empathetic communication.
  """
  def generate_coaching_email(context) do
    system_prompt = Prompts.coaching_email_system_prompt()
    user_prompt = Prompts.coaching_email_user_prompt(context)
    temperature = Prompts.temperature(:coaching_email)
    max_tokens = Prompts.max_tokens(:coaching_email)

    Logger.info("[NvidiaClient] Generating coaching email")
    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@analysis_base_url}/chat/completions",
        json: %{
          model: @analysis_model,
          messages: [
            %{role: "system", content: system_prompt},
            %{role: "user", content: user_prompt}
          ],
          temperature: temperature,
          max_tokens: max_tokens,
          response_format: %{type: "json_object"}
        },
        headers: nvidia_auth_headers(),
        receive_timeout: 60_000
      )

    processing_time = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{status: 200, body: body}} ->
        message = get_in(body, ["choices", Access.at(0), "message", "content"])
        usage = body["usage"]

        {:ok,
         %{
           raw: message,
           structured: parse_analysis_response(message),
           type: :coaching_email,
           tokens_used: (usage["prompt_tokens"] || 0) + (usage["completion_tokens"] || 0),
           processing_time_ms: processing_time
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # Analysis v3.0 MASTERCLASS Methods (Full Legal Compliance)
  # ============================================================================

  @doc """
  Full 13-dimension pedagogical analysis v3.0 MASTERCLASS.

  Complete analysis with:
  - Lei 13.185/2015 (Anti-bullying) compliance
  - Lei 13.718/2018 (Internet safety) compliance
  - BNCC 10 general competencies
  - OCDE 5 socioemotional pillars
  - SEDUC-SP Resolutions alignment

  ## Context Options
  - `:discipline` - Subject name
  - `:theme` - Lesson topic
  - `:grade` - Grade level (e.g., "7o ano")
  - `:average_age` - Average student age
  - `:duration_minutes` - Lesson duration
  - `:date` - Lesson date
  - `:state` - State for SEDUC alignment (default: "SP")
  - `:school_type` - "Pública" or "Particular"
  """
  def analyze_v3(transcription, context \\ %{}) do
    system_prompt = Prompts.core_analysis_system_prompt(context)
    user_prompt = Prompts.core_analysis_user_prompt(transcription)
    temperature = Prompts.temperature(:core_analysis)
    max_tokens = Prompts.max_tokens(:core_analysis)

    Logger.info("[NvidiaClient] Starting v3.0 MASTERCLASS analysis, temp=#{temperature}")
    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@analysis_base_url}/chat/completions",
        json: %{
          model: @analysis_model,
          messages: [
            %{role: "system", content: system_prompt},
            %{role: "user", content: user_prompt}
          ],
          temperature: temperature,
          max_tokens: max_tokens,
          response_format: %{type: "json_object"}
        },
        headers: nvidia_auth_headers(),
        receive_timeout: 240_000
      )

    processing_time = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{status: 200, body: body}} ->
        message = get_in(body, ["choices", Access.at(0), "message", "content"])
        usage = body["usage"]

        Logger.info("[NvidiaClient] v3.0 analysis completed in #{processing_time}ms")

        {:ok,
         %{
           raw: message,
           structured: parse_analysis_response(message),
           model: @analysis_model,
           version: "3.0",
           technique: "CoT+FewShot+LegalCompliance",
           tokens_used: (usage["prompt_tokens"] || 0) + (usage["completion_tokens"] || 0),
           processing_time_ms: processing_time
         }}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[NvidiaClient] v3.0 analysis failed: #{status}")
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        Logger.error("[NvidiaClient] v3.0 analysis error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Quick legal compliance check against Lei 13.185 and Lei 13.718.
  Returns conformity scores and risk assessment.
  """
  def check_legal_compliance(transcription) do
    system_prompt = Prompts.legal_compliance_system_prompt()
    user_prompt = Prompts.legal_compliance_user_prompt(transcription)
    temperature = Prompts.temperature(:legal_compliance)
    max_tokens = Prompts.max_tokens(:legal_compliance)

    Logger.info("[NvidiaClient] Starting legal compliance check")
    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@analysis_base_url}/chat/completions",
        json: %{
          model: @analysis_model,
          messages: [
            %{role: "system", content: system_prompt},
            %{role: "user", content: user_prompt}
          ],
          temperature: temperature,
          max_tokens: max_tokens,
          response_format: %{type: "json_object"}
        },
        headers: nvidia_auth_headers(),
        receive_timeout: 90_000
      )

    processing_time = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{status: 200, body: body}} ->
        message = get_in(body, ["choices", Access.at(0), "message", "content"])
        usage = body["usage"]

        Logger.info("[NvidiaClient] Legal compliance check completed in #{processing_time}ms")

        {:ok,
         %{
           raw: message,
           structured: parse_analysis_response(message),
           type: :legal_compliance,
           tokens_used: (usage["prompt_tokens"] || 0) + (usage["completion_tokens"] || 0),
           processing_time_ms: processing_time
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Analyzes socioemotional competencies based on OCDE 5 pillars.

  Returns scores for:
  - Desempenho (Performance)
  - Regulacao (Emotional Regulation)
  - Interacao (Social Interaction)
  - Abertura (Openness)
  - Colaboracao (Collaboration)
  """
  def analyze_socioemotional(transcription) do
    system_prompt = Prompts.socioemotional_system_prompt()

    user_prompt = """
    TRANSCRIÇÃO DA AULA:
    #{transcription}

    Analise as competências socioemocionais trabalhadas seguindo o framework OCDE.
    """

    temperature = Prompts.temperature(:core_analysis)
    max_tokens = Prompts.max_tokens(:quick_check)

    Logger.info("[NvidiaClient] Starting socioemotional analysis")
    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@analysis_base_url}/chat/completions",
        json: %{
          model: @analysis_model,
          messages: [
            %{role: "system", content: system_prompt},
            %{role: "user", content: user_prompt}
          ],
          temperature: temperature,
          max_tokens: max_tokens,
          response_format: %{type: "json_object"}
        },
        headers: nvidia_auth_headers(),
        receive_timeout: 90_000
      )

    processing_time = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{status: 200, body: body}} ->
        message = get_in(body, ["choices", Access.at(0), "message", "content"])
        usage = body["usage"]

        {:ok,
         %{
           raw: message,
           structured: parse_analysis_response(message),
           type: :socioemotional,
           tokens_used: (usage["prompt_tokens"] || 0) + (usage["completion_tokens"] || 0),
           processing_time_ms: processing_time
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generates a structured pedagogical feedback using the Sandwich Method.
  """
  def analyze_feedback(transcription, context \\ %{}) do
    system_prompt = build_feedback_prompt(context)

    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@analysis_base_url}/chat/completions",
        json: %{
          model: @analysis_model,
          messages: [
            %{role: "system", content: system_prompt},
            %{role: "user", content: build_feedback_request(transcription)}
          ],
          temperature: 0.4,
          max_tokens: 4096,
          response_format: %{type: "json_object"}
        },
        headers: nvidia_auth_headers(),
        receive_timeout: 120_000
      )

    processing_time = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{status: 200, body: body}} ->
        message = get_in(body, ["choices", Access.at(0), "message", "content"])
        usage = body["usage"]

        {:ok,
         %{
           raw: message,
           structured: parse_analysis_response(message),
           model: @analysis_model,
           tokens_used: (usage["prompt_tokens"] || 0) + (usage["completion_tokens"] || 0),
           processing_time_ms: processing_time
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp nvidia_auth_headers do
    api_key = Application.get_env(:hellen, :nvidia_api_key)

    [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp parse_segments(segments) do
    Enum.map(segments, fn seg ->
      %{
        start: seg["start"],
        end: seg["end"],
        text: seg["text"]
      }
    end)
  end

  defp build_pedagogical_prompt(context) do
    planned_section = build_planned_section(context)

    planned_alignment_item =
      if planned_section != "",
        do:
          "\n    9. planned_alignment: análise de aderência ao conteúdo planejado (se fornecido)",
        else: ""

    """
    Você é um especialista em pedagogia e análise de aulas, com profundo conhecimento em:
    - BNCC (Base Nacional Comum Curricular)
    - Lei 13.185/2015 (Lei Anti-bullying)
    - Metodologias ativas de ensino
    - Gestão de sala de aula

    Analise a transcrição da aula e forneça feedback estruturado em JSON com:
    1. overall_score: float de 0.0 a 1.0
    2. bncc_matches: array das TOP 10 competências BNCC mais relevantes identificadas
    3. bullying_alerts: array de alertas de comportamento inadequado
    4. strengths: pontos fortes da aula
    5. improvements: oportunidades de melhoria
    6. time_management: análise da gestão do tempo
    7. engagement: nível de engajamento dos alunos
    8. lesson_characters: array de personagens/participantes identificados na aula#{planned_alignment_item}

    Para lesson_characters, identifique cada participante distinto (professor(a), alunos) e forneça:
    {
      "identifier": "Nome inferido ou 'Professor(a)', 'Aluno 1', etc.",
      "role": "teacher" | "student" | "assistant" | "guest" | "other",
      "speech_count": número estimado de falas,
      "word_count": número estimado de palavras,
      "characteristics": ["participativo", "questionador", "atento", etc.],
      "speech_patterns": "Descrição breve do padrão de fala (ex: 'Usa linguagem clara e pausada')",
      "key_quotes": ["citação representativa 1", "citação representativa 2"],
      "sentiment": "positive" | "neutral" | "negative" | "mixed",
      "engagement_level": "high" | "medium" | "low"
    }

    Contexto da aula:
    - Disciplina: #{context[:subject] || "Não especificada"}
    - Nível: #{context[:grade_level] || "Não especificado"}
    #{planned_section}

    #{if planned_section != "", do: "IMPORTANTE: Compare a transcrição com o conteúdo planejado. Identifique:\n- O que foi coberto conforme planejado\n- O que ficou faltando do planejamento\n- Conteúdos abordados fora do planejamento\n- Sugestões de alinhamento para próximas aulas", else: ""}
    """
  end

  defp build_planned_section(context) do
    planned_content = context[:planned_content]
    planned_file_name = context[:planned_file_name]

    cond do
      planned_content && String.trim(planned_content) != "" ->
        "- Material Planejado: #{planned_content}"

      planned_file_name ->
        "- Arquivo de Planejamento: #{planned_file_name} (conteúdo a ser considerado na análise)"

      true ->
        ""
    end
  end

  defp build_feedback_prompt(context) do
    """
    Você é um Coordenador Pedagógico Sênior especialista em formação de professores.
    Seu objetivo é criar um ROTEIRO DE FEEDBACK estruturado e acolhedor para o professor, baseado na transcrição da aula.

    METODOLOGIA: TÉCNICA SANDUÍCHE
    1. Abertura Positiva (Acolhimento + Pontos Fortes)
    2. Recheio Construtivo (Oportunidades de Melhoria com Evidências)
    3. Fechamento Motivador (Plano de Ação + Encorajamento)

    Contexto da aula:
    - Disciplina: #{context[:subject] || "Não especificada"}
    - Nível: #{context[:grade_level] || "Não especificado"}

    Retorne APENAS um JSON com a seguinte estrutura:
    {
      "opening": "Texto de abertura acolhedor e empático",
      "strengths": [
        {
          "title": "Título do ponto forte",
          "description": "Descrição detalhada",
          "evidence": "Citação ou momento específico da transcrição que comprova"
        }
      ],
      "improvements": [
        {
          "title": "Título da oportunidade de melhoria",
          "observation": "O que foi observado (evidência/citação)",
          "suggestion": "Sugestão prática e acionável de como melhorar (cite técnicas pedagógicas se aplicável)"
        }
      ],
      "action_plan": [
        "Passo 1 do plano de ação",
        "Passo 2 do plano de ação",
        "Passo 3 do plano de ação"
      ],
      "closing": "Texto de encerramento motivador e parceiro"
    }
    """
  end

  defp build_analysis_request(transcription, context) do
    planned_content = context[:planned_content]

    base_request = """
    Analise a seguinte transcrição de aula e forneça seu feedback pedagógico:

    TRANSCRIÇÃO:
    #{transcription}
    """

    planned_section =
      if planned_content && String.trim(to_string(planned_content)) != "" do
        """

        CONTEÚDO PLANEJADO PARA ESTA AULA:
        #{planned_content}

        Compare a transcrição com o conteúdo planejado acima e inclua na sua análise:
        - Percentual de aderência ao planejamento
        - Tópicos cobertos vs não cobertos
        - Recomendações de alinhamento
        """
      else
        ""
      end

    """
    #{base_request}
    #{planned_section}
    Responda APENAS em formato JSON válido.
    """
  end

  defp build_feedback_request(transcription) do
    """
    Gere o Roteiro de Feedback Pedagógico baseado nesta transcrição:

    TRANSCRIÇÃO:
    #{transcription}

    Responda APENAS o JSON estruturado.
    """
  end

  defp parse_analysis_response(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, parsed} -> parsed
      {:error, _} -> %{"error" => "Failed to parse response", "raw" => json_string}
    end
  end

  defp parse_analysis_response(other), do: other

  # ============================================================================
  # Self-Consistency Analysis (Majority Voting)
  # ============================================================================

  @doc """
  Performs analysis with self-consistency for higher accuracy.

  Generates N independent analyses and aggregates via majority voting.
  Provides +17.9% accuracy improvement on complex tasks.

  ## Options
  - `:samples` - Number of analyses to generate (default: 3, max: 5)
  - `:parallel` - Run analyses in parallel (default: true)

  ## Returns
  - `:consensus` - The aggregated/voted result
  - `:analyses` - All individual analyses
  - `:confidence` - Agreement level between analyses (0.0-1.0)
  - `:disagreements` - Dimensions where analyses differed significantly
  """
  def analyze_with_self_consistency(transcription, context \\ %{}, opts \\ []) do
    samples = min(Keyword.get(opts, :samples, 3), 5)
    parallel = Keyword.get(opts, :parallel, true)

    Logger.info("[NvidiaClient] Starting self-consistency analysis with #{samples} samples")
    start_time = System.monotonic_time(:millisecond)

    # Generate multiple analyses
    analyses =
      if parallel do
        1..samples
        |> Task.async_stream(
          fn _ -> run_single_analysis(transcription, context) end,
          timeout: 200_000,
          max_concurrency: samples
        )
        |> Enum.map(fn
          {:ok, result} -> result
          {:exit, _reason} -> nil
        end)
        |> Enum.filter(&(&1 != nil))
      else
        Enum.map(1..samples, fn _ -> run_single_analysis(transcription, context) end)
        |> Enum.filter(fn
          {:ok, _} -> true
          _ -> false
        end)
        |> Enum.map(fn {:ok, r} -> {:ok, r} end)
      end

    successful =
      Enum.filter(analyses, fn
        {:ok, _} -> true
        _ -> false
      end)

    if length(successful) < 2 do
      Logger.error("[NvidiaClient] Self-consistency failed: insufficient successful analyses")
      {:error, :insufficient_analyses}
    else
      # Aggregate results via voting
      consensus = aggregate_analyses(successful)
      confidence = calculate_confidence(successful)
      disagreements = find_disagreements(successful)

      processing_time = System.monotonic_time(:millisecond) - start_time
      total_tokens = sum_tokens(successful)

      Logger.info(
        "[NvidiaClient] Self-consistency completed: confidence=#{Float.round(confidence, 2)}"
      )

      {:ok,
       %{
         consensus: consensus,
         analyses: Enum.map(successful, fn {:ok, a} -> a.structured end),
         confidence: confidence,
         disagreements: disagreements,
         sample_count: length(successful),
         version: "2.0-self-consistency",
         tokens_used: total_tokens,
         processing_time_ms: processing_time
       }}
    end
  end

  defp run_single_analysis(transcription, context) do
    # Use higher temperature for diversity
    system_prompt = Prompts.core_analysis_system_prompt(context)
    user_prompt = Prompts.core_analysis_user_prompt(transcription)
    temperature = Prompts.temperature(:multiple_reasoning)
    max_tokens = Prompts.max_tokens(:core_analysis)

    result =
      Req.post("#{@analysis_base_url}/chat/completions",
        json: %{
          model: @analysis_model,
          messages: [
            %{role: "system", content: system_prompt},
            %{role: "user", content: user_prompt}
          ],
          temperature: temperature,
          max_tokens: max_tokens,
          response_format: %{type: "json_object"}
        },
        headers: nvidia_auth_headers(),
        receive_timeout: 180_000
      )

    case result do
      {:ok, %{status: 200, body: body}} ->
        message = get_in(body, ["choices", Access.at(0), "message", "content"])
        usage = body["usage"]

        {:ok,
         %{
           structured: parse_analysis_response(message),
           tokens_used: (usage["prompt_tokens"] || 0) + (usage["completion_tokens"] || 0)
         }}

      _ ->
        {:error, :api_failure}
    end
  end

  defp aggregate_analyses(analyses) do
    # Extract structured results
    results = Enum.map(analyses, fn {:ok, a} -> a.structured end)

    # Vote on conformidade_geral_percent (average)
    conformidades = Enum.map(results, &get_conformidade/1) |> Enum.filter(&(&1 != nil))

    avg_conformidade = safe_average(conformidades)

    # Vote on status_geral (majority)
    statuses = Enum.map(results, &get_status_geral/1) |> Enum.filter(&(&1 != nil))
    voted_status = vote_majority(statuses)

    # Vote on potencial_melhoria (majority)
    potenciais = Enum.map(results, &get_potencial/1) |> Enum.filter(&(&1 != nil))
    voted_potencial = vote_majority(potenciais)

    # Aggregate dimension scores
    dimension_scores = aggregate_dimension_scores(results)

    # Use the first analysis as base and override with voted values
    base = List.first(results) || %{}

    base
    |> put_in_metadata("conformidade_geral_percent", round(avg_conformidade))
    |> put_in_metadata("status_geral", voted_status)
    |> put_in_metadata("potencial_melhoria", voted_potencial)
    |> Map.put("analise_dimensoes", dimension_scores)
    |> Map.put("_consensus_method", "majority_voting")
    |> Map.put("_sample_count", length(analyses))
  end

  defp get_conformidade(%{"metadata" => %{"conformidade_geral_percent" => v}}), do: v
  defp get_conformidade(_), do: nil

  defp get_status_geral(%{"metadata" => %{"status_geral" => v}}), do: v
  defp get_status_geral(_), do: nil

  defp get_potencial(%{"metadata" => %{"potencial_melhoria" => v}}), do: v
  defp get_potencial(_), do: nil

  defp put_in_metadata(map, key, value) when is_map(map) do
    metadata = Map.get(map, "metadata", %{})
    Map.put(map, "metadata", Map.put(metadata, key, value))
  end

  defp vote_majority([_ | _] = items) do
    items
    |> Enum.frequencies()
    |> Enum.max_by(fn {_item, count} -> count end)
    |> elem(0)
  end

  defp vote_majority(_), do: nil

  defp safe_average([]), do: 0

  defp safe_average(list) do
    count = Enum.count(list)
    Enum.sum(list) / count
  end

  defp aggregate_dimension_scores(results) do
    # Group dimensions by number
    all_dimensions =
      results
      |> Enum.flat_map(&Map.get(&1, "analise_dimensoes", []))
      |> Enum.group_by(&Map.get(&1, "numero"))

    # Average scores per dimension
    Enum.map(1..13, fn num ->
      dims = Map.get(all_dimensions, num, [])
      aggregate_single_dimension(dims, num)
    end)
  end

  defp aggregate_single_dimension([], num) do
    %{"numero" => num, "nome" => "Dimensão #{num}", "conformidade_percent" => 0}
  end

  defp aggregate_single_dimension([base | _] = dims, _num) do
    scores = Enum.map(dims, &Map.get(&1, "conformidade_percent", 0))
    avg_score = safe_average(scores)

    base
    |> Map.put("conformidade_percent", round(avg_score))
    |> Map.put("status", score_to_status(avg_score))
  end

  defp score_to_status(score) when score >= 85, do: "✅"
  defp score_to_status(score) when score >= 60, do: "⚠️"
  defp score_to_status(_score), do: "❌"

  defp calculate_confidence(analyses) do
    results = Enum.map(analyses, fn {:ok, a} -> a.structured end)
    conformidades = Enum.map(results, &get_conformidade/1) |> Enum.filter(&(&1 != nil))
    calculate_confidence_from_scores(conformidades)
  end

  defp calculate_confidence_from_scores(scores) when length(scores) < 2, do: 0.0

  defp calculate_confidence_from_scores(scores) do
    count = Enum.count(scores)
    avg = Enum.sum(scores) / count
    variance = Enum.sum(Enum.map(scores, fn c -> (c - avg) ** 2 end)) / count
    std_dev = :math.sqrt(variance)
    # std_dev of 0 = 1.0 confidence, std_dev of 20+ = ~0.5 confidence
    max(0.0, min(1.0, 1.0 - std_dev / 40.0))
  end

  defp find_disagreements(analyses) do
    results = Enum.map(analyses, fn {:ok, a} -> a.structured end)
    all_dimensions = Enum.flat_map(results, &Map.get(&1, "analise_dimensoes", []))

    1..13
    |> Enum.map(&calculate_dimension_variance(all_dimensions, &1))
    |> Enum.filter(fn {_num, diff} -> diff > 15 end)
    |> Enum.map(&format_disagreement/1)
  end

  defp calculate_dimension_variance(all_dimensions, num) do
    scores =
      all_dimensions
      |> Enum.filter(&(Map.get(&1, "numero") == num))
      |> Enum.map(&Map.get(&1, "conformidade_percent", 0))

    {num, calculate_max_diff(scores)}
  end

  defp calculate_max_diff(scores) when length(scores) < 2, do: 0

  defp calculate_max_diff(scores) do
    avg = safe_average(scores)
    Enum.max(Enum.map(scores, fn s -> abs(s - avg) end))
  end

  defp format_disagreement({num, diff}) do
    %{
      dimension: num,
      variance: round(diff),
      note: "Analyses differed significantly on this dimension"
    }
  end

  defp sum_tokens(analyses) do
    Enum.sum(Enum.map(analyses, fn {:ok, a} -> a.tokens_used end))
  end
end
