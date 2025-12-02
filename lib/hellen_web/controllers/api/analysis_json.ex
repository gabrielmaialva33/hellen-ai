defmodule HellenWeb.API.AnalysisJSON do
  alias Hellen.Analysis.{Analysis, BnccMatch, BullyingAlert}

  def index(%{analyses: analyses}) do
    %{data: for(analysis <- analyses, do: data(analysis))}
  end

  def show(%{analysis: analysis}) do
    %{data: data_with_details(analysis)}
  end

  defp data(%Analysis{} = analysis) do
    %{
      id: analysis.id,
      analysis_type: analysis.analysis_type,
      model_used: analysis.model_used,
      overall_score: analysis.overall_score,
      processing_time_ms: analysis.processing_time_ms,
      tokens_used: analysis.tokens_used,
      inserted_at: analysis.inserted_at
    }
  end

  defp data_with_details(%Analysis{} = analysis) do
    analysis
    |> data()
    |> Map.merge(%{
      result: analysis.result,
      bncc_matches: bncc_matches_data(analysis),
      bullying_alerts: bullying_alerts_data(analysis)
    })
  end

  defp bncc_matches_data(%{bncc_matches: %Ecto.Association.NotLoaded{}}), do: []

  defp bncc_matches_data(%{bncc_matches: matches}) do
    Enum.map(matches, fn %BnccMatch{} = match ->
      %{
        id: match.id,
        competencia_code: match.competencia_code,
        competencia_name: match.competencia_name,
        match_score: match.match_score,
        evidence_text: match.evidence_text
      }
    end)
  end

  defp bullying_alerts_data(%{bullying_alerts: %Ecto.Association.NotLoaded{}}), do: []

  defp bullying_alerts_data(%{bullying_alerts: alerts}) do
    Enum.map(alerts, fn %BullyingAlert{} = alert ->
      %{
        id: alert.id,
        severity: alert.severity,
        alert_type: alert.alert_type,
        description: alert.description,
        evidence_text: alert.evidence_text,
        reviewed: alert.reviewed
      }
    end)
  end
end
