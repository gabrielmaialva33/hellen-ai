defmodule HellenWeb.AdminLive.Health do
  @moduledoc """
  Admin System Health - Monitor system status and health metrics.
  """
  use HellenWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(30_000, self(), :refresh_health)
    end

    {:ok,
     socket
     |> assign(page_title: "Sistema - Admin")
     |> assign_health_data()}
  end

  @impl true
  def handle_info(:refresh_health, socket) do
    {:noreply, assign_health_data(socket)}
  end

  defp assign_health_data(socket) do
    socket
    |> assign(beam_info: get_beam_info())
    |> assign(database_info: get_database_info())
    |> assign(oban_info: get_oban_info())
    |> assign(redis_info: get_redis_info())
  end

  defp get_beam_info do
    memory = :erlang.memory()

    %{
      uptime: get_uptime(),
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      total_memory_mb: div(memory[:total], 1024 * 1024),
      processes_memory_mb: div(memory[:processes], 1024 * 1024),
      atom_count: :erlang.system_info(:atom_count),
      atom_limit: :erlang.system_info(:atom_limit),
      schedulers: :erlang.system_info(:schedulers_online),
      otp_release: :erlang.system_info(:otp_release) |> to_string(),
      elixir_version: System.version()
    }
  end

  defp get_uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_seconds = div(uptime_ms, 1000)
    days = div(uptime_seconds, 86_400)
    hours = div(rem(uptime_seconds, 86_400), 3600)
    minutes = div(rem(uptime_seconds, 3600), 60)

    cond do
      days > 0 -> "#{days}d #{hours}h #{minutes}m"
      hours > 0 -> "#{hours}h #{minutes}m"
      true -> "#{minutes}m"
    end
  end

  defp get_database_info do
    try do
      pool_size = Application.get_env(:hellen, Hellen.Repo)[:pool_size] || 10

      %{status: :ok, pool_size: pool_size}
    rescue
      _ -> %{status: :error, message: "Database unavailable"}
    end
  end

  defp get_oban_info do
    try do
      queues = Application.get_env(:hellen, Oban)[:queues] || []

      %{
        status: :ok,
        queues:
          Enum.map(queues, fn {name, limit} ->
            %{name: name, limit: limit}
          end)
      }
    rescue
      _ -> %{status: :error, message: "Oban unavailable"}
    end
  end

  defp get_redis_info do
    redis_url = Application.get_env(:hellen, :redis_url)

    if redis_url do
      %{status: :ok}
    else
      %{status: :error, message: "Redis not configured"}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <div class="flex items-center gap-2">
            <.link
              navigate={~p"/admin"}
              class="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
            >
              <.icon name="hero-arrow-left" class="h-5 w-5" />
            </.link>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Saude do Sistema</h1>
          </div>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
            Metricas e status dos servicos
          </p>
        </div>
        <div class="flex items-center gap-2 text-sm text-gray-500 dark:text-gray-400">
          <.icon name="hero-arrow-path" class="h-4 w-4" /> Atualizado a cada 30s
        </div>
      </div>
      <!-- Service Status Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <.service_card
          name="Aplicacao"
          icon="hero-server"
          status={:ok}
          details={"Uptime: #{@beam_info.uptime}"}
        />
        <.service_card
          name="Database"
          icon="hero-circle-stack"
          status={@database_info.status}
          details={"Pool: #{@database_info[:pool_size] || "N/A"}"}
        />
        <.service_card
          name="Oban Jobs"
          icon="hero-queue-list"
          status={@oban_info.status}
          details={"#{length(@oban_info[:queues] || [])} filas"}
        />
        <.service_card
          name="Redis Cache"
          icon="hero-bolt"
          status={@redis_info.status}
          details={if @redis_info.status == :ok, do: "Conectado", else: @redis_info[:message]}
        />
      </div>
      <!-- BEAM/Erlang Info -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">BEAM Virtual Machine</h3>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-6">
          <.metric_item label="Uptime" value={@beam_info.uptime} />
          <.metric_item label="OTP Release" value={@beam_info.otp_release} />
          <.metric_item label="Elixir" value={@beam_info.elixir_version} />
          <.metric_item label="Schedulers" value={@beam_info.schedulers} />
        </div>
      </div>
      <!-- Memory & Processes -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Memoria</h3>
          <div class="space-y-4">
            <.metric_bar
              label="Total"
              value={"#{@beam_info.total_memory_mb} MB"}
              percentage={min(@beam_info.total_memory_mb / 10, 100)}
              color="bg-indigo-500"
            />
            <.metric_bar
              label="Processos"
              value={"#{@beam_info.processes_memory_mb} MB"}
              percentage={@beam_info.processes_memory_mb / @beam_info.total_memory_mb * 100}
              color="bg-purple-500"
            />
          </div>
        </div>

        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Processos & Atoms</h3>
          <div class="space-y-4">
            <.metric_bar
              label="Processos"
              value={"#{@beam_info.process_count} / #{@beam_info.process_limit}"}
              percentage={@beam_info.process_count / @beam_info.process_limit * 100}
              color="bg-emerald-500"
            />
            <.metric_bar
              label="Atoms"
              value={"#{@beam_info.atom_count} / #{@beam_info.atom_limit}"}
              percentage={@beam_info.atom_count / @beam_info.atom_limit * 100}
              color="bg-amber-500"
            />
          </div>
        </div>
      </div>
      <!-- Oban Queues -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
          Filas de Processamento (Oban)
        </h3>
        <div :if={@oban_info.status == :ok} class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div
            :for={queue <- @oban_info.queues}
            class="p-4 rounded-lg bg-gray-50 dark:bg-slate-900/50"
          >
            <p class="text-sm font-medium text-gray-900 dark:text-white capitalize">
              <%= queue.name %>
            </p>
            <p class="text-xs text-gray-500 dark:text-gray-400">Limite: <%= queue.limit %> workers</p>
          </div>
        </div>
        <div :if={@oban_info.status != :ok} class="text-red-600 dark:text-red-400">
          <%= @oban_info[:message] || "Erro ao carregar filas" %>
        </div>
      </div>
      <!-- Environment Info -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Ambiente</h3>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-6">
          <.metric_item
            label="Mix Env"
            value={Application.get_env(:hellen, :environment, :prod) |> to_string()}
          />
          <.metric_item label="Node" value={Node.self() |> to_string() |> String.slice(0..20)} />
          <.metric_item label="Phoenix" value={Application.spec(:phoenix, :vsn) |> to_string()} />
          <.metric_item
            label="LiveView"
            value={Application.spec(:phoenix_live_view, :vsn) |> to_string()}
          />
        </div>
      </div>
    </div>
    """
  end

  defp service_card(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-4">
      <div class="flex items-center gap-3">
        <div class={[
          "w-10 h-10 rounded-lg flex items-center justify-center",
          if(@status == :ok,
            do: "bg-emerald-100 dark:bg-emerald-900/30",
            else: "bg-red-100 dark:bg-red-900/30"
          )
        ]}>
          <.icon
            name={@icon}
            class={"h-5 w-5 " <> if(@status == :ok, do: "text-emerald-600 dark:text-emerald-400", else: "text-red-600 dark:text-red-400")}
          />
        </div>
        <div class="flex-1">
          <div class="flex items-center gap-2">
            <p class="text-sm font-medium text-gray-900 dark:text-white"><%= @name %></p>
            <span class={[
              "w-2 h-2 rounded-full",
              if(@status == :ok, do: "bg-emerald-500", else: "bg-red-500")
            ]}>
            </span>
          </div>
          <p class="text-xs text-gray-500 dark:text-gray-400"><%= @details %></p>
        </div>
      </div>
    </div>
    """
  end

  defp metric_item(assigns) do
    ~H"""
    <div>
      <p class="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wider"><%= @label %></p>
      <p class="text-lg font-semibold text-gray-900 dark:text-white mt-1"><%= @value %></p>
    </div>
    """
  end

  defp metric_bar(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-1">
        <span class="text-sm text-gray-700 dark:text-gray-300"><%= @label %></span>
        <span class="text-sm font-medium text-gray-900 dark:text-white"><%= @value %></span>
      </div>
      <div class="w-full h-2 bg-gray-200 dark:bg-slate-700 rounded-full overflow-hidden">
        <div
          class={[@color, "h-full rounded-full transition-all"]}
          style={"width: #{min(@percentage, 100)}%"}
        >
        </div>
      </div>
    </div>
    """
  end
end
