defmodule Hellen.Cache.UserCache do
  @moduledoc """
  Cache operations for User domain.

  Caches user data, stats, credits, preferences, and achievements.

  ## TTL Strategy

  - User by ID/email: 30 minutes (profile changes are rare)
  - User stats: 5 minutes (dashboard stats)
  - User credits: 1 minute (frequently checked, needs accuracy)
  - User preferences: 1 hour (rarely changes)
  - User achievements: 15 minutes (updated on events)
  """

  alias Hellen.Cache
  alias Hellen.Cache.Keys

  # TTLs
  @user_ttl :timer.minutes(30)
  @stats_ttl :timer.minutes(5)
  @credits_ttl :timer.minutes(1)
  @preferences_ttl :timer.hours(1)
  @achievements_ttl :timer.minutes(15)

  # ============================================================================
  # User by ID
  # ============================================================================

  @doc """
  Get a user from cache or compute it.
  """
  @spec get_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.user(user_id), compute_fn, ttl: @user_ttl)
  end

  @doc """
  Get cached user (returns nil if not cached).
  """
  @spec get(binary()) :: any()
  def get(user_id) do
    Cache.get!(Keys.user(user_id))
  end

  @doc """
  Cache a user.
  """
  @spec put(binary(), any()) :: {:ok, any()} | {:error, any()}
  def put(user_id, user) do
    Cache.set(Keys.user(user_id), user, ttl: @user_ttl)
  end

  @doc """
  Invalidate cached user.
  """
  @spec invalidate(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate(user_id) do
    Cache.delete(Keys.user(user_id))
  end

  # ============================================================================
  # User by Email
  # ============================================================================

  @doc """
  Get user by email from cache or compute.
  """
  @spec get_by_email_or_cache(String.t(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_by_email_or_cache(email, compute_fn) do
    Cache.fetch(Keys.user_by_email(email), compute_fn, ttl: @user_ttl)
  end

  @doc """
  Invalidate user by email cache.
  """
  @spec invalidate_by_email(String.t()) :: {:ok, integer()} | {:error, any()}
  def invalidate_by_email(email) do
    Cache.delete(Keys.user_by_email(email))
  end

  # ============================================================================
  # User Stats
  # ============================================================================

  @doc """
  Get user stats from cache or compute.
  """
  @spec get_stats_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_stats_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.user_stats(user_id), compute_fn, ttl: @stats_ttl)
  end

  @doc """
  Cache user stats.
  """
  @spec put_stats(binary(), any()) :: {:ok, any()} | {:error, any()}
  def put_stats(user_id, stats) do
    Cache.set(Keys.user_stats(user_id), stats, ttl: @stats_ttl)
  end

  @doc """
  Invalidate user stats cache.
  """
  @spec invalidate_stats(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_stats(user_id) do
    Cache.delete(Keys.user_stats(user_id))
  end

  # ============================================================================
  # User Credits
  # ============================================================================

  @doc """
  Get user credits from cache or compute.
  Uses short TTL for accuracy.
  """
  @spec get_credits_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_credits_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.user_credits(user_id), compute_fn, ttl: @credits_ttl)
  end

  @doc """
  Cache user credits.
  """
  @spec put_credits(binary(), integer()) :: {:ok, any()} | {:error, any()}
  def put_credits(user_id, credits) do
    Cache.set(Keys.user_credits(user_id), credits, ttl: @credits_ttl)
  end

  @doc """
  Invalidate user credits cache.
  Call this after any credit transaction.
  """
  @spec invalidate_credits(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_credits(user_id) do
    Cache.delete(Keys.user_credits(user_id))
  end

  # ============================================================================
  # User Preferences
  # ============================================================================

  @doc """
  Get user preferences from cache or compute.
  """
  @spec get_preferences_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_preferences_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.user_preferences(user_id), compute_fn, ttl: @preferences_ttl)
  end

  @doc """
  Cache user preferences.
  """
  @spec put_preferences(binary(), any()) :: {:ok, any()} | {:error, any()}
  def put_preferences(user_id, preferences) do
    Cache.set(Keys.user_preferences(user_id), preferences, ttl: @preferences_ttl)
  end

  @doc """
  Invalidate user preferences cache.
  """
  @spec invalidate_preferences(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_preferences(user_id) do
    Cache.delete(Keys.user_preferences(user_id))
  end

  # ============================================================================
  # User Achievements
  # ============================================================================

  @doc """
  Get user achievements from cache or compute.
  """
  @spec get_achievements_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_achievements_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.user_achievements(user_id), compute_fn, ttl: @achievements_ttl)
  end

  @doc """
  Invalidate user achievements cache.
  """
  @spec invalidate_achievements(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_achievements(user_id) do
    Cache.delete(Keys.user_achievements(user_id))
  end

  # ============================================================================
  # Dashboard Stats
  # ============================================================================

  @doc """
  Get dashboard stats from cache or compute.
  """
  @spec get_dashboard_stats_or_cache(binary(), (-> any())) :: {:ok, any()} | {:error, any()}
  def get_dashboard_stats_or_cache(user_id, compute_fn) do
    Cache.fetch(Keys.dashboard_stats(user_id), compute_fn, ttl: @stats_ttl)
  end

  @doc """
  Invalidate dashboard stats cache.
  """
  @spec invalidate_dashboard_stats(binary()) :: {:ok, integer()} | {:error, any()}
  def invalidate_dashboard_stats(user_id) do
    Cache.delete(Keys.dashboard_stats(user_id))
  end

  # ============================================================================
  # Bulk Invalidation
  # ============================================================================

  @doc """
  Invalidate all user-related caches.
  """
  @spec invalidate_all(binary(), String.t() | nil) :: :ok
  def invalidate_all(user_id, email \\ nil) do
    invalidate(user_id)
    invalidate_stats(user_id)
    invalidate_credits(user_id)
    invalidate_preferences(user_id)
    invalidate_achievements(user_id)
    invalidate_dashboard_stats(user_id)

    if email do
      invalidate_by_email(email)
    end

    :ok
  end

  @doc """
  Invalidate caches after user profile update.
  """
  @spec on_user_updated(binary(), String.t() | nil) :: :ok
  def on_user_updated(user_id, email \\ nil) do
    invalidate(user_id)

    if email do
      invalidate_by_email(email)
    end

    :ok
  end

  @doc """
  Invalidate caches after credit transaction.
  """
  @spec on_credit_changed(binary()) :: :ok
  def on_credit_changed(user_id) do
    invalidate_credits(user_id)
    invalidate_stats(user_id)
    invalidate_dashboard_stats(user_id)
    :ok
  end

  @doc """
  Invalidate caches after new achievement.
  """
  @spec on_achievement_unlocked(binary()) :: :ok
  def on_achievement_unlocked(user_id) do
    invalidate_achievements(user_id)
    :ok
  end
end
