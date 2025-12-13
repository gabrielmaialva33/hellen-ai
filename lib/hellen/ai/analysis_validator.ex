defmodule Hellen.AI.AnalysisValidator do
  @moduledoc """
  Validates lesson analysis with pedagogical rigor (v3.0).
  Detects inflated scores by analyzing specific markers for:
  - Law 13.185 (Anti-bullying) compliance vs violation
  - Sarcasm and toxicity
  - Student disengagement
  - Inclusion gaps
  """

  @doc """
  Validates an analysis result against the original transcription.
  Returns {:ok, validated_result} with potentially adjusted score and warnings.
  """
  def validate_analysis(transcription, analysis_result)
      when is_binary(transcription) and is_map(analysis_result) do
    # 1. Calculate Rigorous Score (v3.0)
    rigorous_score = calculate_rigorous_score(transcription)

    # 2. Compare with current score
    current_score =
      Map.get(analysis_result, "overall_score") || Map.get(analysis_result, :overall_score) || 0.0

    # Normalize current score to 0-100 integer if it's 0.0-1.0 float
    current_score_int =
      if current_score <= 1.0, do: round(current_score * 100), else: round(current_score)

    delta = current_score_int - rigorous_score

    if delta > 30 do
      # 3. Flag discrepancy
      warning = %{
        "type" => "inflated_score",
        "current_score" => current_score_int,
        "rigorous_score" => rigorous_score,
        "delta" => delta,
        "reason" =>
          "Pedagogical inconsistencies detected (Law 13.185 violation or disengagement)",
        "recommendation" =>
          "Review teaching methodology regarding inclusion and psychological safety."
      }

      # Adjust result to include warning
      updated_result = Map.put(analysis_result, "validation_warning", warning)

      # Optionally adjust the score? For now, we just flag it.
      # But user wants "Real Score". Let's inject the rigorous score too.
      updated_result = Map.put(updated_result, "rigorous_score", rigorous_score)

      {:ok, updated_result}
    else
      {:ok, Map.put(analysis_result, "rigorous_score", rigorous_score)}
    end
  end

  def validate_analysis(_, result), do: {:ok, result}

  defp calculate_rigorous_score(transcription) do
    scores = [
      lei_13185_compliance(transcription),
      inclusion_compliance(transcription),
      classroom_climate(transcription),
      # Base baseline for other dimensions we can't regex easily
      {:normal, 60}
    ]

    # Calculate weighted average
    {total_score, total_weight} =
      Enum.reduce(scores, {0, 0}, fn
        # Critical weight 2x
        {:critical, val}, {sum, weight} -> {sum + val * 2, weight + 2}
        {:normal, val}, {sum, weight} -> {sum + val, weight + 1}
      end)

    round(total_score / total_weight)
  end

  # --- Dimensions Implementation ---

  # Lei 13.185: Detects bullying WITHIN the classroom
  defp lei_13185_compliance(transcription) do
    has_sarcasm = detect_sarcasm(transcription)
    has_public_shame = Regex.match?(~r/você tem que|tem essa mania|cheirou assim/i, transcription)
    has_disengagement = detect_disengagement(transcription)
    teaching_bullying = Regex.match?(~r/cyberbullying|bullying|agressão/i, transcription)

    cond do
      # Teaching about bullying but practicing it (Critical Violation)
      teaching_bullying and (has_sarcasm or has_public_shame) ->
        {:critical, 20}

      # Just disengagement
      has_disengagement ->
        {:critical, 40}

      # Clean
      true ->
        {:normal, 80}
    end
  end

  # Inclusion: Detects if ALL students are engaged
  defp inclusion_compliance(transcription) do
    missing_students = Regex.match?(~r/não sei onde está|cadê/i, transcription)
    sleeping_students = Regex.match?(~r/dormiu|dorme|acorda/i, transcription)

    if missing_students or sleeping_students do
      {:critical, 15}
    else
      {:normal, 75}
    end
  end

  # Classroom Climate: Psychological Safety
  defp classroom_climate(transcription) do
    has_sarcasm = detect_sarcasm(transcription)
    has_laughter_at_student = Regex.match?(~r/perfume|risos|constrangimento/i, transcription)

    base = 70

    deduction =
      if(has_sarcasm, do: 15, else: 0) +
        if has_laughter_at_student, do: 20, else: 0

    {:normal, max(0, base - deduction)}
  end

  # --- Detectors ---

  defp detect_sarcasm(text) do
    patterns = [
      # "Só sim?"
      ~r/Só\s+\w+\?/i,
      # "Você tem mania"
      ~r/Você tem (essa )?mania/i,
      # "Claro, né"
      ~r/Claro,?\s+né/i
    ]

    Enum.any?(patterns, &Regex.match?(&1, text))
  end

  defp detect_disengagement(text) do
    patterns = [
      ~r/dormiu|dorme|dormente/i,
      ~r/não sei onde/i,
      ~r/silêncio/i
    ]

    Enum.any?(patterns, &Regex.match?(&1, text))
  end
end
