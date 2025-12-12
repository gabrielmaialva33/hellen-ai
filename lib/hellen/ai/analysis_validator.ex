defmodule Hellen.AI.AnalysisValidator do
  @moduledoc """
  Valida análises de aulas com rigor pedagógico.
  Detecta scores inflados comparando o score da IA com uma análise heurística rigorosa (v3.0).
  """

  def validate_analysis(llm_score, transcription, context) do
    # Current score from LLM (0.0-1.0 to 0-100)
    current_score = round((llm_score || 0) * 100)

    # V3.0 (rigoroso)
    rigorous_score = calculate_rigorous_score(transcription, context)

    case {current_score, rigorous_score} do
      {current, rigorous} when rigorous < current - 30 ->
        # Flag discrepância
        {:warning,
         %{
           current: current,
           rigorous: rigorous,
           delta: current - rigorous,
           reason: "Score inflado por ignorar qualidade pedagógica e conformidade legal",
           recommendation: "Use Prompts v3.0 para análise completa"
         }}

      _ ->
        {:ok, %{current: current_score, rigorous: rigorous_score}}
    end
  end

  defp calculate_rigorous_score(transcription, context) do
    dimensions = [
      bncc_alignment(transcription, context),
      lei_13185_compliance(transcription),
      lei_13718_compliance(transcription),
      general_competencies(transcription, context),
      socioemotional_competencies(transcription),
      engagement_level(transcription),
      seduc_strategies(transcription),
      inclusion_compliance(transcription),
      classroom_climate(transcription),
      digital_citizenship(transcription),
      assessment_quality(transcription),
      time_management(transcription),
      closing_quality(transcription)
    ]

    # Média ponderada (alguns pesos > 1)
    {sum, weights} =
      dimensions
      |> Enum.reduce({0, 0}, fn score, {sum, weight} ->
        case score do
          # Critical = peso 2
          {:critical, val} -> {sum + val, weight + 2}
          {:normal, val} -> {sum + val, weight + 1}
        end
      end)

    if weights > 0, do: round(sum / weights), else: 0
  end

  # Detector de sarcasmo/ironia (padrão: "Só ..?", "Você tem mania...")
  defp detect_sarcasm(transcription) do
    sarcasm_patterns = [
      # "Só sim?"
      ~r/Só\s+\w+\?/i,
      # "Você tem mania"
      ~r/Você tem (essa )?mania/i,
      # "Claro, né, fulano"
      ~r/Claro,?\s+né,?\s+\w+/i
    ]

    Enum.any?(sarcasm_patterns, &String.match?(transcription, &1))
  end

  # Detector de alunos dormindo/desengajados
  defp detect_disengagement(transcription) do
    disengagement_markers = [
      ~r/dormiu|dorme|dormente/i,
      ~r/não sei onde|desaparecido/i,
      ~r/Ninguém\?|silêncio|nada/i
    ]

    count =
      Enum.count(disengagement_markers, fn pattern ->
        String.match?(transcription, pattern)
      end)

    count > 0
  end

  defp bncc_alignment(_transcription, _context) do
    # Simplificação: Assume alinhamento base por padrão, mas penaliza se muito curto
    # Na v3.0 real, isso seria mais complexo. Aqui seguimos a lógica:
    # "CUMPRE BNCC" mas execução pode ser falha.
    {:normal, 65}
  end

  defp general_competencies(_transcription, _context) do
    {:normal, 45}
  end

  defp socioemotional_competencies(transcription) do
    if detect_sarcasm(transcription) or detect_disengagement(transcription) do
      {:critical, 25}
    else
      {:normal, 85}
    end
  end

  defp engagement_level(transcription) do
    if detect_disengagement(transcription), do: {:normal, 55}, else: {:normal, 80}
  end

  defp seduc_strategies(transcription) do
    # Verifica leitura colaborativa (ponto forte mencionado)
    if String.match?(transcription, ~r/leitura|ler/i) do
      # Execução falha nos exercícios
      {:normal, 40}
    else
      {:normal, 30}
    end
  end

  defp assessment_quality(_transcription), do: {:normal, 40}
  defp time_management(_transcription), do: {:normal, 50}
  defp closing_quality(_transcription), do: {:normal, 20}

  # Lei 13.185: Detecta bullying DENTRO da aula
  defp lei_13185_compliance(transcription) do
    has_sarcasm = detect_sarcasm(transcription)
    has_public_shame = String.match?(transcription, ~r/você tem que|tem essa mania/i)
    has_disengagement = detect_disengagement(transcription)

    teaching_bullying = String.match?(transcription, ~r/cyberbullying|bullying|agressão/i)

    cond do
      # Ensinando sobre bullying mas praticando = -40 pontos
      teaching_bullying and (has_sarcasm or has_public_shame) ->
        {:critical, 20}

      # Apenas desengajamento
      has_disengagement ->
        {:critical, 40}

      # Nenhum sinal
      true ->
        {:normal, 70}
    end
  end

  # Lei 13.718: Detecta ensino prático de segurança digital
  defp lei_13718_compliance(transcription) do
    teaches_prevention = String.match?(transcription, ~r/prevenção|segurança|proteção/i)
    teaches_responsibility = String.match?(transcription, ~r/responsabilidade|ético|cuidado/i)
    teaches_reporting = String.match?(transcription, ~r/denúncia|boletim|policía|ajuda/i)

    score =
      if(teaches_prevention, do: 30, else: 0) +
        if(teaches_responsibility, do: 30, else: 0) +
        if teaches_reporting, do: 40, else: 0

    # Mínimo 10%
    {:normal, max(score, 10)}
  end

  # Inclusão: Detecta se TODOS os alunos estão engajados
  defp inclusion_compliance(transcription) do
    missing_students = String.match?(transcription, ~r/não sei onde está/i)
    sleeping_students = String.match?(transcription, ~r/dormiu|dorme/i)
    public_shame = String.match?(transcription, ~r/você tem que|mania/i)

    cond do
      missing_students or (sleeping_students and public_shame) ->
        {:critical, 15}

      sleeping_students ->
        {:critical, 30}

      true ->
        {:normal, 70}
    end
  end

  # Clima escolar: Detecta segurança psicológica
  defp classroom_climate(transcription) do
    has_sarcasm = detect_sarcasm(transcription)
    has_laughter_at_student = String.match?(transcription, ~r/perfume|risos|constrangimento/i)
    has_critical_tone = String.match?(transcription, ~r/você tem mania|explicou|erraste/i)

    safety_factors =
      if(has_sarcasm, do: -15, else: 0) +
        if(has_laughter_at_student, do: -20, else: 0) +
        if has_critical_tone, do: -10, else: 0

    {:normal, 70 + safety_factors}
  end

  # Cidadania Digital
  defp digital_citizenship(transcription) do
    teaches_ethics = String.match?(transcription, ~r/ética|respeito/i)
    teaches_safety = String.match?(transcription, ~r/segurança|privacidade/i)

    score = if(teaches_ethics, do: 30, else: 0) + if teaches_safety, do: 20, else: 0
    # Base 30% from user input if misses key components
    score = if score == 0, do: 30, else: score
    {:normal, score}
  end
end
