defmodule Hellen.Cache.Stats do
  @moduledoc """
  Cache statistics and monitoring.

  Provides functions to monitor cache health, hit/miss rates,
  memory usage, and key statistics.

  ## Usage

      # Get cache health summary
      Cache.Stats.health()

      # Get detailed statistics
      Cache.Stats.detailed()

      # Monitor cache size
      Cache.Stats.key_count()
  """

  alias Hellen.Cache

  @redis_name :redix

  @doc """
  Get a quick health check summary.
  """
  @spec health() :: {:ok, map()} | {:error, any()}
  def health do
    with {:ok, "PONG"} <- Cache.ping(),
         {:ok, info} <- get_info("memory"),
         {:ok, key_count} <- key_count() do
      {:ok,
       %{
         status: :healthy,
         connected: true,
         memory_used: parse_bytes(info["used_memory"]),
         memory_peak: parse_bytes(info["used_memory_peak"]),
         key_count: key_count
       }}
    else
      {:error, reason} ->
        {:ok,
         %{
           status: :unhealthy,
           connected: false,
           error: inspect(reason)
         }}
    end
  end

  @doc """
  Get detailed cache statistics.
  """
  @spec detailed() :: {:ok, map()} | {:error, any()}
  def detailed do
    with {:ok, stats} <- get_info("stats"),
         {:ok, memory} <- get_info("memory"),
         {:ok, server} <- get_info("server"),
         {:ok, clients} <- get_info("clients") do
      {:ok,
       %{
         # Hit/miss statistics
         keyspace_hits: parse_int(stats["keyspace_hits"]),
         keyspace_misses: parse_int(stats["keyspace_misses"]),
         hit_rate: calculate_hit_rate(stats),

         # Memory
         memory_used: parse_bytes(memory["used_memory"]),
         memory_peak: parse_bytes(memory["used_memory_peak"]),
         memory_rss: parse_bytes(memory["used_memory_rss"]),
         memory_fragmentation: parse_float(memory["mem_fragmentation_ratio"]),

         # Server info
         redis_version: server["redis_version"],
         uptime_seconds: parse_int(server["uptime_in_seconds"]),
         uptime_days: parse_int(server["uptime_in_days"]),

         # Client connections
         connected_clients: parse_int(clients["connected_clients"]),
         blocked_clients: parse_int(clients["blocked_clients"]),

         # Operations
         total_commands: parse_int(stats["total_commands_processed"]),
         ops_per_sec: parse_int(stats["instantaneous_ops_per_sec"]),

         # Network
         total_net_input: parse_bytes(stats["total_net_input_bytes"]),
         total_net_output: parse_bytes(stats["total_net_output_bytes"])
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get the number of keys in the cache (with Hellen prefix).
  """
  @spec key_count() :: {:ok, integer()} | {:error, any()}
  def key_count do
    case scan_count("hellen:*") do
      {:ok, count} -> {:ok, count}
      error -> error
    end
  end

  @doc """
  Get key count by pattern.
  """
  @spec key_count(String.t()) :: {:ok, integer()} | {:error, any()}
  def key_count(pattern) do
    scan_count("hellen:#{pattern}")
  end

  @doc """
  Get memory usage for a specific key.
  """
  @spec memory_usage(String.t()) :: {:ok, integer() | nil} | {:error, any()}
  def memory_usage(key) do
    Redix.command(@redis_name, ["MEMORY", "USAGE", "hellen:#{key}"])
  end

  @doc """
  Get TTL information for a key.
  """
  @spec ttl_info(String.t()) :: {:ok, map()} | {:error, any()}
  def ttl_info(key) do
    case Cache.ttl(key) do
      {:ok, ttl} ->
        status =
          cond do
            ttl == -2 -> :not_found
            ttl == -1 -> :no_expiry
            ttl > 0 -> :expires_in
            true -> :unknown
          end

        {:ok,
         %{
           key: key,
           ttl_ms: ttl,
           status: status,
           expires_in_human: format_duration(ttl)
         }}

      error ->
        error
    end
  end

  @doc """
  List keys matching a pattern (for debugging).
  Use with caution in production!
  """
  @spec list_keys(String.t(), keyword()) :: {:ok, [String.t()]} | {:error, any()}
  def list_keys(pattern, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    case scan_keys("hellen:#{pattern}", limit) do
      {:ok, keys} ->
        {:ok, Enum.map(keys, &String.replace_prefix(&1, "hellen:", ""))}

      error ->
        error
    end
  end

  @doc """
  Get breakdown of keys by domain.
  """
  @spec key_breakdown() :: {:ok, map()} | {:error, any()}
  def key_breakdown do
    domains = [
      "analysis:*",
      "lesson:*",
      "user:*",
      "institution:*",
      "billing:*",
      "planning:*",
      "assessment:*",
      "lock:*",
      "session:*",
      "ratelimit:*"
    ]

    results =
      domains
      |> Enum.map(fn pattern ->
        domain = String.replace(pattern, ":*", "")

        count =
          case key_count(pattern) do
            {:ok, c} -> c
            _ -> 0
          end

        {domain, count}
      end)
      |> Enum.into(%{})

    {:ok, results}
  end

  @doc """
  Get slow log entries.
  """
  @spec slowlog(integer()) :: {:ok, [map()]} | {:error, any()}
  def slowlog(count \\ 10) do
    case Redix.command(@redis_name, ["SLOWLOG", "GET", count]) do
      {:ok, entries} ->
        formatted =
          Enum.map(entries, fn [id, timestamp, duration, command | _] ->
            %{
              id: id,
              timestamp: DateTime.from_unix!(timestamp),
              duration_us: duration,
              command: command
            }
          end)

        {:ok, formatted}

      error ->
        error
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp get_info(section) do
    case Redix.command(@redis_name, ["INFO", section]) do
      {:ok, info} -> {:ok, parse_info(info)}
      error -> error
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

  defp parse_int(nil), do: 0
  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(value) when is_float(value), do: value

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end

  defp parse_bytes(nil), do: "0 B"

  defp parse_bytes(value) when is_binary(value) do
    parse_bytes(parse_int(value))
  end

  defp parse_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  defp calculate_hit_rate(stats) do
    hits = parse_int(stats["keyspace_hits"])
    misses = parse_int(stats["keyspace_misses"])
    total = hits + misses

    if total > 0 do
      Float.round(hits / total * 100, 2)
    else
      0.0
    end
  end

  defp scan_count(pattern, cursor \\ "0", acc \\ 0) do
    case Redix.command(@redis_name, ["SCAN", cursor, "MATCH", pattern, "COUNT", "1000"]) do
      {:ok, ["0", keys]} ->
        {:ok, acc + length(keys)}

      {:ok, [next_cursor, keys]} ->
        scan_count(pattern, next_cursor, acc + length(keys))

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp scan_keys(pattern, limit, cursor \\ "0", acc \\ []) do
    if length(acc) >= limit do
      {:ok, Enum.take(acc, limit)}
    else
      case Redix.command(@redis_name, ["SCAN", cursor, "MATCH", pattern, "COUNT", "100"]) do
        {:ok, ["0", keys]} ->
          {:ok, Enum.take(acc ++ keys, limit)}

        {:ok, [next_cursor, keys]} ->
          scan_keys(pattern, limit, next_cursor, acc ++ keys)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp format_duration(ms) when ms < 0, do: "N/A"
  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms) when ms < 3_600_000, do: "#{Float.round(ms / 60_000, 1)}m"
  defp format_duration(ms), do: "#{Float.round(ms / 3_600_000, 1)}h"
end
