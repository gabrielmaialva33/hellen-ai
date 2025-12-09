defmodule Hellen.Cache.RateLimiter do
  @moduledoc """
  Rate limiting using Redis with sliding window algorithm.

  ## Usage

      # Check if action is allowed
      case RateLimiter.check("api", user_id, limit: 100, window: :timer.minutes(1)) do
        {:allow, remaining} ->
          # Proceed with action
          {:ok, remaining}

        {:deny, retry_after} ->
          # Rate limited
          {:error, {:rate_limited, retry_after}}
      end

      # Login attempt limiting
      case RateLimiter.check_login(ip_address) do
        {:allow, _} -> authenticate(credentials)
        {:deny, _} -> {:error, :too_many_attempts}
      end

  ## Algorithms

  - **Fixed Window**: Simple counter per time window (default)
  - **Sliding Window**: More accurate, prevents burst at window boundaries
  """

  alias Hellen.Cache
  alias Hellen.Cache.Keys

  @redis_name :redix

  # Default limits
  @default_limit 100
  @default_window :timer.minutes(1)

  # Login limits
  @login_limit 5
  @login_window :timer.minutes(15)
  @login_lockout :timer.minutes(30)

  # API limits
  @api_limit 1000
  @api_window :timer.hours(1)

  @doc """
  Check if an action is allowed under the rate limit.

  Returns `{:allow, remaining}` if allowed, or `{:deny, retry_after_ms}` if rate limited.

  ## Options

  - `:limit` - Maximum requests per window (default: 100)
  - `:window` - Time window in milliseconds (default: 1 minute)
  - `:algorithm` - `:fixed` or `:sliding` (default: :fixed)
  """
  @spec check(String.t(), String.t(), keyword()) :: {:allow, integer()} | {:deny, integer()}
  def check(scope, identifier, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    window = Keyword.get(opts, :window, @default_window)
    algorithm = Keyword.get(opts, :algorithm, :fixed)

    key = Keys.rate_limit(scope, identifier)

    case algorithm do
      :sliding -> sliding_window_check(key, limit, window)
      _ -> fixed_window_check(key, limit, window)
    end
  end

  @doc """
  Check login attempts for an identifier (email, IP, etc).
  Uses stricter limits and longer lockout.
  """
  @spec check_login(String.t()) :: {:allow, integer()} | {:deny, integer()}
  def check_login(identifier) do
    key = Keys.login_attempts(identifier)

    case get_counter(key) do
      {:ok, count} when count >= @login_limit ->
        # Check if in lockout period
        case Cache.ttl(key) do
          {:ok, ttl} when ttl > 0 -> {:deny, ttl}
          _ -> {:deny, @login_lockout}
        end

      {:ok, count} ->
        # Increment counter
        increment_with_expiry(key, @login_window)
        {:allow, @login_limit - count - 1}

      {:error, _} ->
        # Allow on error, but log
        {:allow, @login_limit}
    end
  end

  @doc """
  Reset login attempts for an identifier (after successful login).
  """
  @spec reset_login_attempts(String.t()) :: :ok
  def reset_login_attempts(identifier) do
    key = Keys.login_attempts(identifier)
    Cache.delete(key)
    :ok
  end

  @doc """
  Check API rate limit for a user.
  """
  @spec check_api(String.t()) :: {:allow, integer()} | {:deny, integer()}
  def check_api(user_id) do
    check("api", user_id, limit: @api_limit, window: @api_window)
  end

  @doc """
  Get current usage stats for a rate limit.
  """
  @spec get_usage(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_usage(scope, identifier) do
    key = Keys.rate_limit(scope, identifier)

    with {:ok, count} <- get_counter(key),
         {:ok, ttl} <- Cache.ttl(key) do
      {:ok,
       %{
         current: count,
         remaining: max(@default_limit - count, 0),
         resets_in_ms: max(ttl, 0)
       }}
    end
  end

  @doc """
  Manually reset a rate limit.
  """
  @spec reset(String.t(), String.t()) :: :ok
  def reset(scope, identifier) do
    key = Keys.rate_limit(scope, identifier)
    Cache.delete(key)
    :ok
  end

  # ============================================================================
  # Fixed Window Algorithm
  # ============================================================================

  defp fixed_window_check(key, limit, window) do
    case increment_with_expiry(key, window) do
      {:ok, count} when count <= limit ->
        {:allow, limit - count}

      {:ok, _count} ->
        # Over limit, get remaining time
        case Cache.ttl(key) do
          {:ok, ttl} when ttl > 0 -> {:deny, ttl}
          _ -> {:deny, window}
        end

      {:error, _} ->
        # Allow on error to prevent blocking
        {:allow, limit}
    end
  end

  # ============================================================================
  # Sliding Window Algorithm
  # ============================================================================

  defp sliding_window_check(key, limit, window) do
    now = System.system_time(:millisecond)
    window_start = now - window

    # Use sorted set with timestamp as score
    pipeline = [
      # Remove old entries
      ["ZREMRANGEBYSCORE", "hellen:#{key}", "-inf", window_start],
      # Add current request
      ["ZADD", "hellen:#{key}", now, "#{now}:#{:rand.uniform(1_000_000)}"],
      # Count requests in window
      ["ZCARD", "hellen:#{key}"],
      # Set expiry
      ["PEXPIRE", "hellen:#{key}", window]
    ]

    case Redix.pipeline(@redis_name, pipeline) do
      {:ok, [_, _, count, _]} when count <= limit ->
        {:allow, limit - count}

      {:ok, [_, _, _count, _]} ->
        {:deny, window}

      {:error, _} ->
        {:allow, limit}
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp get_counter(key) do
    case Cache.get!(key) do
      nil -> {:ok, 0}
      count when is_integer(count) -> {:ok, count}
      _ -> {:ok, 0}
    end
  end

  defp increment_with_expiry(key, window) do
    prefixed_key = "hellen:#{key}"

    # Use MULTI/EXEC for atomicity
    pipeline = [
      ["INCR", prefixed_key],
      ["PEXPIRE", prefixed_key, window]
    ]

    case Redix.pipeline(@redis_name, pipeline) do
      {:ok, [count, _]} -> {:ok, count}
      error -> error
    end
  end
end
