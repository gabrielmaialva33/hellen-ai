defmodule Hellen.Cache.Keys do
  @moduledoc """
  Key generation and namespacing for the cache system.

  All cache keys are prefixed with `hellen:` to avoid conflicts with
  other applications sharing the same Redis instance.

  ## Key Structure

  Keys follow a hierarchical pattern:

      hellen:{domain}:{entity}:{id}[:{sub}]

  Examples:
  - `hellen:analysis:123` - Analysis by ID
  - `hellen:user:456:stats` - User stats
  - `hellen:lesson:789:transcription` - Lesson transcription
  - `hellen:bncc:coverage:user:456` - BNCC coverage for user

  ## Naming Conventions

  - Use snake_case for all key components
  - Use colons (`:`) as separators
  - Keep keys descriptive but concise
  - Include version suffix for breaking changes: `hellen:v2:analysis:123`
  """

  @prefix "hellen"

  @doc """
  Add the global prefix to a key.
  """
  @spec prefix(String.t()) :: String.t()
  def prefix(key), do: "#{@prefix}:#{key}"

  @doc """
  Remove the global prefix from a key.
  """
  @spec unprefix(String.t()) :: String.t()
  def unprefix(key) do
    case String.split(key, "#{@prefix}:", parts: 2) do
      [_, rest] -> rest
      [key] -> key
    end
  end

  # ============================================================================
  # Analysis Keys
  # ============================================================================

  @doc "Key for a specific analysis by ID"
  @spec analysis(binary()) :: String.t()
  def analysis(id), do: "analysis:#{id}"

  @doc "Key for analysis by lesson ID"
  @spec analysis_by_lesson(binary()) :: String.t()
  def analysis_by_lesson(lesson_id), do: "analysis:lesson:#{lesson_id}"

  @doc "Key for analyses list by user"
  @spec analyses_by_user(binary()) :: String.t()
  def analyses_by_user(user_id), do: "analyses:user:#{user_id}"

  @doc "Key for user's score history"
  @spec score_history(binary()) :: String.t()
  def score_history(user_id), do: "score_history:user:#{user_id}"

  @doc "Key for user's trend data"
  @spec user_trend(binary()) :: String.t()
  def user_trend(user_id), do: "trend:user:#{user_id}"

  @doc "Key for BNCC coverage by user"
  @spec bncc_coverage(binary()) :: String.t()
  def bncc_coverage(user_id), do: "bncc:coverage:user:#{user_id}"

  @doc "Key for discipline average score"
  @spec discipline_avg(String.t(), binary()) :: String.t()
  def discipline_avg(subject, institution_id), do: "discipline:avg:#{subject}:#{institution_id}"

  # ============================================================================
  # Lesson Keys
  # ============================================================================

  @doc "Key for a specific lesson by ID"
  @spec lesson(binary()) :: String.t()
  def lesson(id), do: "lesson:#{id}"

  @doc "Key for lessons list by user"
  @spec lessons_by_user(binary()) :: String.t()
  def lessons_by_user(user_id), do: "lessons:user:#{user_id}"

  @doc "Key for lesson transcription"
  @spec transcription(binary()) :: String.t()
  def transcription(lesson_id), do: "transcription:lesson:#{lesson_id}"

  @doc "Key for subjects list by institution"
  @spec subjects(binary()) :: String.t()
  def subjects(institution_id), do: "subjects:institution:#{institution_id}"

  # ============================================================================
  # User Keys
  # ============================================================================

  @doc "Key for user by ID"
  @spec user(binary()) :: String.t()
  def user(id), do: "user:#{id}"

  @doc "Key for user by email"
  @spec user_by_email(String.t()) :: String.t()
  def user_by_email(email), do: "user:email:#{email}"

  @doc "Key for user stats"
  @spec user_stats(binary()) :: String.t()
  def user_stats(user_id), do: "user:#{user_id}:stats"

  @doc "Key for user credits"
  @spec user_credits(binary()) :: String.t()
  def user_credits(user_id), do: "user:#{user_id}:credits"

  @doc "Key for user preferences"
  @spec user_preferences(binary()) :: String.t()
  def user_preferences(user_id), do: "user:#{user_id}:preferences"

  @doc "Key for user achievements"
  @spec user_achievements(binary()) :: String.t()
  def user_achievements(user_id), do: "achievements:user:#{user_id}"

  # ============================================================================
  # Institution Keys
  # ============================================================================

  @doc "Key for institution by ID"
  @spec institution(binary()) :: String.t()
  def institution(id), do: "institution:#{id}"

  @doc "Key for institution stats"
  @spec institution_stats(binary()) :: String.t()
  def institution_stats(institution_id), do: "institution:#{institution_id}:stats"

  @doc "Key for institution users list"
  @spec institution_users(binary()) :: String.t()
  def institution_users(institution_id), do: "institution:#{institution_id}:users"

  # ============================================================================
  # Dashboard/Stats Keys
  # ============================================================================

  @doc "Key for dashboard stats"
  @spec dashboard_stats(binary()) :: String.t()
  def dashboard_stats(user_id), do: "dashboard:stats:#{user_id}"

  @doc "Key for global platform stats"
  @spec platform_stats() :: String.t()
  def platform_stats, do: "platform:stats"

  @doc "Key for coordinator dashboard stats"
  @spec coordinator_stats(binary()) :: String.t()
  def coordinator_stats(institution_id), do: "coordinator:stats:#{institution_id}"

  # ============================================================================
  # Billing Keys
  # ============================================================================

  @doc "Key for billing transactions by user"
  @spec billing_transactions(binary()) :: String.t()
  def billing_transactions(user_id), do: "billing:transactions:user:#{user_id}"

  @doc "Key for billing usage by user"
  @spec billing_usage(binary()) :: String.t()
  def billing_usage(user_id), do: "billing:usage:user:#{user_id}"

  # ============================================================================
  # Planning & Assessment Keys
  # ============================================================================

  @doc "Key for planning by ID"
  @spec planning(binary()) :: String.t()
  def planning(id), do: "planning:#{id}"

  @doc "Key for plannings by user"
  @spec plannings_by_user(binary()) :: String.t()
  def plannings_by_user(user_id), do: "plannings:user:#{user_id}"

  @doc "Key for assessment by ID"
  @spec assessment(binary()) :: String.t()
  def assessment(id), do: "assessment:#{id}"

  @doc "Key for assessments by user"
  @spec assessments_by_user(binary()) :: String.t()
  def assessments_by_user(user_id), do: "assessments:user:#{user_id}"

  # ============================================================================
  # Rate Limiting Keys
  # ============================================================================

  @doc "Key for API rate limit counter"
  @spec rate_limit(String.t(), String.t()) :: String.t()
  def rate_limit(scope, identifier), do: "ratelimit:#{scope}:#{identifier}"

  @doc "Key for login attempts"
  @spec login_attempts(String.t()) :: String.t()
  def login_attempts(identifier), do: "login_attempts:#{identifier}"

  # ============================================================================
  # Session/Token Keys
  # ============================================================================

  @doc "Key for refresh token"
  @spec refresh_token(binary()) :: String.t()
  def refresh_token(user_id), do: "refresh_token:user:#{user_id}"

  @doc "Key for session"
  @spec session(String.t()) :: String.t()
  def session(session_id), do: "session:#{session_id}"

  # ============================================================================
  # Lock Keys (for distributed locking)
  # ============================================================================

  @doc "Key for a distributed lock"
  @spec lock(String.t()) :: String.t()
  def lock(resource), do: "lock:#{resource}"

  @doc "Key for job processing lock"
  @spec job_lock(String.t(), binary()) :: String.t()
  def job_lock(job_type, id), do: "lock:job:#{job_type}:#{id}"

  # ============================================================================
  # Pattern Helpers (for bulk operations)
  # ============================================================================

  @doc "Pattern for all user-related keys"
  @spec user_pattern(binary()) :: String.t()
  def user_pattern(user_id), do: "*user:#{user_id}*"

  @doc "Pattern for all lesson-related keys"
  @spec lesson_pattern(binary()) :: String.t()
  def lesson_pattern(lesson_id), do: "*lesson:#{lesson_id}*"

  @doc "Pattern for all institution-related keys"
  @spec institution_pattern(binary()) :: String.t()
  def institution_pattern(institution_id), do: "*institution:#{institution_id}*"
end
