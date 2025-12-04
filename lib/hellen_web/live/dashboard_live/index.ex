defmodule HellenWeb.DashboardLive.Index do
  @moduledoc """
  Dashboard LiveView using LiveView 1.1 patterns:
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
     |> assign(page_title: "Dashboard")
     |> stream(:lessons, [])
     |> assign_async(:stats, fn -> load_stats(user.id) end)
     |> load_lessons_async(user.id)}
  end

  # Load lessons into stream asynchronously
  defp load_lessons_async(socket, user_id) do
    if connected?(socket) do
      start_async(socket, :load_lessons, fn ->
        Lessons.list_lessons_by_user(user_id)
      end)
    else
      socket
    end
  end

  @impl true
  def handle_async(:load_lessons, {:ok, lessons}, socket) do
    {:noreply, stream(socket, :lessons, lessons)}
  end

  def handle_async(:load_lessons, {:exit, _reason}, socket) do
    {:noreply, put_flash(socket, :error, "Erro ao carregar aulas")}
  end

  # Stats computation runs in background
  defp load_stats(user_id) do
    lessons = Lessons.list_lessons_by_user(user_id)

    stats = %{
      total: length(lessons),
      completed: Enum.count(lessons, &(&1.status == "completed")),
      processing: Enum.count(lessons, &(&1.status in ["transcribing", "analyzing", "transcribed"])),
      pending: Enum.count(lessons, &(&1.status == "pending"))
    }

    {:ok, %{stats: stats}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.page_header title="Minhas Aulas" description="Gerencie suas aulas e veja os resultados das análises">
        <:actions>
          <.link navigate={~p"/lessons/new"}>
            <.button>
              <.icon name="hero-plus" class="h-4 w-4 mr-2" /> Nova Aula
            </.button>
          </.link>
        </:actions>
      </.page_header>

      <%!-- Stats com assign_async --%>
      <.async_result :let={data} assign={@stats}>
        <:loading>
          <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            <.stat_skeleton :for={_ <- 1..4} />
          </div>
        </:loading>
        <:failed>
          <.alert variant="error">Erro ao carregar estatísticas</.alert>
        </:failed>

        <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          <.stat_card title="Total de Aulas" value={data.stats.total} icon="hero-academic-cap" />
          <.stat_card
            title="Concluídas"
            value={data.stats.completed}
            icon="hero-check-circle"
            variant="success"
          />
          <.stat_card
            title="Em Progresso"
            value={data.stats.processing}
            icon="hero-arrow-path"
            variant="processing"
          />
          <.stat_card
            title="Pendentes"
            value={data.stats.pending}
            icon="hero-clock"
            variant="pending"
          />
        </div>
      </.async_result>

      <%!-- Lessons com streams --%>
      <div id="lessons-container" phx-update="stream">
        <div
          :for={{dom_id, lesson} <- @streams.lessons}
          id={dom_id}
          class="mb-4"
        >
          <.lesson_card lesson={lesson} />
        </div>
      </div>

      <%!-- Empty state (mostrar apenas se stats carregou e total = 0) --%>
      <.empty_state
        :if={match?(%{ok?: true, result: %{stats: %{total: 0}}}, @stats)}
        icon="hero-document-text"
        title="Nenhuma aula"
        description="Comece enviando sua primeira aula para análise."
      >
        <.link navigate={~p"/lessons/new"}>
          <.button>
            <.icon name="hero-plus" class="h-4 w-4 mr-2" /> Nova Aula
          </.button>
        </.link>
      </.empty_state>
    </div>
    """
  end

  # Skeleton loader para stats
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
