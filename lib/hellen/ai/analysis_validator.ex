defmodule Hellen.AI.AnalysisValidator do
  @moduledoc """
  Validates lesson analysis with pedagogical rigor (v5.0).

  Comprehensive validation using:
  - BehaviorDetector: Pattern-based detection of problematic behaviors
  - ContextDetector: Identifies contradictions between lesson topic and teacher behavior
  - LegalComplianceChecker: Validates compliance with Lei 13.185/2015

  Calculates rigorous score based on actual classroom behavior,
  independent of LLM assessment for verification.
  """

  alias Hellen.AI.BehaviorDetector
  alias Hellen.AI.ContextDetector
  alias Hellen.AI.LegalComplianceChecker

  @doc """
  Validates an analysis result against the original transcription.
  Returns {:ok, validated_result} with potentially adjusted score and warnings.
  """
  def validate_analysis(transcription, analysis_result)
      when is_binary(transcription) and is_map(analysis_result) do
    # 1. Run all detectors
    behavior_report = BehaviorDetector.analyze(transcription)
    context_report = ContextDetector.analyze(transcription)
    compliance_report = LegalComplianceChecker.check_compliance(transcription)

    # 2. Calculate Rigorous Score (weighted combination)
    rigorous_score = calculate_rigorous_score(behavior_report, context_report, compliance_report)

    # 3. Compare with current score
    current_score =
      Map.get(analysis_result, "overall_score") || Map.get(analysis_result, :overall_score) || 0.0

    # Normalize current score to 0-100 integer if it's 0-1.0 float
    current_score_int =
      if current_score <= 1.0, do: round(current_score * 100), else: round(current_score)

    delta = current_score_int - rigorous_score

    # 4. Build comprehensive analysis details
    analysis_details =
      build_comprehensive_details(
        behavior_report,
        context_report,
        compliance_report,
        rigorous_score
      )

    if delta > 30 do
      # 5. Flag significant discrepancy
      warning =
        build_discrepancy_warning(
          current_score_int,
          rigorous_score,
          delta,
          behavior_report,
          context_report,
          compliance_report
        )

      # Adjust result to include warning and comprehensive analysis
      updated_result =
        analysis_result
        |> Map.put("validation_warning", warning)
        |> Map.put("rigorous_score", rigorous_score)
        |> Map.put("behavior_analysis", analysis_details)

      {:ok, updated_result}
    else
      # No significant discrepancy, but still include comprehensive analysis
      updated_result =
        analysis_result
        |> Map.put("rigorous_score", rigorous_score)
        |> Map.put("behavior_analysis", analysis_details)

      {:ok, updated_result}
    end
  end

  def validate_analysis(_, result), do: {:ok, result}

  # --- Score Calculation ---

  defp calculate_rigorous_score(behavior_report, context_report, compliance_report) do
    # Weighted formula:
    # - Behavior Safety: 40% (direct classroom climate)
    # - Context/Hypocrisy: 30% (alignment with lesson topic)
    # - Legal Compliance: 30% (Lei 13.185 adherence)

    behavior_weight = 0.40
    context_weight = 0.30
    compliance_weight = 0.30

    behavior_score = behavior_report.safety_score * behavior_weight
    context_score = context_report.hypocrisy_score * context_weight
    compliance_score = compliance_report.combined_score * compliance_weight

    round(behavior_score + context_score + compliance_score)
  end

  # --- Comprehensive Details ---

  defp build_comprehensive_details(
         behavior_report,
         context_report,
         compliance_report,
         rigorous_score
       ) do
    %{
      # Behavior Detection
      "behavior" => %{
        "sarcasm" => format_detection(behavior_report.sarcasm),
        "disengagement" => format_detection(behavior_report.disengagement),
        "public_shame" => format_detection(behavior_report.public_shame),
        "exclusion" => format_detection(behavior_report.exclusion),
        "aggression" => format_detection(behavior_report.aggression),
        "safety_score" => behavior_report.safety_score,
        "summary" => behavior_report.summary
      },

      # Context Analysis
      "context" => %{
        "detected_topics" => Enum.map(context_report.detected_topics, &Atom.to_string/1),
        "teaching_about_bullying" => context_report.teaching_about_bullying,
        "practicing_bullying" => context_report.practicing_bullying,
        "contradictions_count" => length(context_report.contradictions),
        "hypocrisy_score" => context_report.hypocrisy_score,
        "recommendation" => context_report.recommendation
      },

      # Legal Compliance
      "compliance" => %{
        "lei_13185_level" => Atom.to_string(compliance_report.lei_13185.compliance_level),
        "lei_13185_score" => compliance_report.lei_13185.score,
        "lei_13185_risk" => Atom.to_string(compliance_report.lei_13185.risk_level),
        "violations" => compliance_report.lei_13185.violations,
        "recommendations" => compliance_report.lei_13185.recommendations,
        "overall_compliance" => Atom.to_string(compliance_report.overall_compliance),
        "overall_risk" => Atom.to_string(compliance_report.overall_risk),
        "legal_summary" => compliance_report.legal_summary
      },

      # Combined Scores
      "scores" => %{
        "behavior_safety" => behavior_report.safety_score,
        "context_hypocrisy" => context_report.hypocrisy_score,
        "legal_compliance" => compliance_report.combined_score,
        "rigorous_combined" => rigorous_score
      }
    }
  end

  defp format_detection(%{detected: false}), do: nil

  defp format_detection(%{detected: true, severity: severity, evidence: evidence}) do
    %{
      "severity" => Atom.to_string(severity),
      "evidence" => Enum.take(evidence, 3)
    }
  end

  # --- Warning Construction ---

  defp build_discrepancy_warning(
         current_score,
         rigorous_score,
         delta,
         behavior_report,
         context_report,
         compliance_report
       ) do
    %{
      "type" => "inflated_score",
      "current_score" => current_score,
      "rigorous_score" => rigorous_score,
      "delta" => delta,
      "lei_13185_risk" => Atom.to_string(compliance_report.lei_13185.risk_level),
      "overall_risk" => Atom.to_string(compliance_report.overall_risk),
      "reason" => build_warning_reason(behavior_report, context_report, compliance_report),
      "recommendation" => build_recommendation(behavior_report, context_report, compliance_report)
    }
  end

  defp build_warning_reason(behavior_report, context_report, compliance_report) do
    issues =
      collect_behavior_issues(behavior_report) ++
        collect_context_issues(context_report) ++
        collect_compliance_issues(compliance_report)

    format_issues(issues)
  end

  defp collect_behavior_issues(report) do
    issue_checks = [
      {report.sarcasm.detected, "sarcasm patterns"},
      {report.disengagement.detected, "student disengagement"},
      {report.public_shame.detected, "public shaming"},
      {report.exclusion.detected, "exclusion behaviors"},
      {report.aggression.detected, "verbal aggression"}
    ]

    for {detected, label} <- issue_checks, detected, do: label
  end

  defp collect_context_issues(context_report) do
    if context_report.teaching_about_bullying and context_report.practicing_bullying do
      ["teaching-behavior contradiction (hypocrisy)"]
    else
      []
    end
  end

  defp collect_compliance_issues(compliance_report) do
    if compliance_report.overall_risk in [:critical, :high] do
      ["Lei 13.185 compliance risk"]
    else
      []
    end
  end

  defp format_issues([]), do: "Score discrepancy detected without specific markers"
  defp format_issues([single]), do: "Detected #{single}"
  defp format_issues(multiple), do: "Multiple issues: #{Enum.join(multiple, ", ")}"

  defp build_recommendation(behavior_report, context_report, compliance_report) do
    recommendations =
      collect_behavior_recommendations(behavior_report) ++
        collect_context_recommendations(context_report) ++
        collect_compliance_recommendations(compliance_report)

    format_recommendations(recommendations)
  end

  defp collect_behavior_recommendations(report) do
    recommendation_checks = [
      {report.sarcasm.detected, "Replace sarcastic comments with constructive feedback"},
      {report.disengagement.detected,
       "Check on disengaged students and implement engagement strategies"},
      {report.public_shame.detected, "Address student issues privately, never in front of peers"},
      {report.exclusion.detected, "Ensure all students are included in activities"},
      {report.aggression.detected, "Use calm, respectful language when correcting behavior"}
    ]

    for {detected, rec} <- recommendation_checks, detected, do: rec
  end

  defp collect_context_recommendations(context_report) do
    if context_report.teaching_about_bullying and context_report.practicing_bullying do
      ["CRITICAL: Align behavior with lesson topic - contradictions undermine pedagogical value"]
    else
      []
    end
  end

  defp collect_compliance_recommendations(compliance_report) do
    if compliance_report.overall_risk == :critical do
      ["URGENT: Review Lei 13.185 compliance - immediate corrective action required"]
    else
      []
    end
  end

  defp format_recommendations([]),
    do: "Maintain current practices and continue professional development"

  defp format_recommendations([single]), do: single
  defp format_recommendations(multiple), do: "Priority actions: " <> Enum.join(multiple, "; ")
end
