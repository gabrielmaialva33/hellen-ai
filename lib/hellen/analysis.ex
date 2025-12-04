defmodule Hellen.Analysis do
  @moduledoc """
  The Analysis context - manages pedagogical analyses.
  """

  import Ecto.Query, warn: false

  alias Hellen.Analysis.{Analysis, BnccMatch, BullyingAlert}
  alias Hellen.Repo

  ## Analysis

  @doc """
  Gets an analysis by ID, scoped to institution.
  Raises if not found or institution doesn't match.
  """
  @spec get_analysis!(binary(), binary()) :: Analysis.t()
  def get_analysis!(id, institution_id) do
    Analysis
    |> where([a], a.id == ^id and a.institution_id == ^institution_id)
    |> Repo.one!()
  end

  @doc """
  Gets an analysis with details, scoped to institution.
  """
  @spec get_analysis_with_details!(binary(), binary()) :: Analysis.t()
  def get_analysis_with_details!(id, institution_id) do
    Analysis
    |> where([a], a.id == ^id and a.institution_id == ^institution_id)
    |> Repo.one!()
    |> Repo.preload([:bncc_matches, :bullying_alerts])
  end

  @doc """
  Lists analyses for a lesson, verifying institution ownership.
  """
  @spec list_analyses_by_lesson(binary(), binary()) :: [Analysis.t()]
  def list_analyses_by_lesson(lesson_id, institution_id) do
    Analysis
    |> where([a], a.lesson_id == ^lesson_id and a.institution_id == ^institution_id)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  def create_analysis(attrs \\ %{}) do
    %Analysis{}
    |> Analysis.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a full analysis with related BNCC matches and bullying alerts.
  Uses Ecto.Multi for transactional consistency.
  """
  @spec create_full_analysis(binary(), map()) :: {:ok, Analysis.t()} | {:error, term()}
  def create_full_analysis(lesson_id, analysis_result) do
    lesson = Repo.get!(Hellen.Lessons.Lesson, lesson_id)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:analysis, build_analysis_changeset(lesson, analysis_result))
    |> Ecto.Multi.run(:bncc_matches, fn _repo, %{analysis: analysis} ->
      insert_bncc_matches(analysis, analysis_result.bncc_matches || [])
    end)
    |> Ecto.Multi.run(:bullying_alerts, fn _repo, %{analysis: analysis} ->
      insert_bullying_alerts(analysis, analysis_result.bullying_alerts || [])
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{analysis: analysis}} -> {:ok, analysis}
      {:error, _failed_op, changeset, _changes} -> {:error, changeset}
    end
  end

  defp build_analysis_changeset(lesson, analysis_result) do
    %Analysis{}
    |> Analysis.changeset(%{
      lesson_id: lesson.id,
      institution_id: lesson.institution_id,
      analysis_type: "full",
      model_used: analysis_result.model,
      raw_response: analysis_result.raw,
      result: analysis_result.structured,
      overall_score: analysis_result.overall_score,
      processing_time_ms: analysis_result.processing_time_ms,
      tokens_used: analysis_result.tokens_used
    })
  end

  defp insert_bncc_matches(analysis, matches) do
    results =
      Enum.map(matches, fn match ->
        %BnccMatch{}
        |> BnccMatch.changeset(Map.put(match, :analysis_id, analysis.id))
        |> Repo.insert()
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(results, fn {:ok, m} -> m end)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp insert_bullying_alerts(analysis, alerts) do
    results =
      Enum.map(alerts, fn alert ->
        %BullyingAlert{}
        |> BullyingAlert.changeset(Map.put(alert, :analysis_id, analysis.id))
        |> Repo.insert()
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(results, fn {:ok, a} -> a end)}
      {:error, changeset} -> {:error, changeset}
    end
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
