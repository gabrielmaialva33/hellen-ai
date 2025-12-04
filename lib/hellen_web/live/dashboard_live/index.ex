defmodule HellenWeb.DashboardLive.Index do
  use HellenWeb, :live_view

  alias Hellen.Lessons

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    lessons = Lessons.list_lessons_by_user(user.id)

    {:ok,
     socket
     |> assign(page_title: "Dashboard")
     |> assign(lessons: lessons)
     |> assign(stats: compute_stats(lessons))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">Minhas Aulas</h1>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
            Gerencie suas aulas e veja os resultados das análises
          </p>
        </div>
        <.link navigate={~p"/lessons/new"}>
          <.button>
            <.icon name="hero-plus" class="h-4 w-4 mr-2" /> Nova Aula
          </.button>
        </.link>
      </div>

      <div :if={@lessons != []} class="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <.stat_card title="Total de Aulas" value={@stats.total} icon="hero-academic-cap" />
        <.stat_card
          title="Concluídas"
          value={@stats.completed}
          icon="hero-check-circle"
          variant="success"
        />
        <.stat_card
          title="Em Progresso"
          value={@stats.processing}
          icon="hero-arrow-path"
          variant="processing"
        />
        <.stat_card title="Pendentes" value={@stats.pending} icon="hero-clock" variant="pending" />
      </div>

      <div :if={@lessons != [] && @stats.has_charts} class="grid gap-6 lg:grid-cols-2">
        <.card>
          <:header>
            <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
              Status das Aulas
            </h2>
          </:header>
          <.chart
            id="status-breakdown"
            type="donut"
            series={[@stats.completed, @stats.processing, @stats.pending, @stats.failed]}
            labels={["Concluídas", "Em Progresso", "Pendentes", "Falhadas"]}
            colors={["#22c55e", "#3b82f6", "#eab308", "#ef4444"]}
            height="300"
          />
        </.card>

        <.card>
          <:header>
            <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100">Últimas Aulas</h2>
          </:header>
          <.trend_chart
            id="recent-lessons"
            categories={@stats.recent_dates}
            data={@stats.recent_counts}
            label="Aulas"
            height="300"
          />
        </.card>
      </div>

      <div :if={@lessons == []} class="text-center py-12">
        <.icon name="hero-document-text" class="mx-auto h-12 w-12 text-gray-400" />
        <h3 class="mt-2 text-sm font-semibold text-gray-900">Nenhuma aula</h3>
        <p class="mt-1 text-sm text-gray-500">Comece enviando sua primeira aula para análise.</p>
        <div class="mt-6">
          <.link navigate={~p"/lessons/new"}>
            <.button>
              <.icon name="hero-plus" class="h-4 w-4 mr-2" /> Nova Aula
            </.button>
          </.link>
        </div>
      </div>

      <div :if={@lessons != []} class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <.lesson_card :for={lesson <- @lessons} lesson={lesson} />
      </div>
    </div>
    """
  end

  defp lesson_card(assigns) do
    ~H"""
    <.link navigate={~p"/lessons/#{@lesson.id}"} class="block">
      <.card class="hover:shadow-md transition-shadow">
        <div class="flex justify-between items-start">
          <div class="flex-1 min-w-0">
            <h3 class="text-base font-semibold text-gray-900 truncate">
              <%= @lesson.title || "Aula sem título" %>
            </h3>
            <p class="mt-1 text-sm text-gray-500 truncate">
              <%= @lesson.subject || "Disciplina não informada" %>
            </p>
          </div>
          <.badge variant={status_variant(@lesson.status)}>
            <%= status_label(@lesson.status) %>
          </.badge>
        </div>

        <div class="mt-4 flex items-center text-xs text-gray-500">
          <.icon name="hero-calendar-mini" class="h-4 w-4 mr-1" />
          <%= format_date(@lesson.inserted_at) %>

          <span :if={@lesson.duration_seconds} class="ml-4 flex items-center">
            <.icon name="hero-clock-mini" class="h-4 w-4 mr-1" />
            <%= format_duration(@lesson.duration_seconds) %>
          </span>
        </div>
      </.card>
    </.link>
    """
  end

  defp status_variant("pending"), do: "pending"
  defp status_variant("transcribing"), do: "processing"
  defp status_variant("transcribed"), do: "processing"
  defp status_variant("analyzing"), do: "processing"
  defp status_variant("completed"), do: "completed"
  defp status_variant("failed"), do: "failed"
  defp status_variant(_), do: "default"

  defp status_label("pending"), do: "Pendente"
  defp status_label("transcribing"), do: "Transcrevendo"
  defp status_label("transcribed"), do: "Analisando"
  defp status_label("analyzing"), do: "Analisando"
  defp status_label("completed"), do: "Concluído"
  defp status_label("failed"), do: "Falhou"
  defp status_label(_), do: "Desconhecido"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y")
  end

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    if minutes > 0, do: "#{minutes}min #{secs}s", else: "#{secs}s"
  end

  defp format_duration(_), do: "-"

  defp stat_card(assigns) do
    assigns = assign_new(assigns, :variant, fn -> "default" end)

    ~H"""
    <.card class={stat_card_class(@variant)}>
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm font-medium text-gray-600 dark:text-gray-400"><%= @title %></p>
          <p class="mt-1 text-3xl font-semibold text-gray-900 dark:text-gray-100">
            <%= @value %>
          </p>
        </div>
        <div class={stat_icon_class(@variant)}>
          <.icon name={@icon} class="h-8 w-8" />
        </div>
      </div>
    </.card>
    """
  end

  defp stat_card_class("success"), do: "border-l-4 border-green-500"
  defp stat_card_class("processing"), do: "border-l-4 border-blue-500"
  defp stat_card_class("pending"), do: "border-l-4 border-yellow-500"
  defp stat_card_class(_), do: "border-l-4 border-indigo-500"

  defp stat_icon_class("success"), do: "text-green-500"
  defp stat_icon_class("processing"), do: "text-blue-500"
  defp stat_icon_class("pending"), do: "text-yellow-500"
  defp stat_icon_class(_), do: "text-indigo-500"

  defp compute_stats(lessons) do
    total = length(lessons)
    completed = Enum.count(lessons, &(&1.status == "completed"))
    processing = Enum.count(lessons, &(&1.status in ["transcribing", "analyzing", "transcribed"]))
    pending = Enum.count(lessons, &(&1.status == "pending"))
    failed = Enum.count(lessons, &(&1.status == "failed"))

    # Get last 7 days of lesson counts for trend chart
    {recent_dates, recent_counts} = compute_recent_trend(lessons)

    %{
      total: total,
      completed: completed,
      processing: processing,
      pending: pending,
      failed: failed,
      has_charts: total > 0,
      recent_dates: recent_dates,
      recent_counts: recent_counts
    }
  end

  defp compute_recent_trend(lessons) do
    today = Date.utc_today()

    # Create a map of dates to counts for the last 7 days
    date_counts =
      lessons
      |> Enum.map(fn lesson ->
        DateTime.to_date(lesson.inserted_at)
      end)
      |> Enum.frequencies()

    # Generate last 7 days
    dates =
      Enum.map(6..0//-1, fn days_ago ->
        Date.add(today, -days_ago)
      end)

    # Get counts for each day
    counts =
      Enum.map(dates, fn date ->
        Map.get(date_counts, date, 0)
      end)

    # Format dates for display (day/month)
    formatted_dates =
      Enum.map(dates, fn date ->
        Calendar.strftime(date, "%d/%m")
      end)

    {formatted_dates, counts}
  end
end
