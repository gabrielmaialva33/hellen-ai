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

  # PWA OfflineIndicator hook events - ignore silently
  @impl true
  def handle_event("online", _params, socket), do: {:noreply, socket}
  def handle_event("offline", _params, socket), do: {:noreply, socket}

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
    <div class="space-y-6 animate-fade-in">
      <!-- Page Header -->
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900 dark:text-white tracking-tight">
            Minhas Aulas
          </h1>
          <p class="mt-1 text-slate-500 dark:text-slate-400">
            Todas as suas aulas e analises pedagogicas
          </p>
        </div>
        <.link navigate={~p"/lessons/new"}>
          <.button icon="hero-plus">
            Nova Aula
          </.button>
        </.link>
      </div>

      <!-- Stats Summary -->
      <div :if={@lessons_count} class="flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
        <.icon name="hero-document-text" class="h-4 w-4" />
        <span><%= @lessons_count %> aula<%= if @lessons_count != 1, do: "s" %> encontrada<%= if @lessons_count != 1, do: "s" %></span>
      </div>

      <!-- Filters Card -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-card border border-slate-200/50 dark:border-slate-700/50 p-5">
        <div class="flex flex-wrap gap-4 items-center">
          <!-- Search -->
          <div class="flex-1 min-w-[200px]">
            <form phx-change="search" phx-submit="search">
              <div class="relative">
                <.icon
                  name="hero-magnifying-glass"
                  class="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-400"
                />
                <input
                  type="text"
                  name="search"
                  value={@filters[:search]}
                  placeholder="Buscar por titulo ou disciplina..."
                  phx-debounce="300"
                  class="w-full pl-10 pr-4 py-2.5 rounded-xl border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-700/50 text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-all duration-200"
                />
              </div>
            </form>
          </div>

          <!-- Status Filter -->
          <div class="flex items-center gap-3">
            <span class="text-sm font-medium text-slate-500 dark:text-slate-400">Status:</span>
            <div class="flex gap-1.5 flex-wrap">
              <button
                :for={{value, label} <- @statuses}
                type="button"
                phx-click="filter"
                phx-value-status={value}
                class={[
                  "px-3 py-1.5 text-sm rounded-lg transition-all duration-200",
                  @filters[:status] == value &&
                    "bg-teal-500 text-white shadow-sm",
                  @filters[:status] != value &&
                    "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-600"
                ]}
              >
                <%= label %>
              </button>
            </div>
          </div>

          <!-- Subject Filter (if subjects exist) -->
          <div :if={@subjects != []} class="flex items-center gap-3">
            <span class="text-sm font-medium text-slate-500 dark:text-slate-400">Disciplina:</span>
            <select
              phx-change="filter_subject"
              name="subject"
              class="rounded-xl border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-700/50 text-slate-900 dark:text-white text-sm py-2 px-3 focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-all duration-200"
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
        <div
          :for={{dom_id, lesson} <- @streams.lessons}
          id={dom_id}
          class="animate-fade-in-up"
        >
          <.lesson_card lesson={lesson} />
        </div>
      </div>

      <!-- Empty State -->
      <.empty_state
        :if={@lessons_count == 0}
        icon="hero-document-text"
        title="Nenhuma aula encontrada"
        description={empty_state_description(@filters)}
      >
        <.link navigate={~p"/lessons/new"}>
          <.button icon="hero-plus">
            Nova Aula
          </.button>
        </.link>
      </.empty_state>
    </div>
    """
  end

  defp empty_state_description(filters) do
    if filters[:search] != "" or filters[:status] != "all" do
      "Tente ajustar os filtros ou buscar por outro termo."
    else
      "Comece enviando sua primeira aula para analise pedagogica com IA."
    end
  end
end
