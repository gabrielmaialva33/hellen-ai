defmodule Hellen.Workers.AnalysisJob do
  @moduledoc """
  Oban worker for analyzing lesson transcriptions.
  """

  use Oban.Worker,
    queue: :analysis,
    max_attempts: 3,
    unique: [period: 300, keys: [:lesson_id]]

  alias Hellen.AI.AnalysisValidator
  alias Hellen.AI.NvidiaClient
  alias Hellen.Analysis
  alias Hellen.Lessons
  alias Hellen.Notifications

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"lesson_id" => lesson_id}}) do
    Logger.info("Starting analysis for lesson #{lesson_id}")

    lesson = Lessons.get_lesson_with_transcription!(lesson_id)

    with {:ok, transcription} <- get_transcription(lesson),
         {:ok, result} <- analyze_transcription(lesson, transcription),
         {:ok, analysis} <- save_analysis(lesson, result),
         {:ok, _lesson} <- Lessons.update_lesson_status(lesson, "completed") do
      Logger.info("Analysis completed for lesson #{lesson_id}")
      broadcast_progress(lesson_id, "analysis_complete", %{analysis: analysis})

      # Send notifications asynchronously
      send_notifications(analysis)

      :ok
    else
      {:error, reason} ->
        Logger.error("Analysis failed for lesson #{lesson_id}: #{inspect(reason)}")
        handle_failure(lesson, reason)
    end
  end

  defp get_transcription(%{transcription: nil}) do
    {:error, :no_transcription}
  end

  defp get_transcription(%{transcription: transcription}) do
    {:ok, transcription.full_text}
  end

  defp analyze_transcription(lesson, transcription) do
    context = %{
      subject: lesson.subject,
      grade_level: lesson.grade_level
    }

    case NvidiaClient.analyze_pedagogy(transcription, context) do
      {:ok, result} ->
        # Enrich result with context and transcription for validation
        enriched_result = Map.merge(result, %{transcription: transcription, context: context})
        {:ok, build_analysis_result(enriched_result)}

      {:error, _} = error ->
        error
    end
  end

  defp build_analysis_result(nvidia_result) do
    structured = nvidia_result.structured

    %{
      model: nvidia_result.model,
      # Wrap raw string in a map to match the :map field type in Analysis schema
      raw: %{"content" => nvidia_result.raw},
      structured: structured,
      overall_score: parse_float(structured["overall_score"]),
      processing_time_ms: nvidia_result.processing_time_ms,
      tokens_used: nvidia_result.tokens_used,
      bncc_matches: parse_bncc_matches(structured["bncc_matches"]),
      bullying_alerts: parse_bullying_alerts(structured["bullying_alerts"]),
      validation:
        validate_result(
          nvidia_result.structured["overall_score"],
          nvidia_result.transcription,
          nvidia_result[:context]
        )
    }
  end

  defp validate_result(overall_score, transcription, context) do
    case AnalysisValidator.validate_analysis(
           parse_float(overall_score),
           transcription,
           context
         ) do
      {:warning, warning} -> warning
      {:ok, _} -> nil
    end
  end

  defp parse_bncc_matches(nil), do: []

  defp parse_bncc_matches(matches) when is_list(matches) do
    Enum.map(matches, fn
      match when is_binary(match) ->
        %{
          competencia_code: match,
          competencia_name: nil,
          score: 1.0,
          explanation: nil
        }

      match when is_map(match) ->
        %{
          competencia_code: match["code"] || match["competencia_code"],
          competencia_name: match["name"] || match["competencia_name"],
          score: parse_float(match["score"] || match["relevance"] || 0.0),
          explanation: match["explanation"] || match["description"]
        }
    end)
  end

  @valid_alert_types ~w(verbal_aggression exclusion intimidation mockery discrimination threat inappropriate_language other)

  defp parse_bullying_alerts(nil), do: []

  defp parse_bullying_alerts(alerts) when is_list(alerts) do
    Enum.map(alerts, fn
      alert when is_binary(alert) ->
        %{
          # Default severity for string alerts
          severity: "medium",
          # valid type
          alert_type: "other",
          description: alert,
          evidence_text: alert,
          timestamp_start: nil,
          timestamp_end: nil
        }

      alert when is_map(alert) ->
        raw_type = alert["type"] || alert["alert_type"] || "other"
        valid_type = if raw_type in @valid_alert_types, do: raw_type, else: "other"

        %{
          severity: alert["severity"] || "low",
          alert_type: valid_type,
          description: alert["description"],
          evidence_text: alert["evidence"] || alert["evidence_text"],
          timestamp_start: parse_float(alert["start"]),
          timestamp_end: parse_float(alert["end"])
        }
    end)
  end

  defp parse_float(nil), do: nil
  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value / 1.0

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> nil
    end
  end

  defp save_analysis(lesson, result) do
    Analysis.create_full_analysis(lesson.id, result)
  end

  defp handle_failure(lesson, reason) do
    Lessons.update_lesson_status(lesson, "failed")

    # Refund credit on failure (matching UI promise)
    user = Hellen.Accounts.get_user!(lesson.user_id)
    Hellen.Billing.refund_credit(user, lesson.id)

    broadcast_progress(lesson.id, "analysis_failed", %{error: inspect(reason)})
    {:error, reason}
  end

  defp broadcast_progress(lesson_id, event, payload) do
    Phoenix.PubSub.broadcast(
      Hellen.PubSub,
      "lesson:#{lesson_id}",
      {event, Map.put(payload, :lesson_id, lesson_id)}
    )
  end

  defp send_notifications(analysis) do
    # Preload required associations
    analysis = Hellen.Repo.preload(analysis, [:bullying_alerts, lesson: [:user, :institution]])

    # Notify about analysis completion
    Task.start(fn ->
      try do
        Notifications.notify_analysis_complete(analysis)
      rescue
        e -> Logger.warning("Failed to send analysis notification: #{inspect(e)}")
      end
    end)

    # Notify about each bullying alert
    Enum.each(analysis.bullying_alerts, fn alert ->
      Task.start(fn ->
        try do
          Notifications.notify_alert(alert)
        rescue
          e -> Logger.warning("Failed to send alert notification: #{inspect(e)}")
        end
      end)
    end)
  end
end
