defmodule Hellen.AI.NvidiaClient do
  @moduledoc """
  Client for AI APIs.
  - Transcription: Groq Whisper (fast, OpenAI-compatible REST API)
  - Analysis: NVIDIA NIM Qwen3 (pedagogical feedback)

  Uses optimized audio extraction for video files (10x faster with FFmpeg stream copy).
  """

  require Logger

  alias Hellen.AI.AudioExtractor

  # Groq for transcription (OpenAI-compatible REST API)
  @transcription_base_url "https://api.groq.com/openai/v1"
  @transcription_model "whisper-large-v3-turbo"

  # NVIDIA for LLM analysis
  @analysis_base_url "https://integrate.api.nvidia.com/v1"
  @analysis_model "qwen/qwen3-next-80b-a3b-instruct"

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
    """
    Você é um especialista em pedagogia e análise de aulas, com profundo conhecimento em:
    - BNCC (Base Nacional Comum Curricular)
    - Lei 13.185/2015 (Lei Anti-bullying)
    - Metodologias ativas de ensino
    - Gestão de sala de aula

    Analise a transcrição da aula e forneça feedback estruturado em JSON com:
    1. overall_score: float de 0.0 a 1.0
    2. bncc_matches: array de competências BNCC identificadas
    3. bullying_alerts: array de alertas de comportamento inadequado
    4. strengths: pontos fortes da aula
    5. improvements: oportunidades de melhoria
    6. time_management: análise da gestão do tempo
    7. engagement: nível de engajamento dos alunos

    Contexto da aula:
    - Disciplina: #{context[:subject] || "Não especificada"}
    - Nível: #{context[:grade_level] || "Não especificado"}
    """
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

  defp build_analysis_request(transcription, _context) do
    """
    Analise a seguinte transcrição de aula e forneça seu feedback pedagógico:

    TRANSCRIÇÃO:
    #{transcription}

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
end
