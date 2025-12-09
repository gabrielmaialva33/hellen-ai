defmodule Hellen.Cache.AnalysisCache do
  @moduledoc """
  Cache operations for Analysis domain.

  Caches analysis results, score histories, BNCC coverage, and trends.

  ## TTL Strategy

  - Individual analysis: 1 hour (rarely changes after creation)
  - Score history: 15 minutes (updated on new analysis)
  - User trend: 15 minutes (computed from recent scores)
  - BNCC coverage: 30 minutes (aggregated data)
  - Discipline averages: 1 hour (institution-wide, slow to change)
  """

  alias Hellen.Cache
  alias Hellen.Cache.Keys

  # TTLs
  @analysis_ttl :timer.hours(1)
  @history_ttl :timer.minutes(15)
  @trend_ttl :timer.minutes(15)
  @bncc_ttl :timer.minutes(30)
  @discipline_ttl :timer.hours(1)

  # ============================================================================
  # Analysis by ID
  # ============================================================================

  @doc """
  Get an analysis from cache or compute it.
  """
  @spec get_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_or_cache(analysis_id, compute_fn) do
    Cache.fetch(Keys.analysis(analysis_id), compute_fn, ttl: @analysis_ttl)
  end

  @doc """
  Get cached analysis (returns nil if not cached).
  """
  @spec get(binary()) :: any()
  def get(analysis_id) do
    Cache.get!(Keys.analysis(analysis_id))
  end

  @doc """
  Cache an analysis.
  """
  @spec put(binary(), any()) :: {:ok, any()} | {:error, any()}
  def put(analysis_id, analysis) do
    Cache.set(Keys.analysis(analysis_id), analysis, ttl: @analysis_ttl)
  end

  @doc """
  Invalidate cached analysis.
  """
  @spec invalidate(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate(analysis_id) do
    Cache.delete(Keys.analysis(analysis_id))
  end

  # ============================================================================
  # Analysis by Lesson
  # ============================================================================

  @doc """
  Get analyses for a lesson from cache or compute.
  """
  @spec get_by_lesson_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_by_lesson_or_cache(lesson_id, compute_fn) do
    Cache.fetch(Keys.analysis_by_lesson(lesson_id), compute_fn, ttl: @analysis_ttl)
  end

  @doc """
  Invalidate analyses cache for a lesson.
  """
  @spec invalidate_by_lesson(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_by_lesson(lesson_id) do
    Cache.delete(Keys.analysis_by_lesson(lesson_id))
  end

  # ============================================================================
  # Analyses by User
  # ============================================================================

  @doc """
  Get user's analyses list from cache or compute.
  """
  @spec get_user_analyses_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_user_analyses_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.analyses_by_user(user_id), compute_fn, ttl: @history_ttl)
  end

  @doc """
  Invalidate user's analyses cache.
  """
  @spec invalidate_user_analyses(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_user_analyses(user_id) do
    Cache.delete(Keys.analyses_by_user(user_id))
  end

  # ============================================================================
  # Score History
  # ============================================================================

  @doc """
  Get user's score history from cache or compute.
  """
  @spec get_score_history_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_score_history_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.score_history(user_id), compute_fn, ttl: @history_ttl)
  end

  @doc """
  Invalidate score history cache.
  """
  @spec invalidate_score_history(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_score_history(user_id) do
    Cache.delete(Keys.score_history(user_id))
  end

  # ============================================================================
  # User Trend
  # ============================================================================

  @doc """
  Get user's trend data from cache or compute.
  """
  @spec get_trend_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_trend_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.user_trend(user_id), compute_fn, ttl: @trend_ttl)
  end

  @doc """
  Invalidate trend cache.
  """
  @spec invalidate_trend(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_trend(user_id) do
    Cache.delete(Keys.user_trend(user_id))
  end

  # ============================================================================
  # BNCC Coverage
  # ============================================================================

  @doc """
  Get BNCC coverage from cache or compute.
  """
  @spec get_bncc_coverage_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_bncc_coverage_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.bncc_coverage(user_id), compute_fn, ttl: @bncc_ttl)
  end

  @doc """
  Invalidate BNCC coverage cache.
  """
  @spec invalidate_bncc_coverage(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_bncc_coverage(user_id) do
    Cache.delete(Keys.bncc_coverage(user_id))
  end

  # ============================================================================
  # Discipline Average
  # ============================================================================

  @doc """
  Get discipline average from cache or compute.
  """
  @spec get_discipline_avg_or_cache(String.t(), binary(), (-> any())) ::
          {:ok, any()} | {:error, any()}
  def get_discipline_avg_or_cache(subject, institution_id, compute_fn) do
    Cache.fetch(Keys.discipline_avg(subject, institution_id), compute_fn, ttl: @discipline_ttl)
  end

  @doc """
  Invalidate discipline average cache.
  """
  @spec invalidate_discipline_avg(String.t(), binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_discipline_avg(subject, institution_id) do
    Cache.delete(Keys.discipline_avg(subject, institution_id))
  end

  # ============================================================================
  # Bulk Invalidation
  # ============================================================================

  @doc """
  Invalidate all analysis-related caches for a user.
  Call this after a new analysis is created.
  """
  @spec invalidate_user_caches(binary()) :: :ok
  def invalidate_user_caches(user_id) do
    invalidate_user_analyses(user_id)
    invalidate_score_history(user_id)
    invalidate_trend(user_id)
    invalidate_bncc_coverage(user_id)
    :ok
  end

  @doc """
  Invalidate all caches after a new analysis is created.
  """
  @spec on_analysis_created(binary(), binary(), String.t() | nil, binary() | nil) :: :ok
  def on_analysis_created(analysis_id, user_id, subject, institution_id) do
    invalidate(analysis_id)
    invalidate_user_caches(user_id)

    if subject && institution_id do
      invalidate_discipline_avg(subject, institution_id)
    end

    :ok
  end
end
