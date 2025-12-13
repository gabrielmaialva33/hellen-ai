defmodule Hellen.Cache do
  @moduledoc """
  Main cache module providing a unified interface for Redis-based caching.

  ## Architecture

  The cache system is organized into several modules:

  - `Hellen.Cache` - Core operations (get, set, delete, etc.)
  - `Hellen.Cache.Keys` - Key generation and namespacing
  - `Hellen.Cache.Serializer` - Encoding/decoding values
  - `Hellen.Cache.Stats` - Cache statistics and monitoring
  - Domain modules (`Analysis`, `Lessons`, `Users`) - High-level caching functions

  ## Usage

      # Simple key-value operations
      Cache.set("user:123", %{name: "John"}, ttl: :timer.hours(1))
      Cache.get("user:123")

      # With fetch pattern (get or compute)
      Cache.fetch("expensive:data", fn -> compute_expensive_data() end, ttl: :timer.minutes(30))

      # Domain-specific caching
      Cache.Analysis.get_or_cache(analysis_id, fn -> load_analysis(analysis_id) end)

  ## Configuration

  Configure Redis URL in your config:

      config :hellen, :redis_url, "redis://localhost:6379"

  ## TTL Values

  All TTL values are in milliseconds. Use `:timer` helpers:
  - `:timer.seconds(30)` = 30 seconds
  - `:timer.minutes(5)` = 5 minutes
  - `:timer.hours(1)` = 1 hour
  """

  alias Hellen.Cache.{Keys, Serializer}

  require Logger

  @redis_name :redix

  # Default TTLs
  @default_ttl :timer.minutes(15)
  @short_ttl :timer.minutes(5)
  @long_ttl :timer.hours(1)
  @day_ttl :timer.hours(24)

  # ============================================================================
  # Core Operations
  # ============================================================================

  @doc """
  Get a value from cache.

  Returns `{:ok, value}` if found, `{:ok, nil}` if not found,
  or `{:error, reason}` on failure.
  """
  @spec get(String.t()) :: {:ok, any()} | {:error, any()}
  def get(key) do
    case command(["GET", Keys.prefix(key)]) do
      {:ok, nil} -> {:ok, nil}
      {:ok, value} -> {:ok, Serializer.decode(value)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get a value from cache, returning the value directly or nil.
  """
  @spec get!(String.t()) :: any()
  def get!(key) do
    case get(key) do
      {:ok, value} -> value
      {:error, _} -> nil
    end
  end

  @doc """
  Set a value in cache with optional TTL.

  ## Options

  - `:ttl` - Time to live in milliseconds (default: 15 minutes)
  - `:nx` - Only set if key does not exist
  - `:xx` - Only set if key already exists
  """
  @spec set(String.t(), any(), keyword()) :: {:ok, any()} | {:error, any()}
  def set(key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    prefixed_key = Keys.prefix(key)
    encoded_value = Serializer.encode(value)

    args =
      ["SET", prefixed_key, encoded_value]
      |> maybe_add_ttl(ttl)
      |> maybe_add_nx(Keyword.get(opts, :nx, false))
      |> maybe_add_xx(Keyword.get(opts, :xx, false))

    command(args)
  end

  @doc """
  Delete a key from cache.
  """
  @spec delete(String.t()) :: {:ok, integer()} | {:error, any()}
  def delete(key) do
    command(["DEL", Keys.prefix(key)])
  end

  @doc """
  Delete multiple keys matching a pattern.

  **Warning**: Uses SCAN, safe for production but may be slow with many keys.
  """
  @spec delete_pattern(String.t()) :: {:ok, integer()} | {:error, any()}
  def delete_pattern(pattern) do
    prefixed_pattern = Keys.prefix(pattern)

    case scan_keys(prefixed_pattern) do
      {:ok, []} ->
        {:ok, 0}

      {:ok, keys} ->
        case command(["DEL" | keys]) do
          {:ok, count} -> {:ok, count}
          error -> error
        end

      error ->
        error
    end
  end

  @doc """
  Check if a key exists.
  """
  @spec exists?(String.t()) :: boolean()
  def exists?(key) do
    case command(["EXISTS", Keys.prefix(key)]) do
      {:ok, 1} -> true
      _ -> false
    end
  end

  @doc """
  Get remaining TTL for a key in milliseconds.
  Returns -1 if key has no TTL, -2 if key doesn't exist.
  """
  @spec ttl(String.t()) :: {:ok, integer()} | {:error, any()}
  def ttl(key) do
    command(["PTTL", Keys.prefix(key)])
  end

  @doc """
  Set a new TTL for an existing key.
  """
  @spec expire(String.t(), integer()) :: {:ok, integer()} | {:error, any()}
  def expire(key, ttl_ms) do
    command(["PEXPIRE", Keys.prefix(key), ttl_ms])
  end

  @doc """
  Increment a numeric value. Creates key with value 1 if it doesn't exist.
  """
  @spec incr(String.t()) :: {:ok, integer()} | {:error, any()}
  def incr(key) do
    command(["INCR", Keys.prefix(key)])
  end

  @doc """
  Increment by a specific amount.
  """
  @spec incrby(String.t(), integer()) :: {:ok, integer()} | {:error, any()}
  def incrby(key, amount) do
    command(["INCRBY", Keys.prefix(key), amount])
  end

  # ============================================================================
  # Fetch Pattern (Get or Compute)
  # ============================================================================

  @doc """
  Get a cached value or compute and cache it if not found.

  This is the recommended pattern for caching expensive computations.

  ## Examples

      # Simple usage
      Cache.fetch("user:123:profile", fn -> load_user_profile(123) end)

      # With custom TTL
      Cache.fetch("stats:daily", fn -> compute_stats() end, ttl: :timer.hours(1))

      # With stale-while-revalidate (return stale data while refreshing)
      Cache.fetch("data", fn -> load() end, ttl: :timer.minutes(5), stale_ttl: :timer.minutes(30))
  """
  @spec fetch(String.t(), (-> any()), keyword()) :: {:ok, any()} | {:error, any()}
  def fetch(key, compute_fn, opts \\ []) do
    case get(key) do
      {:ok, nil} ->
        compute_and_cache(key, compute_fn, opts)

      {:ok, value} ->
        # Check for stale-while-revalidate
        maybe_refresh_stale(key, compute_fn, opts)
        {:ok, value}

      {:error, reason} ->
        Logger.warning("[Cache] Read error for #{key}: #{inspect(reason)}, computing fresh value")
        compute_and_cache(key, compute_fn, opts)
    end
  end

  @doc """
  Same as `fetch/3` but returns the value directly or raises on error.
  """
  @spec fetch!(String.t(), (-> any()), keyword()) :: any()
  def fetch!(key, compute_fn, opts \\ []) do
    case fetch(key, compute_fn, opts) do
      {:ok, value} -> value
      {:error, reason} -> raise "Cache fetch failed: #{inspect(reason)}"
    end
  end

  # ============================================================================
  # Hash Operations (for structured data)
  # ============================================================================

  @doc """
  Set a field in a hash.
  """
  @spec hset(String.t(), String.t(), any()) :: {:ok, any()} | {:error, any()}
  def hset(key, field, value) do
    command(["HSET", Keys.prefix(key), field, Serializer.encode(value)])
  end

  @doc """
  Set multiple fields in a hash.
  """
  @spec hmset(String.t(), map()) :: {:ok, any()} | {:error, any()}
  def hmset(key, map) when is_map(map) do
    args =
      map
      |> Enum.flat_map(fn {k, v} -> [to_string(k), Serializer.encode(v)] end)

    command(["HSET", Keys.prefix(key) | args])
  end

  @doc """
  Get a field from a hash.
  """
  @spec hget(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def hget(key, field) do
    case command(["HGET", Keys.prefix(key), field]) do
      {:ok, nil} -> {:ok, nil}
      {:ok, value} -> {:ok, Serializer.decode(value)}
      error -> error
    end
  end

  @doc """
  Get all fields and values from a hash.
  """
  @spec hgetall(String.t()) :: {:ok, map()} | {:error, any()}
  def hgetall(key) do
    case command(["HGETALL", Keys.prefix(key)]) do
      {:ok, []} ->
        {:ok, %{}}

      {:ok, list} ->
        map =
          list
          |> Enum.chunk_every(2)
          |> Enum.into(%{}, fn [k, v] -> {k, Serializer.decode(v)} end)

        {:ok, map}

      error ->
        error
    end
  end

  @doc """
  Delete a field from a hash.
  """
  @spec hdel(String.t(), String.t()) :: {:ok, integer()} | {:error, any()}
  def hdel(key, field) do
    command(["HDEL", Keys.prefix(key), field])
  end

  # ============================================================================
  # List Operations (for queues/recent items)
  # ============================================================================

  @doc """
  Push value(s) to the left of a list.
  """
  @spec lpush(String.t(), any() | [any()]) :: {:ok, integer()} | {:error, any()}
  def lpush(key, values) when is_list(values) do
    encoded = Enum.map(values, &Serializer.encode/1)
    command(["LPUSH", Keys.prefix(key) | encoded])
  end

  def lpush(key, value), do: lpush(key, [value])

  @doc """
  Get a range of elements from a list.
  """
  @spec lrange(String.t(), integer(), integer()) :: {:ok, [any()]} | {:error, any()}
  def lrange(key, start, stop) do
    case command(["LRANGE", Keys.prefix(key), start, stop]) do
      {:ok, values} -> {:ok, Enum.map(values, &Serializer.decode/1)}
      error -> error
    end
  end

  @doc """
  Trim a list to the specified range.
  """
  @spec ltrim(String.t(), integer(), integer()) :: {:ok, String.t()} | {:error, any()}
  def ltrim(key, start, stop) do
    command(["LTRIM", Keys.prefix(key), start, stop])
  end

  # ============================================================================
  # Set Operations (for unique collections)
  # ============================================================================

  @doc """
  Add member(s) to a set.
  """
  @spec sadd(String.t(), any() | [any()]) :: {:ok, integer()} | {:error, any()}
  def sadd(key, members) when is_list(members) do
    encoded = Enum.map(members, &Serializer.encode/1)
    command(["SADD", Keys.prefix(key) | encoded])
  end

  def sadd(key, member), do: sadd(key, [member])

  @doc """
  Get all members of a set.
  """
  @spec smembers(String.t()) :: {:ok, [any()]} | {:error, any()}
  def smembers(key) do
    case command(["SMEMBERS", Keys.prefix(key)]) do
      {:ok, values} -> {:ok, Enum.map(values, &Serializer.decode/1)}
      error -> error
    end
  end

  @doc """
  Check if a value is a member of a set.
  """
  @spec sismember?(String.t(), any()) :: boolean()
  def sismember?(key, member) do
    case command(["SISMEMBER", Keys.prefix(key), Serializer.encode(member)]) do
      {:ok, 1} -> true
      _ -> false
    end
  end

  # ============================================================================
  # Sorted Set Operations (for rankings/leaderboards)
  # ============================================================================

  @doc """
  Add a member with score to a sorted set.
  """
  @spec zadd(String.t(), number(), any()) :: {:ok, integer()} | {:error, any()}
  def zadd(key, score, member) do
    command(["ZADD", Keys.prefix(key), score, Serializer.encode(member)])
  end

  @doc """
  Get members by score range (ascending).
  """
  @spec zrangebyscore(String.t(), number() | String.t(), number() | String.t(), keyword()) ::
          {:ok, [any()]} | {:error, any()}
  def zrangebyscore(key, min, max, opts \\ []) do
    args = ["ZRANGEBYSCORE", Keys.prefix(key), min, max]

    args =
      if Keyword.get(opts, :withscores, false) do
        args ++ ["WITHSCORES"]
      else
        args
      end

    withscores = Keyword.get(opts, :withscores, false)

    case command(args) do
      {:ok, values} when withscores ->
        pairs =
          values
          |> Enum.chunk_every(2)
          |> Enum.map(fn [member, score] ->
            {Serializer.decode(member), String.to_float(score)}
          end)

        {:ok, pairs}

      {:ok, values} ->
        {:ok, Enum.map(values, &Serializer.decode/1)}

      error ->
        error
    end
  end

  @doc """
  Get top N members from a sorted set (descending).
  """
  @spec zrevrange(String.t(), integer(), integer(), keyword()) ::
          {:ok, [any()]} | {:error, any()}
  def zrevrange(key, start, stop, opts \\ []) do
    withscores = Keyword.get(opts, :withscores, false)
    args = ["ZREVRANGE", Keys.prefix(key), start, stop]

    args =
      if withscores do
        args ++ ["WITHSCORES"]
      else
        args
      end

    case command(args) do
      {:ok, values} when withscores ->
        pairs =
          values
          |> Enum.chunk_every(2)
          |> Enum.map(fn [member, score] ->
            {Serializer.decode(member), String.to_float(score)}
          end)

        {:ok, pairs}

      {:ok, values} ->
        {:ok, Enum.map(values, &Serializer.decode/1)}

      error ->
        error
    end
  end

  # ============================================================================
  # Utility Functions
  # ============================================================================

  @doc """
  Flush the entire cache (use with caution!).
  Only flushes keys with our prefix.
  """
  @spec flush_all() :: {:ok, integer()} | {:error, any()}
  def flush_all do
    delete_pattern("*")
  end

  @doc """
  Get cache statistics.
  """
  @spec stats() :: {:ok, map()} | {:error, any()}
  def stats do
    case command(["INFO", "stats"]) do
      {:ok, info} -> {:ok, parse_info(info)}
      error -> error
    end
  end

  @doc """
  Ping Redis to check connectivity.
  """
  @spec ping() :: {:ok, String.t()} | {:error, any()}
  def ping do
    command(["PING"])
  end

  @doc """
  Execute a pipeline of commands atomically.
  """
  @spec pipeline([list()]) :: {:ok, [any()]} | {:error, any()}
  def pipeline(commands) do
    prefixed_commands =
      Enum.map(commands, fn [cmd | args] ->
        case cmd do
          cmd when cmd in ["GET", "SET", "DEL", "EXISTS", "EXPIRE", "PEXPIRE", "TTL", "PTTL"] ->
            [cmd, Keys.prefix(hd(args)) | tl(args)]

          _ ->
            [cmd | args]
        end
      end)

    Redix.pipeline(@redis_name, prefixed_commands)
  end

  # ============================================================================
  # TTL Helpers (exported for use in domain modules)
  # ============================================================================

  def default_ttl, do: @default_ttl
  def short_ttl, do: @short_ttl
  def long_ttl, do: @long_ttl
  def day_ttl, do: @day_ttl

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp command(args) do
    Redix.command(@redis_name, args)
  rescue
    e ->
      Logger.error("[Cache] Redis command failed: #{inspect(e)}")
      {:error, e}
  end

  defp scan_keys(pattern, cursor \\ "0", acc \\ []) do
    case command(["SCAN", cursor, "MATCH", pattern, "COUNT", "100"]) do
      {:ok, ["0", keys]} ->
        {:ok, acc ++ keys}

      {:ok, [next_cursor, keys]} ->
        scan_keys(pattern, next_cursor, acc ++ keys)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_add_ttl(args, nil), do: args
  defp maybe_add_ttl(args, ttl) when is_integer(ttl), do: args ++ ["PX", ttl]

  defp maybe_add_nx(args, true), do: args ++ ["NX"]
  defp maybe_add_nx(args, _), do: args

  defp maybe_add_xx(args, true), do: args ++ ["XX"]
  defp maybe_add_xx(args, _), do: args

  defp compute_and_cache(key, compute_fn, opts) do
    value = compute_fn.()
    ttl = Keyword.get(opts, :ttl, @default_ttl)

    case set(key, value, ttl: ttl) do
      {:ok, _} ->
        {:ok, value}

      {:error, reason} ->
        Logger.warning("[Cache] Failed to cache #{key}: #{inspect(reason)}")
        {:ok, value}
    end
  rescue
    e ->
      Logger.error("[Cache] Compute function failed for #{key}: #{inspect(e)}")
      {:error, e}
  end

  defp maybe_refresh_stale(key, compute_fn, opts) do
    case Keyword.get(opts, :stale_ttl) do
      nil -> :ok
      stale_ttl when is_integer(stale_ttl) -> check_and_refresh(key, compute_fn, opts, stale_ttl)
      _ -> :ok
    end
  end

  defp check_and_refresh(key, compute_fn, opts, stale_ttl) do
    case ttl(key) do
      {:ok, remaining} when remaining > 0 and remaining < stale_ttl ->
        Task.start(fn -> compute_and_cache(key, compute_fn, opts) end)

      _ ->
        :ok
    end
  end

  defp parse_info(info) do
    info
    |> String.split("\r\n")
    |> Enum.filter(&String.contains?(&1, ":"))
    |> Enum.into(%{}, fn line ->
      [key, value] = String.split(line, ":", parts: 2)
      {key, value}
    end)
  end
end
