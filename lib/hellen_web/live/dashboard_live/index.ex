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
     |> assign(lessons: lessons)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Minhas Aulas</h1>
          <p class="mt-1 text-sm text-gray-500">
            Gerencie suas aulas e veja os resultados das análises
          </p>
        </div>
        <.link navigate={~p"/lessons/new"}>
          <.button>
            <.icon name="hero-plus" class="h-4 w-4 mr-2" />
            Nova Aula
          </.button>
        </.link>
      </div>

      <div :if={@lessons == []} class="text-center py-12">
        <.icon name="hero-document-text" class="mx-auto h-12 w-12 text-gray-400" />
        <h3 class="mt-2 text-sm font-semibold text-gray-900">Nenhuma aula</h3>
        <p class="mt-1 text-sm text-gray-500">Comece enviando sua primeira aula para análise.</p>
        <div class="mt-6">
          <.link navigate={~p"/lessons/new"}>
            <.button>
              <.icon name="hero-plus" class="h-4 w-4 mr-2" />
              Nova Aula
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

    cond do
      minutes > 0 -> "#{minutes}min #{secs}s"
      true -> "#{secs}s"
    end
  end

  defp format_duration(_), do: "-"
end
