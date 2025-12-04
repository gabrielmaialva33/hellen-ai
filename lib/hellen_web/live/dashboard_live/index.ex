defmodule HellenWeb.DashboardLive.Index do
  @moduledoc """
  Dashboard LiveView - Quick actions and overview.
  Uses LiveView 1.1 patterns:
  - assign_async for stats (non-blocking)
  - streams for lesson list (memory efficient)
  """
  use HellenWeb, :live_view

  alias Hellen.Lessons

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(page_title: "Inicio")
     |> stream(:recent_lessons, [])
     |> assign_async(:stats, fn -> load_stats(user.id) end)
     |> load_lessons_async(user.id)}
  end

  defp load_lessons_async(socket, user_id) do
    if connected?(socket) do
      start_async(socket, :load_lessons, fn ->
        Lessons.list_lessons_by_user(user_id, limit: 5)
      end)
    else
      socket
    end
  end

  @impl true
  def handle_async(:load_lessons, {:ok, lessons}, socket) do
    {:noreply, stream(socket, :recent_lessons, lessons)}
  end

  def handle_async(:load_lessons, {:exit, _reason}, socket) do
    {:noreply, put_flash(socket, :error, "Erro ao carregar aulas")}
  end

  defp load_stats(user_id) do
    lessons = Lessons.list_lessons_by_user(user_id)

    {:ok,
     %{
       stats: %{
         total: length(lessons),
         completed: Enum.count(lessons, &(&1.status == "completed")),
         processing:
           Enum.count(lessons, &(&1.status in ["transcribing", "analyzing", "transcribed"])),
         pending: Enum.count(lessons, &(&1.status == "pending"))
       }
     }}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Welcome Header -->
      <div>
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
          Ola, <%= @current_user.name || "Professor" %>!
        </h1>
        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
          Bem-vindo ao Hellen AI. O que deseja fazer hoje?
        </p>
      </div>
      <!-- Quick Actions -->
      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <.link navigate={~p"/lessons/new"} class="block group">
          <div class="bg-gradient-to-br from-indigo-500 to-purple-600 rounded-xl p-6 text-white shadow-lg hover:shadow-xl transition-shadow">
            <div class="flex items-center gap-4">
              <div class="p-3 bg-white/20 rounded-lg">
                <.icon name="hero-plus-circle" class="h-8 w-8" />
              </div>
              <div>
                <h3 class="font-semibold text-lg">Nova Aula</h3>
                <p class="text-sm text-white/80">Enviar gravacao para analise</p>
              </div>
            </div>
          </div>
        </.link>

        <.link navigate={~p"/aulas"} class="block group">
          <div class="bg-white dark:bg-slate-800 rounded-xl p-6 border border-gray-200 dark:border-slate-700 hover:border-indigo-300 dark:hover:border-indigo-600 hover:shadow-md transition-all">
            <div class="flex items-center gap-4">
              <div class="p-3 bg-indigo-100 dark:bg-indigo-900/30 rounded-lg">
                <.icon name="hero-academic-cap" class="h-8 w-8 text-indigo-600 dark:text-indigo-400" />
              </div>
              <div>
                <h3 class="font-semibold text-lg text-gray-900 dark:text-white">Minhas Aulas</h3>
                <p class="text-sm text-gray-500 dark:text-gray-400">Ver todas as aulas</p>
              </div>
            </div>
          </div>
        </.link>

        <.async_result :let={data} assign={@stats}>
          <:loading>
            <div class="bg-white dark:bg-slate-800 rounded-xl p-6 border border-gray-200 dark:border-slate-700 animate-pulse">
              <div class="flex items-center gap-4">
                <div class="h-14 w-14 bg-gray-200 dark:bg-slate-700 rounded-lg"></div>
                <div class="space-y-2">
                  <div class="h-5 w-24 bg-gray-200 dark:bg-slate-700 rounded"></div>
                  <div class="h-4 w-16 bg-gray-200 dark:bg-slate-700 rounded"></div>
                </div>
              </div>
            </div>
          </:loading>
          <:failed>
            <div class="bg-white dark:bg-slate-800 rounded-xl p-6 border border-gray-200 dark:border-slate-700">
              <p class="text-gray-500">Erro ao carregar</p>
            </div>
          </:failed>

          <.link :if={data.pending > 0} navigate={~p"/aulas?status=pending"} class="block group">
            <div class="bg-white dark:bg-slate-800 rounded-xl p-6 border-2 border-yellow-300 dark:border-yellow-600 hover:shadow-md transition-all">
              <div class="flex items-center gap-4">
                <div class="p-3 bg-yellow-100 dark:bg-yellow-900/30 rounded-lg">
                  <.icon name="hero-clock" class="h-8 w-8 text-yellow-600 dark:text-yellow-400" />
                </div>
                <div>
                  <h3 class="font-semibold text-lg text-gray-900 dark:text-white">
                    <%= data.pending %> Pendentes
                  </h3>
                  <p class="text-sm text-gray-500 dark:text-gray-400">Aulas aguardando analise</p>
                </div>
              </div>
            </div>
          </.link>

          <div
            :if={data.pending == 0}
            class="bg-white dark:bg-slate-800 rounded-xl p-6 border border-gray-200 dark:border-slate-700"
          >
            <div class="flex items-center gap-4">
              <div class="p-3 bg-green-100 dark:bg-green-900/30 rounded-lg">
                <.icon name="hero-check-circle" class="h-8 w-8 text-green-600 dark:text-green-400" />
              </div>
              <div>
                <h3 class="font-semibold text-lg text-gray-900 dark:text-white">Tudo em dia!</h3>
                <p class="text-sm text-gray-500 dark:text-gray-400">Nenhuma aula pendente</p>
              </div>
            </div>
          </div>
        </.async_result>
      </div>
      <!-- Stats Overview -->
      <.async_result :let={data} assign={@stats}>
        <:loading>
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <.stat_skeleton :for={_ <- 1..4} />
          </div>
        </:loading>
        <:failed>
          <.alert variant="error">Erro ao carregar estatisticas</.alert>
        </:failed>

        <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.stat_card title="Total de Aulas" value={data.total} icon="hero-academic-cap" />
          <.stat_card
            title="Concluidas"
            value={data.completed}
            icon="hero-check-circle"
            variant="success"
          />
          <.stat_card
            title="Em Progresso"
            value={data.processing}
            icon="hero-arrow-path"
            variant="processing"
          />
          <.stat_card title="Pendentes" value={data.pending} icon="hero-clock" variant="pending" />
        </div>
      </.async_result>
      <!-- Recent Lessons -->
      <div>
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Aulas Recentes</h2>
          <.link
            navigate={~p"/aulas"}
            class="text-sm text-indigo-600 dark:text-indigo-400 hover:underline"
          >
            Ver todas
          </.link>
        </div>

        <div id="recent-lessons-container" phx-update="stream" class="space-y-3">
          <div :for={{dom_id, lesson} <- @streams.recent_lessons} id={dom_id}>
            <.lesson_card lesson={lesson} />
          </div>
        </div>

        <.empty_state
          :if={match?(%{ok?: true, result: %{total: 0}}, @stats)}
          icon="hero-document-text"
          title="Nenhuma aula ainda"
          description="Comece enviando sua primeira aula para analise."
        >
          <.link navigate={~p"/lessons/new"}>
            <.button>
              <.icon name="hero-plus" class="h-4 w-4 mr-2" /> Nova Aula
            </.button>
          </.link>
        </.empty_state>
      </div>
    </div>
    """
  end

  defp stat_skeleton(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6 animate-pulse">
      <div class="flex items-center justify-between">
        <div class="space-y-2">
          <div class="h-4 w-20 bg-gray-200 dark:bg-slate-700 rounded"></div>
          <div class="h-8 w-12 bg-gray-200 dark:bg-slate-700 rounded"></div>
        </div>
        <div class="h-12 w-12 bg-gray-200 dark:bg-slate-700 rounded-full"></div>
      </div>
    </div>
    """
  end
end
