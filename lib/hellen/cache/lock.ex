defmodule Hellen.Cache.Lock do
  @moduledoc """
  Distributed locking using Redis with automatic expiry.

  Implements a simple but effective distributed lock using Redis SET NX PX.
  Suitable for preventing duplicate job processing and coordinating
  distributed operations.

  ## Usage

      # Acquire a lock
      case Lock.acquire("process:lesson:123") do
        {:ok, token} ->
          try do
            do_work()
          after
            Lock.release("process:lesson:123", token)
          end

        {:error, :locked} ->
          # Someone else has the lock
          :skip
      end

      # With helper function
      Lock.with_lock("resource:456", fn ->
        do_exclusive_work()
      end)

  ## Important Notes

  - Locks automatically expire after TTL to prevent deadlocks
  - Always release locks in a `try/after` block
  - Use unique tokens to ensure only lock owner can release
  """

  alias Hellen.Cache
  alias Hellen.Cache.Keys

  require Logger

  @redis_name :redix

  # Default lock TTL (30 seconds)
  @default_ttl :timer.seconds(30)

  # Maximum lock TTL (5 minutes)
  @max_ttl :timer.minutes(5)

  # Retry settings
  @default_retry_count 3
  @default_retry_delay 100

  @doc """
  Acquire a distributed lock.

  Returns `{:ok, token}` if lock acquired, `{:error, :locked}` if already locked.

  ## Options

  - `:ttl` - Lock TTL in milliseconds (default: 30 seconds, max: 5 minutes)
  - `:retry` - Number of retry attempts (default: 0)
  - `:retry_delay` - Delay between retries in ms (default: 100)
  """
  @spec acquire(String.t(), keyword()) :: {:ok, String.t()} | {:error, :locked}
  def acquire(resource, opts \\ []) do
    ttl = min(Keyword.get(opts, :ttl, @default_ttl), @max_ttl)
    retry = Keyword.get(opts, :retry, 0)
    retry_delay = Keyword.get(opts, :retry_delay, @default_retry_delay)

    token = generate_token()
    key = Keys.lock(resource)

    do_acquire(key, token, ttl, retry, retry_delay)
  end

  @doc """
  Release a distributed lock.

  Only releases if the token matches (prevents releasing someone else's lock).
  """
  @spec release(String.t(), String.t()) :: :ok | {:error, :not_owner}
  def release(resource, token) do
    key = "hellen:#{Keys.lock(resource)}"

    # Use Lua script for atomic check-and-delete
    script = """
    if redis.call("GET", KEYS[1]) == ARGV[1] then
      return redis.call("DEL", KEYS[1])
    else
      return 0
    end
    """

    case Redix.command(@redis_name, ["EVAL", script, 1, key, token]) do
      {:ok, 1} ->
        :ok

      {:ok, 0} ->
        {:error, :not_owner}

      {:error, reason} ->
        Logger.warning("[Lock] Failed to release lock #{resource}: #{inspect(reason)}")
        {:error, :not_owner}
    end
  end

  @doc """
  Execute a function while holding a lock.

  Automatically acquires and releases the lock.

  ## Options

  - `:ttl` - Lock TTL (default: 30 seconds)
  - `:retry` - Retry attempts if lock is held (default: 3)
  - `:retry_delay` - Delay between retries (default: 100ms)
  - `:on_locked` - Function to call if lock cannot be acquired

  ## Examples

      Lock.with_lock("process:123", fn ->
        do_work()
      end)

      Lock.with_lock("process:123", fn ->
        do_work()
      end, on_locked: fn -> {:error, :busy} end)
  """
  @spec with_lock(String.t(), (-> any()), keyword()) :: any()
  def with_lock(resource, fun, opts \\ []) do
    retry = Keyword.get(opts, :retry, @default_retry_count)
    on_locked = Keyword.get(opts, :on_locked, fn -> {:error, :locked} end)

    acquire_opts = Keyword.put(opts, :retry, retry)

    case acquire(resource, acquire_opts) do
      {:ok, token} ->
        try do
          fun.()
        after
          release(resource, token)
        end

      {:error, :locked} ->
        on_locked.()
    end
  end

  @doc """
  Extend the TTL of an existing lock.

  Only works if you own the lock (token must match).
  """
  @spec extend(String.t(), String.t(), integer()) :: :ok | {:error, :not_owner}
  def extend(resource, token, ttl \\ @default_ttl) do
    key = "hellen:#{Keys.lock(resource)}"
    ttl = min(ttl, @max_ttl)

    # Use Lua script for atomic check-and-extend
    script = """
    if redis.call("GET", KEYS[1]) == ARGV[1] then
      return redis.call("PEXPIRE", KEYS[1], ARGV[2])
    else
      return 0
    end
    """

    case Redix.command(@redis_name, ["EVAL", script, 1, key, token, ttl]) do
      {:ok, 1} ->
        :ok

      {:ok, 0} ->
        {:error, :not_owner}

      {:error, reason} ->
        Logger.warning("[Lock] Failed to extend lock #{resource}: #{inspect(reason)}")
        {:error, :not_owner}
    end
  end

  @doc """
  Check if a resource is currently locked.
  """
  @spec locked?(String.t()) :: boolean()
  def locked?(resource) do
    Cache.exists?(Keys.lock(resource))
  end

  @doc """
  Get the remaining TTL of a lock.
  """
  @spec ttl(String.t()) :: {:ok, integer()} | {:error, any()}
  def ttl(resource) do
    Cache.ttl(Keys.lock(resource))
  end

  @doc """
  Force release a lock (admin use only).
  Use with caution - can cause issues if lock is actively being used.
  """
  @spec force_release(String.t()) :: :ok
  def force_release(resource) do
    Cache.delete(Keys.lock(resource))
    :ok
  end

  @doc """
  Lock for job processing to prevent duplicate execution.
  """
  @spec acquire_job_lock(String.t(), binary(), keyword()) :: {:ok, String.t()} | {:error, :locked}
  def acquire_job_lock(job_type, id, opts \\ []) do
    acquire(Keys.job_lock(job_type, id), opts)
  end

  @doc """
  Release a job processing lock.
  """
  @spec release_job_lock(String.t(), binary(), String.t()) :: :ok | {:error, :not_owner}
  def release_job_lock(job_type, id, token) do
    release(Keys.job_lock(job_type, id), token)
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp do_acquire(key, token, ttl, retries_left, retry_delay) do
    prefixed_key = "hellen:#{key}"

    case Redix.command(@redis_name, ["SET", prefixed_key, token, "NX", "PX", ttl]) do
      {:ok, "OK"} ->
        {:ok, token}

      {:ok, nil} when retries_left > 0 ->
        Process.sleep(retry_delay)
        do_acquire(key, token, ttl, retries_left - 1, retry_delay)

      {:ok, nil} ->
        {:error, :locked}

      {:error, reason} ->
        Logger.warning("[Lock] Failed to acquire lock #{key}: #{inspect(reason)}")
        {:error, :locked}
    end
  end

  defp generate_token do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
  end
end
