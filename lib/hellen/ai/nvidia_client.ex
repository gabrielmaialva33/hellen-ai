defmodule Hellen.AI.NvidiaClient do
  @moduledoc """
  Client for NVIDIA NIM API.
  Handles transcription (Whisper/Parakeet) and analysis (Qwen3).
  """

  @base_url "https://integrate.api.nvidia.com/v1"

  @transcription_model "nvidia/parakeet-ctc-1.1b-asr"
  @analysis_model "qwen/qwen3-next-80b-a3b-instruct"

  @doc """
  Transcribes audio using NVIDIA Parakeet/Whisper.
  """
  def transcribe(audio_url, opts \\ []) do
    language = Keyword.get(opts, :language, "pt")

    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@base_url}/audio/transcriptions",
        json: %{
          model: @transcription_model,
          file: audio_url,
          language: language,
          response_format: "verbose_json"
        },
        headers: auth_headers(),
        receive_timeout: 300_000
      )

    processing_time = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{status: 200, body: body}} ->
        {:ok,
         %{
           text: body["text"],
           segments: parse_segments(body["segments"] || []),
           language: body["language"],
           duration: body["duration"],
           processing_time_ms: processing_time
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Analyzes transcription using Qwen3 for pedagogical feedback.
  """
  def analyze_pedagogy(transcription, context \\ %{}) do
    system_prompt = build_pedagogical_prompt(context)

    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@base_url}/chat/completions",
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
        headers: auth_headers(),
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

  defp auth_headers do
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

  defp build_analysis_request(transcription, _context) do
    """
    Analise a seguinte transcrição de aula e forneça seu feedback pedagógico:

    TRANSCRIÇÃO:
    #{transcription}

    Responda APENAS em formato JSON válido.
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
