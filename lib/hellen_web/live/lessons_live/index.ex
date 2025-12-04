defmodule HellenWeb.LessonsLive.Index do
  @moduledoc """
  Lessons list LiveView with filters.
  Allows filtering by status, subject, and search.
  """
  use HellenWeb, :live_view

  alias Hellen.Lessons

  @statuses [
    {"all", "Todos"},
    {"pending", "Pendentes"},
    {"transcribing", "Transcrevendo"},
    {"analyzing", "Analisando"},
    {"completed", "Concluidas"},
    {"failed", "Com Erro"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(page_title: "Minhas Aulas")
     |> assign(statuses: @statuses)
     |> assign(filters: %{status: "all", subject: "all", search: ""})
     |> assign(subjects: [])
     |> assign(lessons_count: nil)
     |> stream(:lessons, [])
     |> load_subjects_async(user)
     |> load_lessons_async(user)}
  end

  defp load_subjects_async(socket, user) do
    if connected?(socket) and user.institution_id do
      start_async(socket, :load_subjects, fn ->
        Lessons.list_subjects(user.institution_id)
      end)
    else
      socket
    end
  end

  defp load_lessons_async(socket, user, filters \\ %{}) do
    if connected?(socket) do
      start_async(socket, :load_lessons, fn ->
        opts = build_filter_opts(filters, user)
        Lessons.list_lessons_by_user(user.id, opts)
      end)
    else
      socket
    end
  end

  defp build_filter_opts(filters, _user) do
    opts = [limit: 100]

    opts =
      case filters[:status] do
        nil -> opts
        "all" -> opts
        status -> Keyword.put(opts, :status, status)
      end

    case filters[:subject] do
      nil -> opts
      "all" -> opts
      subject -> Keyword.put(opts, :subject, subject)
    end
  end

  @impl true
  def handle_async(:load_lessons, {:ok, lessons}, socket) do
    # Apply client-side search filter
    search = socket.assigns.filters[:search] || ""

    filtered =
      if search != "" do
        search_lower = String.downcase(search)

        Enum.filter(lessons, fn l ->
          String.contains?(String.downcase(l.title || ""), search_lower) or
            String.contains?(String.downcase(l.subject || ""), search_lower)
        end)
      else
        lessons
      end

    {:noreply,
     socket
     |> assign(:lessons_count, length(filtered))
     |> stream(:lessons, filtered, reset: true)}
  end

  def handle_async(:load_lessons, {:exit, _reason}, socket) do
    {:noreply, put_flash(socket, :error, "Erro ao carregar aulas")}
  end

  def handle_async(:load_subjects, {:ok, subjects}, socket) do
    {:noreply, assign(socket, :subjects, subjects)}
  end

  def handle_async(:load_subjects, {:exit, _reason}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    user = socket.assigns.current_user
    filters = Map.put(socket.assigns.filters, :status, status)

    {:noreply,
     socket
     |> assign(filters: filters)
     |> load_lessons_async(user, filters)}
  end

  def handle_event("filter_subject", %{"subject" => subject}, socket) do
    user = socket.assigns.current_user
    filters = Map.put(socket.assigns.filters, :subject, subject)

    {:noreply,
     socket
     |> assign(filters: filters)
     |> load_lessons_async(user, filters)}
  end

  def handle_event("search", %{"search" => search}, socket) do
    user = socket.assigns.current_user
    filters = Map.put(socket.assigns.filters, :search, search)

    {:noreply,
     socket
     |> assign(filters: filters)
     |> load_lessons_async(user, filters)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.page_header title="Minhas Aulas" description="Todas as suas aulas e analises">
        <:actions>
          <.link navigate={~p"/lessons/new"}>
            <.button>
              <.icon name="hero-plus" class="h-4 w-4 mr-2" /> Nova Aula
            </.button>
          </.link>
        </:actions>
      </.page_header>
      <!-- Filters -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-4">
        <div class="flex flex-wrap gap-4 items-center">
          <!-- Search -->
          <div class="flex-1 min-w-[200px]">
            <form phx-change="search" phx-submit="search">
              <div class="relative">
                <.icon
                  name="hero-magnifying-glass"
                  class="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400"
                />
                <input
                  type="text"
                  name="search"
                  value={@filters[:search]}
                  placeholder="Buscar aulas..."
                  phx-debounce="300"
                  class="w-full pl-10 pr-4 py-2 rounded-lg border border-gray-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-gray-900 dark:text-white placeholder-gray-500 dark:placeholder-gray-400 focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                />
              </div>
            </form>
          </div>
          <!-- Status Filter -->
          <div class="flex items-center gap-2">
            <span class="text-sm text-gray-500 dark:text-gray-400">Status:</span>
            <div class="flex gap-1 flex-wrap">
              <button
                :for={{value, label} <- @statuses}
                type="button"
                phx-click="filter"
                phx-value-status={value}
                class={[
                  "px-3 py-1.5 text-sm rounded-lg transition-colors",
                  @filters[:status] == value &&
                    "bg-indigo-100 dark:bg-indigo-900/50 text-indigo-700 dark:text-indigo-300 font-medium",
                  @filters[:status] != value &&
                    "bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-slate-600"
                ]}
              >
                <%= label %>
              </button>
            </div>
          </div>
          <!-- Subject Filter (if subjects exist) -->
          <div :if={@subjects != []} class="flex items-center gap-2">
            <span class="text-sm text-gray-500 dark:text-gray-400">Disciplina:</span>
            <select
              phx-change="filter_subject"
              name="subject"
              class="rounded-lg border border-gray-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-gray-900 dark:text-white text-sm py-1.5 px-3 focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
            >
              <option value="all" selected={@filters[:subject] == "all"}>Todas</option>
              <option
                :for={subject <- @subjects}
                value={subject}
                selected={@filters[:subject] == subject}
              >
                <%= subject %>
              </option>
            </select>
          </div>
        </div>
      </div>
      <!-- Lessons Grid -->
      <div id="lessons-container" phx-update="stream" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div :for={{dom_id, lesson} <- @streams.lessons} id={dom_id}>
          <.lesson_card lesson={lesson} />
        </div>
      </div>
      <!-- Empty State -->
      <div :if={@lessons_count == 0} id="empty-state" class="text-center py-12">
        <.icon name="hero-document-text" class="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500" />
        <h3 class="mt-2 text-sm font-semibold text-gray-900 dark:text-white">
          Nenhuma aula encontrada
        </h3>
        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
          <%= if @filters[:search] != "" or @filters[:status] != "all" do %>
            Tente ajustar os filtros ou buscar por outro termo.
          <% else %>
            Comece enviando sua primeira aula para analise.
          <% end %>
        </p>
        <div class="mt-6">
          <.link navigate={~p"/lessons/new"}>
            <.button>
              <.icon name="hero-plus" class="h-4 w-4 mr-2" /> Nova Aula
            </.button>
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
