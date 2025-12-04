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

  ## Statistics & History

  @doc """
  Get score history for a user's lessons over time.
  Returns a list of %{date: Date.t(), score: float, lesson_title: String.t()}
  """
  def get_user_score_history(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    Analysis
    |> join(:inner, [a], l in assoc(a, :lesson))
    |> where([a, l], l.user_id == ^user_id)
    |> where([a], not is_nil(a.overall_score))
    |> order_by([a], asc: a.inserted_at)
    |> limit(^limit)
    |> select([a, l], %{
      date: a.inserted_at,
      score: a.overall_score,
      lesson_title: l.title,
      lesson_id: l.id
    })
    |> Repo.all()
  end

  @doc """
  Get the average score for a discipline within an institution.
  """
  def get_discipline_average(subject, institution_id) when is_binary(subject) do
    Analysis
    |> join(:inner, [a], l in assoc(a, :lesson))
    |> where([a, l], l.institution_id == ^institution_id)
    |> where([a, l], l.subject == ^subject)
    |> where([a], not is_nil(a.overall_score))
    |> select([a], avg(a.overall_score))
    |> Repo.one()
  end

  def get_discipline_average(_subject, _institution_id), do: nil

  @doc """
  Calculate user's score trend based on recent analyses.
  Returns :improving, :stable, or :declining with the change percentage.
  """
  def get_user_trend(user_id) do
    history = get_user_score_history(user_id, limit: 10)

    case history do
      [] ->
        {:stable, 0.0}

      [_single] ->
        {:stable, 0.0}

      scores ->
        mid = div(length(scores), 2)
        {older, recent} = Enum.split(scores, mid)

        older_avg = Enum.map(older, & &1.score) |> average()
        recent_avg = Enum.map(recent, & &1.score) |> average()

        change = (recent_avg - older_avg) * 100

        cond do
          change > 5 -> {:improving, change}
          change < -5 -> {:declining, change}
          true -> {:stable, change}
        end
    end
  end

  defp average([]), do: 0.0
  defp average(list), do: Enum.sum(list) / length(list)

  @doc """
  Get BNCC competencies coverage for a user.
  Returns aggregated competencies with frequency and average score.
  """
  def get_bncc_coverage(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    BnccMatch
    |> join(:inner, [m], a in assoc(m, :analysis))
    |> join(:inner, [m, a], l in assoc(a, :lesson))
    |> where([m, a, l], l.user_id == ^user_id)
    |> group_by([m], [m.competencia_code, m.competencia_name])
    |> select([m], %{
      code: m.competencia_code,
      name: m.competencia_name,
      count: count(m.id),
      avg_score: avg(m.match_score)
    })
    |> order_by([m], desc: count(m.id))
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  List all alerts for an institution with pagination.
  """
  def list_alerts_by_institution(institution_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    status = Keyword.get(opts, :status, :all)

    query =
      BullyingAlert
      |> join(:inner, [b], a in assoc(b, :analysis))
      |> where([b, a], a.institution_id == ^institution_id)
      |> order_by([b], desc: b.inserted_at)
      |> limit(^limit)
      |> preload([b, a], analysis: {a, :lesson})

    query =
      case status do
        :unreviewed -> where(query, [b], b.reviewed == false)
        :reviewed -> where(query, [b], b.reviewed == true)
        _ -> query
      end

    Repo.all(query)
  end

  @doc """
  Get alert statistics for an institution.
  """
  def get_alert_stats(institution_id) do
    query =
      BullyingAlert
      |> join(:inner, [b], a in assoc(b, :analysis))
      |> where([b, a], a.institution_id == ^institution_id)

    total = Repo.aggregate(query, :count)
    unreviewed = query |> where([b], b.reviewed == false) |> Repo.aggregate(:count)

    by_severity =
      query
      |> group_by([b], b.severity)
      |> select([b], {b.severity, count(b.id)})
      |> Repo.all()
      |> Map.new()

    by_type =
      query
      |> group_by([b], b.alert_type)
      |> select([b], {b.alert_type, count(b.id)})
      |> Repo.all()
      |> Map.new()

    %{
      total: total,
      unreviewed: unreviewed,
      reviewed: total - unreviewed,
      by_severity: by_severity,
      by_type: by_type
    }
  end
end
