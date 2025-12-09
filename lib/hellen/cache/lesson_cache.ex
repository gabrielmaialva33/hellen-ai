defmodule Hellen.Cache.LessonCache do
  @moduledoc """
  Cache operations for Lessons domain.

  Caches lessons, transcriptions, and related data.

  ## TTL Strategy

  - Individual lesson: 30 minutes (status may change during processing)
  - User's lessons list: 5 minutes (frequently updated)
  - Transcription: 1 hour (immutable after creation)
  - Subjects list: 1 hour (rarely changes)
  """

  alias Hellen.Cache
  alias Hellen.Cache.Keys

  # TTLs
  @lesson_ttl :timer.minutes(30)
  @lessons_list_ttl :timer.minutes(5)
  @transcription_ttl :timer.hours(1)
  @subjects_ttl :timer.hours(1)

  # ============================================================================
  # Lesson by ID
  # ============================================================================

  @doc """
  Get a lesson from cache or compute it.
  """
  @spec get_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_or_cache(lesson_id, compute_fn) do
    Cache.fetch(Keys.lesson(lesson_id), compute_fn, ttl: @lesson_ttl)
  end

  @doc """
  Get cached lesson (returns nil if not cached).
  """
  @spec get(binary()) :: any()
  def get(lesson_id) do
    Cache.get!(Keys.lesson(lesson_id))
  end

  @doc """
  Cache a lesson.
  """
  @spec put(binary(), any()) :: {:ok, any()} | {:error, any()}
  def put(lesson_id, lesson) do
    Cache.set(Keys.lesson(lesson_id), lesson, ttl: @lesson_ttl)
  end

  @doc """
  Invalidate cached lesson.
  """
  @spec invalidate(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate(lesson_id) do
    Cache.delete(Keys.lesson(lesson_id))
  end

  # ============================================================================
  # User's Lessons List
  # ============================================================================

  @doc """
  Get user's lessons list from cache or compute.
  """
  @spec get_user_lessons_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_user_lessons_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.lessons_by_user(user_id), compute_fn, ttl: @lessons_list_ttl)
  end

  @doc """
  Invalidate user's lessons list cache.
  """
  @spec invalidate_user_lessons(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_user_lessons(user_id) do
    Cache.delete(Keys.lessons_by_user(user_id))
  end

  # ============================================================================
  # Transcription
  # ============================================================================

  @doc """
  Get transcription from cache or compute.
  """
  @spec get_transcription_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_transcription_or_cache(lesson_id, compute_fn) do
    Cache.fetch(Keys.transcription(lesson_id), compute_fn, ttl: @transcription_ttl)
  end

  @doc """
  Cache a transcription.
  """
  @spec put_transcription(binary(), any()) :: {:ok, any()} | {:error, any()}
  def put_transcription(lesson_id, transcription) do
    Cache.set(Keys.transcription(lesson_id), transcription, ttl: @transcription_ttl)
  end

  @doc """
  Invalidate transcription cache.
  """
  @spec invalidate_transcription(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_transcription(lesson_id) do
    Cache.delete(Keys.transcription(lesson_id))
  end

  # ============================================================================
  # Subjects List
  # ============================================================================

  @doc """
  Get subjects list from cache or compute.
  """
  @spec get_subjects_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_subjects_or_cache(institution_id, compute_fn) do
    Cache.fetch(Keys.subjects(institution_id), compute_fn, ttl: @subjects_ttl)
  end

  @doc """
  Invalidate subjects cache.
  """
  @spec invalidate_subjects(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_subjects(institution_id) do
    Cache.delete(Keys.subjects(institution_id))
  end

  # ============================================================================
  # Bulk Invalidation
  # ============================================================================

  @doc """
  Invalidate all lesson-related caches.
  Call this after lesson status changes.
  """
  @spec invalidate_all(binary(), binary()) :: :ok
  def invalidate_all(lesson_id, user_id) do
    invalidate(lesson_id)
    invalidate_user_lessons(user_id)
    :ok
  end

  @doc """
  Invalidate caches after lesson is created.
  """
  @spec on_lesson_created(binary(), binary(), binary() | nil) :: :ok
  def on_lesson_created(lesson_id, user_id, institution_id) do
    invalidate(lesson_id)
    invalidate_user_lessons(user_id)

    if institution_id do
      invalidate_subjects(institution_id)
    end

    :ok
  end

  @doc """
  Invalidate caches after lesson status changes.
  """
  @spec on_lesson_updated(binary(), binary()) :: :ok
  def on_lesson_updated(lesson_id, user_id) do
    invalidate(lesson_id)
    invalidate_user_lessons(user_id)
    :ok
  end

  @doc """
  Invalidate caches after transcription is created.
  """
  @spec on_transcription_created(binary(), binary()) :: :ok
  def on_transcription_created(lesson_id, user_id) do
    invalidate(lesson_id)
    invalidate_transcription(lesson_id)
    invalidate_user_lessons(user_id)
    :ok
  end
end
