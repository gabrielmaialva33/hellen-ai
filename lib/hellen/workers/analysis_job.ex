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
      grade_level: lesson.grade_level,
      planned_content: lesson.planned_content,
      planned_file_name: lesson.planned_file_name
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

    validation_result =
      validate_result(
        nvidia_result.structured,
        nvidia_result.transcription
      )

    # Use rigorous score if available from validation, otherwise default to LLM score
    final_score =
      if validation_result && validation_result["rigorous_score"] do
        validation_result["rigorous_score"]
      else
        parse_float(structured["overall_score"])
      end

    %{
      model: nvidia_result.model,
      # Wrap raw string in a map to match the :map field type in Analysis schema
      raw: %{"content" => nvidia_result.raw},
      structured: structured,
      overall_score: final_score,
      processing_time_ms: nvidia_result.processing_time_ms,
      tokens_used: nvidia_result.tokens_used,
      bncc_matches: parse_bncc_matches(structured["bncc_matches"]),
      bullying_alerts: parse_bullying_alerts(structured["bullying_alerts"]),
      lesson_characters: parse_lesson_characters(structured["lesson_characters"]),
      validation: validation_result
    }
  end

  defp validate_result(structured_result, transcription) do
    case AnalysisValidator.validate_analysis(
           transcription,
           structured_result
         ) do
      {:ok, updated_result} -> updated_result["validation_warning"]
      _ -> nil
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

  @valid_roles ~w(teacher student assistant guest other)
  @valid_sentiments ~w(positive neutral negative mixed)
  @valid_engagement_levels ~w(high medium low)

  defp parse_lesson_characters(nil), do: []

  defp parse_lesson_characters(characters) when is_list(characters) do
    Enum.map(characters, fn
      character when is_map(character) ->
        raw_role = character["role"] || "other"
        valid_role = if raw_role in @valid_roles, do: raw_role, else: "other"

        raw_sentiment = character["sentiment"]
        valid_sentiment = if raw_sentiment in @valid_sentiments, do: raw_sentiment, else: nil

        raw_engagement = character["engagement_level"] || character["engagement"]

        valid_engagement =
          if raw_engagement in @valid_engagement_levels, do: raw_engagement, else: nil

        %{
          identifier: character["identifier"] || character["name"] || "Participante",
          role: valid_role,
          speech_count: parse_integer(character["speech_count"]),
          word_count: parse_integer(character["word_count"]),
          characteristics: parse_string_list(character["characteristics"]),
          speech_patterns: character["speech_patterns"],
          key_quotes: parse_string_list(character["key_quotes"]),
          sentiment: valid_sentiment,
          engagement_level: valid_engagement
        }

      character when is_binary(character) ->
        %{
          identifier: character,
          role: "other",
          speech_count: nil,
          word_count: nil,
          characteristics: [],
          speech_patterns: nil,
          key_quotes: [],
          sentiment: nil,
          engagement_level: nil
        }
    end)
  end

  defp parse_string_list(nil), do: []
  defp parse_string_list(list) when is_list(list), do: Enum.filter(list, &is_binary/1)
  defp parse_string_list(_), do: []

  defp parse_integer(nil), do: nil
  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(value) when is_float(value), do: round(value)

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_float(nil), do: nil
  defp parse_float(value) when is_float(value), do: normalize_score(value)
  defp parse_float(value) when is_integer(value), do: normalize_score(value / 1.0)

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> normalize_score(float)
      :error -> nil
    end
  end

  # Normalize score to 0-1 range (AI sometimes returns 0-100 instead of 0-1)
  defp normalize_score(score) when score > 1.0, do: score / 100.0
  defp normalize_score(score), do: score

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
