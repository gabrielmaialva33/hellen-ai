defmodule Hellen.AI.NvidiaKeyPool do
  @moduledoc """
  GenServer for round-robin rotation of NVIDIA API keys.

  Distributes API calls across multiple keys to avoid rate limiting
  and improve throughput for parallel analysis tasks.
  """

  use GenServer

  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the next API key from the pool using round-robin rotation.
  """
  def get_key do
    GenServer.call(__MODULE__, :get_key)
  end

  @doc """
  Returns the number of keys in the pool.
  """
  def pool_size do
    GenServer.call(__MODULE__, :pool_size)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    keys = get_configured_keys()
    Logger.info("[NvidiaKeyPool] Initialized with #{length(keys)} API key(s)")
    {:ok, %{keys: keys, index: 0}}
  end

  @impl true
  def handle_call(:get_key, _from, %{keys: keys, index: index} = state) do
    key = Enum.at(keys, rem(index, length(keys)))
    {:reply, key, %{state | index: index + 1}}
  end

  @impl true
  def handle_call(:pool_size, _from, %{keys: keys} = state) do
    {:reply, length(keys), state}
  end

  # Private Functions

  defp get_configured_keys do
    # Try multiple keys first (comma-separated)
    case Application.get_env(:hellen, :nvidia_api_keys) do
      [_ | _] = keys ->
        keys

      _ ->
        # Fallback to single key
        case Application.get_env(:hellen, :nvidia_api_key) do
          nil -> raise "No NVIDIA API key configured"
          key -> [key]
        end
    end
  end
end
