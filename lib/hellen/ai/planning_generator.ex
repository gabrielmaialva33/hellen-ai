defmodule Hellen.AI.PlanningGenerator do
  @moduledoc """
  AI-powered lesson planning generator.

  Uses NVIDIA NIM LLM to generate structured lesson plans from:
  - Lesson transcriptions
  - Topic descriptions
  - BNCC competency codes

  Features:
  - BNCC alignment
  - Grade-level appropriate content
  - Structured methodology sections
  - Assessment criteria suggestions
  """

  require Logger

  alias Hellen.AI.Embeddings
  alias Hellen.Lessons
  alias Hellen.Plannings
  alias Hellen.Plannings.Planning

  # NVIDIA NIM API
  @llm_base_url "https://integrate.api.nvidia.com/v1"
  @llm_model "nvidia/llama-3.1-nemotron-70b-instruct"

  # ============================================================================
  # GENERATION FROM LESSON
  # ============================================================================

  @doc """
  Generates a lesson planning from an existing lesson transcription.

  The planning will include:
  - Learning objectives extracted from the lesson
  - BNCC codes matched from content
  - Structured methodology based on actual teaching
  - Assessment criteria aligned with objectives
  """
  def from_lesson(lesson_id, user_id, opts \\ []) do
    with {:ok, lesson} <- get_lesson_with_transcription(lesson_id),
         {:ok, bncc_matches} <- find_bncc_matches(lesson.transcription.text),
         {:ok, planning_data} <- generate_planning_from_transcription(lesson, bncc_matches, opts) do
      # Create the planning
      attrs =
        planning_data
        |> Map.put(:user_id, user_id)
        |> Map.put(:source_lesson_id, lesson_id)
        |> Map.put(:institution_id, lesson.institution_id)
        |> Map.put(:generated_by_ai, true)

      Plannings.create_planning(attrs)
    end
  end

  @doc """
  Generates a lesson planning from a topic description.

  Useful for creating plannings without existing lessons.
  """
  def from_topic(topic, subject, grade_level, user_id, opts \\ []) do
    with {:ok, bncc_matches} <- find_bncc_matches(topic),
         {:ok, planning_data} <-
           generate_planning_from_topic(topic, subject, grade_level, bncc_matches, opts) do
      attrs =
        planning_data
        |> Map.put(:user_id, user_id)
        |> Map.put(:generated_by_ai, true)

      Plannings.create_planning(attrs)
    end
  end

  @doc """
  Generates inline suggestions for form fields based on basic info.

  Used for real-time AI assistance while filling the manual form.
  Returns suggestions for description, methodology, and assessment_criteria.
  """
  def suggest_fields(title, subject, grade_level, description \\ nil) do
    prompt = build_suggestion_prompt(title, subject, grade_level, description)

    case call_llm(prompt) do
      {:ok, response} ->
        parse_suggestion_response(response)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_suggestion_prompt(title, subject, grade_level, description) do
    subject_label = Plannings.Planning.subject_label(subject)
    grade_label = Plannings.Planning.grade_level_label(grade_level)

    context =
      if description && String.trim(description) != "" do
        "Descrição fornecida: #{description}"
      else
        "Sem descrição prévia"
      end

    """
    Você é um especialista em pedagogia brasileira. Baseado nas informações abaixo, sugira conteúdo para um plano de aula.

    INFORMAÇÕES:
    - Título: #{title}
    - Disciplina: #{subject_label}
    - Ano/Série: #{grade_label}
    - #{context}

    Gere sugestões criativas e pedagógicamente sólidas em JSON (responda APENAS com o JSON):
    {
      "description": "Uma descrição concisa do que será abordado na aula (2-3 frases)",
      "methodology": "Descrição da metodologia sugerida, incluindo abordagens didáticas específicas para #{grade_label}",
      "assessment_criteria": "Critérios claros de avaliação alinhados aos objetivos da aula"
    }
    """
  end

  defp parse_suggestion_response(response) do
    json_str = extract_json(response)

    case Jason.decode(json_str) do
      {:ok, data} ->
        {:ok,
         %{
           description: data["description"],
           methodology: data["methodology"],
           assessment_criteria: data["assessment_criteria"]
         }}

      {:error, _} ->
        {:error, :invalid_json_response}
    end
  end

  @doc """
  Improves an existing planning using AI suggestions.
  """
  def improve_planning(%Planning{} = planning, focus_areas \\ []) do
    prompt = build_improvement_prompt(planning, focus_areas)

    case call_llm(prompt) do
      {:ok, response} ->
        parse_improvement_response(response)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # PRIVATE - GENERATION LOGIC
  # ============================================================================

  defp get_lesson_with_transcription(lesson_id) do
    try do
      lesson = Lessons.get_lesson!(lesson_id)
      lesson = Hellen.Repo.preload(lesson, :transcription)

      if lesson.transcription && lesson.transcription.text do
        {:ok, lesson}
      else
        {:error, :no_transcription}
      end
    rescue
      Ecto.NoResultsError ->
        {:error, :lesson_not_found}
    end
  end

  defp find_bncc_matches(text) do
    case Embeddings.match_bncc(text, limit: 5) do
      {:ok, matches} ->
        codes = Enum.map(matches, & &1.payload["code"])
        {:ok, codes}

      {:error, _reason} ->
        # Return empty if BNCC collection not available
        {:ok, []}
    end
  end

  defp generate_planning_from_transcription(lesson, bncc_codes, opts) do
    duration = Keyword.get(opts, :duration_minutes, 50)

    prompt = """
    Você é um especialista em pedagogia brasileira. Analise a transcrição desta aula e gere um plano de aula estruturado.

    TRANSCRIÇÃO DA AULA:
    #{String.slice(lesson.transcription.text, 0, 8000)}

    INFORMAÇÕES:
    - Disciplina: #{lesson.subject || "Não especificada"}
    - Ano/Série: #{lesson.grade_level || "Não especificado"}
    - Duração prevista: #{duration} minutos
    - Códigos BNCC sugeridos: #{Enum.join(bncc_codes, ", ")}

    Gere um JSON com a seguinte estrutura (responda APENAS com o JSON, sem texto adicional):
    {
      "title": "Título claro e descritivo do plano de aula",
      "description": "Breve descrição do que será abordado",
      "objectives": ["Objetivo 1", "Objetivo 2", "Objetivo 3"],
      "bncc_codes": ["EF05MA01", "EF05MA02"],
      "content": {
        "introduction": "Descrição da introdução/contextualização (5-10 min)",
        "development": [
          {"step": 1, "activity": "Descrição da atividade", "duration_minutes": 15},
          {"step": 2, "activity": "Descrição da atividade", "duration_minutes": 20}
        ],
        "closure": "Atividade de encerramento e síntese",
        "homework": "Tarefa para casa (opcional)",
        "adaptations": "Sugestões de adaptação para alunos com necessidades especiais"
      },
      "materials": ["Material 1", "Material 2"],
      "methodology": "Descrição da metodologia utilizada (expositiva, dialogada, prática, etc.)",
      "assessment_criteria": "Como avaliar se os objetivos foram alcançados"
    }
    """

    case call_llm(prompt) do
      {:ok, response} ->
        parse_planning_response(response, lesson.subject, lesson.grade_level, duration)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_planning_from_topic(topic, subject, grade_level, bncc_codes, opts) do
    duration = Keyword.get(opts, :duration_minutes, 50)

    prompt = """
    Você é um especialista em pedagogia brasileira. Crie um plano de aula completo sobre o tema especificado.

    TEMA: #{topic}

    INFORMAÇÕES:
    - Disciplina: #{subject}
    - Ano/Série: #{grade_level}
    - Duração prevista: #{duration} minutos
    - Códigos BNCC sugeridos: #{Enum.join(bncc_codes, ", ")}

    Gere um JSON com a seguinte estrutura (responda APENAS com o JSON, sem texto adicional):
    {
      "title": "Título claro e descritivo do plano de aula",
      "description": "Breve descrição do que será abordado",
      "objectives": ["Objetivo 1", "Objetivo 2", "Objetivo 3"],
      "bncc_codes": ["Código BNCC 1", "Código BNCC 2"],
      "content": {
        "introduction": "Descrição da introdução/contextualização (5-10 min)",
        "development": [
          {"step": 1, "activity": "Descrição da atividade", "duration_minutes": 15},
          {"step": 2, "activity": "Descrição da atividade", "duration_minutes": 20}
        ],
        "closure": "Atividade de encerramento e síntese",
        "homework": "Tarefa para casa (opcional)",
        "adaptations": "Sugestões de adaptação para alunos com necessidades especiais"
      },
      "materials": ["Material 1", "Material 2"],
      "methodology": "Descrição da metodologia utilizada",
      "assessment_criteria": "Como avaliar se os objetivos foram alcançados"
    }
    """

    case call_llm(prompt) do
      {:ok, response} ->
        parse_planning_response(response, subject, grade_level, duration)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_improvement_prompt(%Planning{} = planning, focus_areas) do
    focus_text =
      if Enum.empty?(focus_areas) do
        "engajamento dos alunos, clareza dos objetivos, alinhamento BNCC"
      else
        Enum.join(focus_areas, ", ")
      end

    """
    Você é um especialista em pedagogia brasileira. Analise este plano de aula e sugira melhorias.

    PLANO ATUAL:
    Título: #{planning.title}
    Descrição: #{planning.description}
    Objetivos: #{Enum.join(planning.objectives || [], ", ")}
    Metodologia: #{planning.methodology}
    Avaliação: #{planning.assessment_criteria}

    FOCO DAS MELHORIAS: #{focus_text}

    Responda em JSON com sugestões específicas:
    {
      "suggestions": [
        {"area": "Objetivos", "current": "...", "improved": "...", "reason": "..."},
        {"area": "Metodologia", "current": "...", "improved": "...", "reason": "..."}
      ],
      "additional_activities": ["Atividade sugerida 1", "Atividade sugerida 2"],
      "resources": ["Recurso adicional 1", "Recurso adicional 2"]
    }
    """
  end

  # ============================================================================
  # LLM INTEGRATION
  # ============================================================================

  defp call_llm(prompt) do
    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@llm_base_url}/chat/completions",
        json: %{
          model: @llm_model,
          messages: [
            %{
              role: "system",
              content:
                "Você é um assistente especializado em educação brasileira. Responda sempre em português e em formato JSON quando solicitado."
            },
            %{role: "user", content: prompt}
          ],
          max_tokens: 4000,
          temperature: 0.7
        },
        headers: auth_headers(),
        receive_timeout: 120_000
      )

    case result do
      {:ok, %{status: 200, body: body}} ->
        content = get_in(body, ["choices", Access.at(0), "message", "content"])
        processing_time = System.monotonic_time(:millisecond) - start_time
        Logger.info("Planning LLM call completed in #{processing_time}ms")
        {:ok, content}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Planning LLM error #{status}: #{inspect(body)}")
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        Logger.error("Planning LLM request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp auth_headers do
    api_key = Application.get_env(:hellen, :nvidia_api_key)

    [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]
  end

  # ============================================================================
  # RESPONSE PARSING
  # ============================================================================

  defp parse_planning_response(response, subject, grade_level, duration) do
    # Extract JSON from response (handle markdown code blocks)
    json_str =
      response
      |> String.trim()
      |> extract_json()

    case Jason.decode(json_str) do
      {:ok, data} ->
        planning_attrs = %{
          title: data["title"] || "Plano de Aula",
          description: data["description"],
          subject: normalize_subject(subject),
          grade_level: normalize_grade_level(grade_level),
          duration_minutes: duration,
          objectives: data["objectives"] || [],
          bncc_codes: data["bncc_codes"] || [],
          content: data["content"] || %{},
          materials: data["materials"] || [],
          methodology: data["methodology"],
          assessment_criteria: data["assessment_criteria"]
        }

        {:ok, planning_attrs}

      {:error, _} ->
        Logger.warning("Failed to parse planning JSON: #{String.slice(json_str, 0, 200)}")
        {:error, :invalid_json_response}
    end
  end

  defp parse_improvement_response(response) do
    json_str = extract_json(response)

    case Jason.decode(json_str) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:error, :invalid_json_response}
    end
  end

  defp extract_json(text) do
    # Try to extract JSON from markdown code blocks
    case Regex.run(~r/```(?:json)?\s*\n?([\s\S]*?)\n?```/, text) do
      [_, json] -> String.trim(json)
      nil -> String.trim(text)
    end
  end

  defp normalize_subject(nil), do: "portugues"

  defp normalize_subject(subject) do
    subject
    |> String.downcase()
    |> String.replace(~r/[áàãâä]/, "a")
    |> String.replace(~r/[éèêë]/, "e")
    |> String.replace(~r/[íìîï]/, "i")
    |> String.replace(~r/[óòõôö]/, "o")
    |> String.replace(~r/[úùûü]/, "u")
    |> String.replace(~r/ç/, "c")
    |> String.replace(~r/\s+/, "_")
    |> then(fn s ->
      if s in Planning.subjects(), do: s, else: "portugues"
    end)
  end

  defp normalize_grade_level(nil), do: "5_ano"

  defp normalize_grade_level(level) do
    level
    |> String.downcase()
    |> String.replace(~r/º\s*/, "_")
    |> String.replace(~r/\s+/, "_")
    |> then(fn s ->
      if s in Planning.grade_levels(), do: s, else: "5_ano"
    end)
  end
end
