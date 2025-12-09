defmodule Hellen.AI.AssessmentGenerator do
  @moduledoc """
  AI-powered assessment (prova) generator.

  Uses NVIDIA NIM LLM to generate structured assessments from:
  - Lesson plannings
  - Topic descriptions
  - BNCC competency codes

  Features:
  - Multiple question types support
  - Difficulty level customization
  - BNCC alignment
  - Answer key generation
  - Rubric suggestions
  """

  require Logger

  alias Hellen.AI.Embeddings
  alias Hellen.Assessments
  alias Hellen.Assessments.Assessment
  alias Hellen.Plannings

  # NVIDIA NIM API
  @llm_base_url "https://integrate.api.nvidia.com/v1"
  @llm_model "nvidia/llama-3.1-nemotron-70b-instruct"

  # ============================================================================
  # GENERATION FROM PLANNING
  # ============================================================================

  @doc """
  Generates an assessment from an existing lesson planning.

  ## Options
    * `:assessment_type` - Type of assessment (default: "prova")
    * `:difficulty_level` - Difficulty level (default: "medio")
    * `:num_questions` - Number of questions (default: 10)
    * `:question_types` - List of question types to include
    * `:duration_minutes` - Duration in minutes
  """
  def from_planning(planning_id, user_id, opts \\ []) do
    with {:ok, planning} <- get_planning(planning_id),
         {:ok, assessment_data} <- generate_assessment_from_planning(planning, opts) do
      attrs =
        assessment_data
        |> Map.put(:user_id, user_id)
        |> Map.put(:source_planning_id, planning_id)
        |> Map.put(:institution_id, planning.institution_id)
        |> Map.put(:generated_by_ai, true)

      Assessments.create_ai_assessment(attrs)
    end
  end

  @doc """
  Generates an assessment from a topic description.

  ## Options
    * `:assessment_type` - Type of assessment (default: "prova")
    * `:difficulty_level` - Difficulty level (default: "medio")
    * `:num_questions` - Number of questions (default: 10)
    * `:question_types` - List of question types to include
    * `:duration_minutes` - Duration in minutes
  """
  def from_topic(topic, subject, grade_level, user_id, opts \\ []) do
    with {:ok, bncc_matches} <- find_bncc_matches(topic),
         {:ok, assessment_data} <-
           generate_assessment_from_topic(topic, subject, grade_level, bncc_matches, opts) do
      attrs =
        assessment_data
        |> Map.put(:user_id, user_id)
        |> Map.put(:generated_by_ai, true)

      Assessments.create_ai_assessment(attrs)
    end
  end

  @doc """
  Generates additional questions for an existing assessment.
  """
  def generate_more_questions(assessment, num_questions, opts \\ []) do
    question_types = Keyword.get(opts, :question_types, ["multiple_choice"])
    difficulty = Keyword.get(opts, :difficulty_level, assessment.difficulty_level)

    prompt =
      build_additional_questions_prompt(assessment, num_questions, question_types, difficulty)

    case call_llm(prompt) do
      {:ok, response} ->
        parse_questions_response(response)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Improves an existing assessment with AI suggestions.
  """
  def improve_assessment(assessment, focus_areas \\ []) do
    prompt = build_improvement_prompt(assessment, focus_areas)

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

  defp get_planning(planning_id) do
    try do
      planning = Plannings.get_planning!(planning_id)
      {:ok, planning}
    rescue
      Ecto.NoResultsError ->
        {:error, :planning_not_found}
    end
  end

  defp find_bncc_matches(text) do
    case Embeddings.match_bncc(text, limit: 5) do
      {:ok, matches} ->
        codes = Enum.map(matches, & &1.payload["code"])
        {:ok, codes}

      {:error, _reason} ->
        {:ok, []}
    end
  end

  defp generate_assessment_from_planning(planning, opts) do
    assessment_type = Keyword.get(opts, :assessment_type, "prova")
    difficulty = Keyword.get(opts, :difficulty_level, "medio")
    num_questions = Keyword.get(opts, :num_questions, 10)

    question_types =
      Keyword.get(opts, :question_types, ["multiple_choice", "true_false", "short_answer"])

    duration = Keyword.get(opts, :duration_minutes, 60)

    prompt = """
    Você é um especialista em educação brasileira. Crie uma #{assessment_type_text(assessment_type)} baseada no plano de aula abaixo.

    PLANO DE AULA:
    Título: #{planning.title}
    Descrição: #{planning.description || ""}
    Disciplina: #{planning.subject}
    Ano/Série: #{planning.grade_level}
    Objetivos: #{Enum.join(planning.objectives || [], "; ")}
    Códigos BNCC: #{Enum.join(planning.bncc_codes || [], ", ")}
    Metodologia: #{planning.methodology || ""}

    CONFIGURAÇÕES DA AVALIAÇÃO:
    - Tipo: #{assessment_type_text(assessment_type)}
    - Nível de dificuldade: #{difficulty_text(difficulty)}
    - Número de questões: #{num_questions}
    - Tipos de questões permitidos: #{Enum.join(question_types, ", ")}
    - Duração: #{duration} minutos

    #{question_type_instructions()}

    Gere um JSON com a seguinte estrutura (responda APENAS com o JSON, sem texto adicional):
    #{assessment_json_template()}
    """

    case call_llm(prompt) do
      {:ok, response} ->
        parse_assessment_response(
          response,
          planning.subject,
          planning.grade_level,
          assessment_type,
          difficulty,
          duration
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_assessment_from_topic(topic, subject, grade_level, bncc_codes, opts) do
    assessment_type = Keyword.get(opts, :assessment_type, "prova")
    difficulty = Keyword.get(opts, :difficulty_level, "medio")
    num_questions = Keyword.get(opts, :num_questions, 10)

    question_types =
      Keyword.get(opts, :question_types, ["multiple_choice", "true_false", "short_answer"])

    duration = Keyword.get(opts, :duration_minutes, 60)

    prompt = """
    Você é um especialista em educação brasileira. Crie uma #{assessment_type_text(assessment_type)} sobre o tema especificado.

    TEMA: #{topic}

    INFORMAÇÕES:
    - Disciplina: #{subject}
    - Ano/Série: #{grade_level}
    - Códigos BNCC sugeridos: #{Enum.join(bncc_codes, ", ")}

    CONFIGURAÇÕES DA AVALIAÇÃO:
    - Tipo: #{assessment_type_text(assessment_type)}
    - Nível de dificuldade: #{difficulty_text(difficulty)}
    - Número de questões: #{num_questions}
    - Tipos de questões permitidos: #{Enum.join(question_types, ", ")}
    - Duração: #{duration} minutos

    #{question_type_instructions()}

    Gere um JSON com a seguinte estrutura (responda APENAS com o JSON, sem texto adicional):
    #{assessment_json_template()}
    """

    case call_llm(prompt) do
      {:ok, response} ->
        parse_assessment_response(
          response,
          subject,
          grade_level,
          assessment_type,
          difficulty,
          duration
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_additional_questions_prompt(assessment, num_questions, question_types, difficulty) do
    existing_questions =
      (assessment.questions || [])
      |> Enum.map_join("\n- ", fn q -> q["text"] end)

    """
    Você é um especialista em educação brasileira. Gere #{num_questions} questões adicionais para esta avaliação.

    AVALIAÇÃO EXISTENTE:
    Título: #{assessment.title}
    Disciplina: #{assessment.subject}
    Ano/Série: #{assessment.grade_level}
    Tipo: #{assessment.assessment_type}

    QUESTÕES JÁ EXISTENTES (não repita):
    - #{existing_questions}

    CONFIGURAÇÕES:
    - Nível de dificuldade: #{difficulty_text(difficulty)}
    - Tipos de questões: #{Enum.join(question_types, ", ")}

    #{question_type_instructions()}

    Gere um JSON com a seguinte estrutura:
    {
      "questions": [
        // Array de questões no formato especificado acima
      ]
    }
    """
  end

  defp build_improvement_prompt(assessment, focus_areas) do
    focus_text =
      if Enum.empty?(focus_areas) do
        "clareza das questões, equilíbrio de dificuldade, alinhamento BNCC"
      else
        Enum.join(focus_areas, ", ")
      end

    questions_preview =
      (assessment.questions || [])
      |> Enum.take(5)
      |> Enum.map_join("\n", fn q ->
        "#{q["type"]}: #{String.slice(q["text"] || "", 0, 100)}..."
      end)

    """
    Você é um especialista em educação brasileira. Analise esta avaliação e sugira melhorias.

    AVALIAÇÃO:
    Título: #{assessment.title}
    Disciplina: #{assessment.subject}
    Ano/Série: #{assessment.grade_level}
    Tipo: #{assessment.assessment_type}
    Dificuldade: #{assessment.difficulty_level}
    Número de questões: #{length(assessment.questions || [])}

    AMOSTRA DE QUESTÕES:
    #{questions_preview}

    FOCO DAS MELHORIAS: #{focus_text}

    Responda em JSON com sugestões específicas:
    {
      "suggestions": [
        {"area": "Questões", "issue": "...", "improvement": "...", "priority": "alta|media|baixa"},
        {"area": "Dificuldade", "issue": "...", "improvement": "...", "priority": "alta|media|baixa"}
      ],
      "question_improvements": [
        {"question_index": 0, "current": "...", "improved": "...", "reason": "..."}
      ],
      "additional_recommendations": ["Recomendação 1", "Recomendação 2"]
    }
    """
  end

  defp question_type_instructions do
    """
    FORMATOS DE QUESTÕES:

    1. multiple_choice (Múltipla Escolha):
    {
      "type": "multiple_choice",
      "text": "Texto da pergunta",
      "options": ["A) Opção 1", "B) Opção 2", "C) Opção 3", "D) Opção 4"],
      "correct_answer": "A",
      "points": 1,
      "difficulty": "facil|medio|dificil",
      "explanation": "Explicação da resposta correta"
    }

    2. true_false (Verdadeiro/Falso):
    {
      "type": "true_false",
      "text": "Afirmação para avaliar",
      "correct_answer": true,
      "points": 1,
      "difficulty": "facil|medio|dificil",
      "explanation": "Explicação"
    }

    3. short_answer (Resposta Curta):
    {
      "type": "short_answer",
      "text": "Pergunta que requer resposta breve",
      "expected_answer": "Resposta esperada",
      "points": 2,
      "difficulty": "medio",
      "keywords": ["palavra-chave1", "palavra-chave2"]
    }

    4. essay (Dissertativa):
    {
      "type": "essay",
      "text": "Questão dissertativa",
      "points": 5,
      "difficulty": "dificil",
      "rubric": {
        "criteria": ["Critério 1", "Critério 2"],
        "max_words": 200
      }
    }

    5. fill_blank (Preencher Lacunas):
    {
      "type": "fill_blank",
      "text": "Texto com _____ para preencher",
      "blanks": ["resposta1", "resposta2"],
      "points": 1,
      "difficulty": "facil"
    }

    6. matching (Associação):
    {
      "type": "matching",
      "text": "Associe as colunas:",
      "left_column": ["Item A", "Item B", "Item C"],
      "right_column": ["Definição 1", "Definição 2", "Definição 3"],
      "correct_matches": {"0": "1", "1": "0", "2": "2"},
      "points": 3,
      "difficulty": "medio"
    }
    """
  end

  defp assessment_json_template do
    """
    {
      "title": "Título da Avaliação",
      "description": "Breve descrição do que será avaliado",
      "instructions": "Instruções para os alunos",
      "bncc_codes": ["Código BNCC 1", "Código BNCC 2"],
      "questions": [
        // Array de questões seguindo os formatos acima
      ],
      "answer_key": {
        "0": "resposta_questao_0",
        "1": "resposta_questao_1"
      },
      "rubrics": {
        "general": "Critérios gerais de avaliação",
        "partial_credit": "Regras para crédito parcial"
      }
    }
    """
  end

  defp assessment_type_text("prova"), do: "prova"
  defp assessment_type_text("atividade"), do: "atividade avaliativa"
  defp assessment_type_text("simulado"), do: "simulado"
  defp assessment_type_text("exercicio"), do: "lista de exercícios"
  defp assessment_type_text("trabalho"), do: "trabalho"
  defp assessment_type_text("quiz"), do: "quiz rápido"
  defp assessment_type_text(_), do: "avaliação"

  defp difficulty_text("facil"), do: "Fácil (questões diretas e básicas)"
  defp difficulty_text("medio"), do: "Médio (equilíbrio entre básico e desafiador)"
  defp difficulty_text("dificil"), do: "Difícil (questões que exigem análise e síntese)"
  defp difficulty_text("misto"), do: "Misto (progressão de fácil a difícil)"
  defp difficulty_text(_), do: "Médio"

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
                "Você é um assistente especializado em educação brasileira. Crie avaliações pedagogicamente adequadas. Responda sempre em português e em formato JSON quando solicitado."
            },
            %{role: "user", content: prompt}
          ],
          max_tokens: 8000,
          temperature: 0.7
        },
        headers: auth_headers(),
        receive_timeout: 180_000
      )

    case result do
      {:ok, %{status: 200, body: body}} ->
        content = get_in(body, ["choices", Access.at(0), "message", "content"])
        processing_time = System.monotonic_time(:millisecond) - start_time
        Logger.info("Assessment LLM call completed in #{processing_time}ms")
        {:ok, content}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Assessment LLM error #{status}: #{inspect(body)}")
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        Logger.error("Assessment LLM request failed: #{inspect(reason)}")
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

  defp parse_assessment_response(
         response,
         subject,
         grade_level,
         assessment_type,
         difficulty,
         duration
       ) do
    json_str =
      response
      |> String.trim()
      |> extract_json()

    case Jason.decode(json_str) do
      {:ok, data} ->
        assessment_attrs = %{
          title: data["title"] || "Avaliação",
          description: data["description"],
          subject: normalize_subject(subject),
          grade_level: normalize_grade_level(grade_level),
          assessment_type: assessment_type,
          difficulty_level: difficulty,
          duration_minutes: duration,
          instructions: data["instructions"],
          bncc_codes: data["bncc_codes"] || [],
          questions: data["questions"] || [],
          answer_key: data["answer_key"] || %{},
          rubrics: data["rubrics"] || %{},
          total_points: calculate_total_points(data["questions"] || [])
        }

        {:ok, assessment_attrs}

      {:error, _} ->
        Logger.warning("Failed to parse assessment JSON: #{String.slice(json_str, 0, 200)}")
        {:error, :invalid_json_response}
    end
  end

  defp parse_questions_response(response) do
    json_str = extract_json(response)

    case Jason.decode(json_str) do
      {:ok, %{"questions" => questions}} -> {:ok, questions}
      {:ok, _} -> {:error, :invalid_response_format}
      {:error, _} -> {:error, :invalid_json_response}
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
    case Regex.run(~r/```(?:json)?\s*\n?([\s\S]*?)\n?```/, text) do
      [_, json] -> String.trim(json)
      nil -> String.trim(text)
    end
  end

  defp calculate_total_points(questions) do
    questions
    |> Enum.map(fn q -> Decimal.new(to_string(q["points"] || "1")) end)
    |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
  end

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
      if s in Assessment.subjects(), do: s, else: "portugues"
    end)
  end

  defp normalize_grade_level(level) do
    level
    |> String.downcase()
    |> String.replace(~r/º\s*/, "_")
    |> String.replace(~r/\s+/, "_")
    |> then(fn s ->
      if s in Assessment.grade_levels(), do: s, else: "5_ano"
    end)
  end
end
