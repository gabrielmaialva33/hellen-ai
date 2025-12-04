defmodule Hellen.Analysis do
  @moduledoc """
  The Analysis context - manages pedagogical analyses.
  """

  import Ecto.Query, warn: false

  alias Hellen.Analysis.{Analysis, BnccMatch, BullyingAlert}
  alias Hellen.Repo

  ## Analysis

  def get_analysis!(id), do: Repo.get!(Analysis, id)

  def get_analysis_with_details!(id) do
    Analysis
    |> Repo.get!(id)
    |> Repo.preload([:bncc_matches, :bullying_alerts])
  end

  def list_analyses_by_lesson(lesson_id) do
    Analysis
    |> where([a], a.lesson_id == ^lesson_id)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  def create_analysis(attrs \\ %{}) do
    %Analysis{}
    |> Analysis.changeset(attrs)
    |> Repo.insert()
  end

  def create_full_analysis(lesson_id, analysis_result) do
    Repo.transaction(fn ->
      analysis_result
      |> build_analysis_attrs(lesson_id)
      |> create_analysis()
      |> case do
        {:ok, analysis} -> create_related_records(analysis, analysis_result)
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp build_analysis_attrs(analysis_result, lesson_id) do
    # Get institution_id from lesson
    lesson = Hellen.Repo.get!(Hellen.Lessons.Lesson, lesson_id)

    %{
      lesson_id: lesson_id,
      institution_id: lesson.institution_id,
      analysis_type: "full",
      model_used: analysis_result.model,
      raw_response: analysis_result.raw,
      result: analysis_result.structured,
      overall_score: analysis_result.overall_score,
      processing_time_ms: analysis_result.processing_time_ms,
      tokens_used: analysis_result.tokens_used
    }
  end

  defp create_related_records(analysis, analysis_result) do
    Enum.each(analysis_result.bncc_matches || [], fn match ->
      create_bncc_match(Map.put(match, :analysis_id, analysis.id))
    end)

    Enum.each(analysis_result.bullying_alerts || [], fn alert ->
      create_bullying_alert(Map.put(alert, :analysis_id, analysis.id))
    end)

    analysis
  end

  def create_feedback_analysis(lesson_id, analysis_result) do
    create_analysis(%{
      lesson_id: lesson_id,
      analysis_type: "pedagogical_feedback",
      model_used: analysis_result.model,
      raw_response: analysis_result.raw,
      result: analysis_result.structured,
      processing_time_ms: analysis_result.processing_time_ms,
      tokens_used: analysis_result.tokens_used
    })
  end

  ## BNCC Matches

  def create_bncc_match(attrs) do
    %BnccMatch{}
    |> BnccMatch.changeset(attrs)
    |> Repo.insert()
  end

  def list_bncc_matches_by_analysis(analysis_id) do
    BnccMatch
    |> where([m], m.analysis_id == ^analysis_id)
    |> order_by([m], desc: m.match_score)
    |> Repo.all()
  end

  ## Bullying Alerts

  def create_bullying_alert(attrs) do
    %BullyingAlert{}
    |> BullyingAlert.changeset(attrs)
    |> Repo.insert()
  end

  def list_bullying_alerts_by_analysis(analysis_id) do
    BullyingAlert
    |> where([a], a.analysis_id == ^analysis_id)
    |> order_by([a], desc: a.severity)
    |> Repo.all()
  end

  def review_bullying_alert(alert_id, reviewer_id) do
    BullyingAlert
    |> Repo.get!(alert_id)
    |> BullyingAlert.review_changeset(reviewer_id)
    |> Repo.update()
  end

  def list_unreviewed_alerts(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    BullyingAlert
    |> where([a], a.reviewed == false)
    |> order_by([a], desc: a.severity, desc: a.inserted_at)
    |> limit(^limit)
    |> preload(analysis: :lesson)
    |> Repo.all()
  end
end
