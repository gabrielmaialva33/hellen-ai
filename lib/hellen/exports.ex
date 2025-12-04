defmodule Hellen.Exports do
  @moduledoc """
  Context for generating CSV exports of analytics data.
  """

  alias Hellen.Analysis

  @doc """
  Generate CSV content for various export types.

  ## Types
  - `:score_history` - Score history for a user
  - `:bncc_coverage` - BNCC coverage details
  - `:alerts` - Bullying alerts (requires institution_id)
  - `:daily_scores` - Daily score averages
  """
  def generate_csv(type, id, opts \\ [])

  def generate_csv(:score_history, user_id, opts) do
    analyses = Analysis.list_analyses_for_export(user_id, opts)

    headers = ["Data", "Aula", "Score", "Competencias BNCC", "Alertas"]

    rows =
      Enum.map(analyses, fn analysis ->
        [
          format_date(analysis.inserted_at),
          analysis.lesson.title,
          format_score(analysis.overall_score),
          length(analysis.bncc_matches),
          length(analysis.bullying_alerts)
        ]
      end)

    build_csv(headers, rows)
  end

  def generate_csv(:bncc_coverage, user_id, opts) do
    coverage = Analysis.get_bncc_coverage_detailed(user_id, opts)

    headers = [
      "Codigo",
      "Competencia",
      "Categoria",
      "Ocorrencias",
      "Score Medio",
      "Score Min",
      "Score Max"
    ]

    rows =
      Enum.map(coverage, fn item ->
        [
          item.code || "N/A",
          item.name || "N/A",
          item.category,
          item.count,
          format_score(item.avg_score),
          format_score(item.min_score),
          format_score(item.max_score)
        ]
      end)

    build_csv(headers, rows)
  end

  def generate_csv(:alerts, institution_id, opts) do
    alerts = Analysis.list_alerts_by_institution(institution_id, opts)

    headers = ["Data", "Aula", "Tipo", "Severidade", "Descricao", "Status"]

    rows =
      Enum.map(alerts, fn alert ->
        [
          format_date(alert.inserted_at),
          alert.analysis.lesson.title,
          translate_alert_type(alert.alert_type),
          translate_severity(alert.severity),
          alert.description || "N/A",
          if(alert.reviewed, do: "Revisado", else: "Pendente")
        ]
      end)

    build_csv(headers, rows)
  end

  def generate_csv(:daily_scores, user_id, opts) do
    scores = Analysis.get_daily_scores(user_id, opts)

    headers = ["Data", "Score Medio", "Quantidade de Analises"]

    rows =
      Enum.map(scores, fn item ->
        [
          Date.to_string(item.date),
          format_score(item.avg_score),
          item.count
        ]
      end)

    build_csv(headers, rows)
  end

  defp build_csv(headers, rows) do
    header_line = Enum.join(headers, ",")

    data_lines =
      Enum.map(rows, fn row ->
        Enum.map_join(row, ",", &escape_csv_field/1)
      end)

    Enum.join([header_line | data_lines], "\n")
  end

  defp escape_csv_field(nil), do: ""
  defp escape_csv_field(value) when is_number(value), do: to_string(value)

  defp escape_csv_field(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end

  defp escape_csv_field(value), do: to_string(value)

  defp format_date(nil), do: "N/A"
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  defp format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  defp format_date(date), do: to_string(date)

  defp format_score(nil), do: "N/A"

  defp format_score(score) when is_float(score) do
    score |> Float.round(2) |> to_string()
  end

  defp format_score(score) when is_integer(score) do
    to_string(score)
  end

  defp format_score(%Decimal{} = score) do
    score |> Decimal.round(2) |> Decimal.to_string()
  end

  defp translate_alert_type("bullying"), do: "Bullying"
  defp translate_alert_type("harassment"), do: "Assedio"
  defp translate_alert_type("discrimination"), do: "Discriminacao"
  defp translate_alert_type("violence"), do: "Violencia"
  defp translate_alert_type(type), do: type || "N/A"

  defp translate_severity("high"), do: "Alta"
  defp translate_severity("medium"), do: "Media"
  defp translate_severity("low"), do: "Baixa"
  defp translate_severity(sev), do: sev || "N/A"
end
