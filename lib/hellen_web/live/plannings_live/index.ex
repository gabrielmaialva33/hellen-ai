defmodule HellenWeb.PlanningsLive.Index do
  @moduledoc """
  LiveView for listing and managing lesson plannings.
  """

  use HellenWeb, :live_view

  alias Hellen.Plannings
  alias Hellen.Plannings.Planning

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Planejamentos")
     |> assign(:filter_status, nil)
     |> assign(:filter_subject, nil)
     |> assign(:search_query, "")
     |> assign(:view_mode, "cards")
     |> load_plannings()
     |> load_stats()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status = if status == "", do: nil, else: status

    {:noreply,
     socket
     |> assign(:filter_status, status)
     |> load_plannings()}
  end

  @impl true
  def handle_event("filter_subject", %{"subject" => subject}, socket) do
    subject = if subject == "", do: nil, else: subject

    {:noreply,
     socket
     |> assign(:filter_subject, subject)
     |> load_plannings()}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_plannings()}
  end

  @impl true
  def handle_event("toggle_view", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, mode)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    planning = Plannings.get_planning!(id)

    case Plannings.delete_planning(planning) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Planejamento excluído com sucesso!")
         |> load_plannings()
         |> load_stats()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao excluir planejamento")}
    end
  end

  @impl true
  def handle_event("duplicate", %{"id" => id}, socket) do
    planning = Plannings.get_planning!(id)

    case Plannings.duplicate_planning(planning, %{user_id: socket.assigns.current_user.id}) do
      {:ok, new_planning} ->
        {:noreply,
         socket
         |> put_flash(:info, "Planejamento duplicado: #{new_planning.title}")
         |> load_plannings()
         |> load_stats()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao duplicar planejamento")}
    end
  end

  @impl true
  def handle_event("publish", %{"id" => id}, socket) do
    planning = Plannings.get_planning!(id)

    case Plannings.publish_planning(planning) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Planejamento publicado!")
         |> load_plannings()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao publicar")}
    end
  end

  @impl true
  def handle_event("archive", %{"id" => id}, socket) do
    planning = Plannings.get_planning!(id)

    case Plannings.archive_planning(planning) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Planejamento arquivado!")
         |> load_plannings()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao arquivar")}
    end
  end

  defp load_plannings(socket) do
    user = socket.assigns.current_user

    opts =
      []
      |> maybe_add_filter(:status, socket.assigns.filter_status)
      |> maybe_add_filter(:subject, socket.assigns.filter_subject)
      |> maybe_add_filter(:search, socket.assigns.search_query)

    plannings = Plannings.list_plannings(user.id, opts)
    assign(socket, :plannings, plannings)
  end

  defp load_stats(socket) do
    user = socket.assigns.current_user

    stats = %{
      total: Plannings.count_total(user.id),
      by_status: Plannings.count_by_status(user.id),
      by_subject: Plannings.count_by_subject(user.id)
    }

    assign(socket, :stats, stats)
  end

  defp maybe_add_filter(opts, _key, nil), do: opts
  defp maybe_add_filter(opts, _key, ""), do: opts
  defp maybe_add_filter(opts, key, value), do: Keyword.put(opts, key, value)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50 dark:bg-slate-900">
      <!-- Header -->
      <div class="bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <h1 class="text-2xl font-bold text-slate-900 dark:text-white">
                Planejamentos
              </h1>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                Gerencie seus planos de aula
              </p>
            </div>

            <.link
              navigate={~p"/plannings/new"}
              class="inline-flex items-center gap-2 px-4 py-2.5 bg-teal-600 hover:bg-teal-700 text-white font-medium rounded-xl transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 4v16m8-8H4"
                />
              </svg>
              Novo Planejamento
            </.link>
          </div>
        </div>
      </div>
      <!-- Stats Cards -->
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <div class="flex items-center gap-3">
              <div class="p-2 bg-teal-100 dark:bg-teal-900/30 rounded-lg">
                <svg
                  class="w-5 h-5 text-teal-600 dark:text-teal-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                  />
                </svg>
              </div>
              <div>
                <p class="text-2xl font-bold text-slate-900 dark:text-white"><%= @stats.total %></p>
                <p class="text-xs text-slate-500 dark:text-slate-400">Total</p>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <div class="flex items-center gap-3">
              <div class="p-2 bg-amber-100 dark:bg-amber-900/30 rounded-lg">
                <svg
                  class="w-5 h-5 text-amber-600 dark:text-amber-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                  />
                </svg>
              </div>
              <div>
                <p class="text-2xl font-bold text-slate-900 dark:text-white">
                  <%= Map.get(@stats.by_status, "draft", 0) %>
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">Rascunhos</p>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <div class="flex items-center gap-3">
              <div class="p-2 bg-emerald-100 dark:bg-emerald-900/30 rounded-lg">
                <svg
                  class="w-5 h-5 text-emerald-600 dark:text-emerald-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>
              <div>
                <p class="text-2xl font-bold text-slate-900 dark:text-white">
                  <%= Map.get(@stats.by_status, "published", 0) %>
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">Publicados</p>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <div class="flex items-center gap-3">
              <div class="p-2 bg-slate-100 dark:bg-slate-700 rounded-lg">
                <svg
                  class="w-5 h-5 text-slate-600 dark:text-slate-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4"
                  />
                </svg>
              </div>
              <div>
                <p class="text-2xl font-bold text-slate-900 dark:text-white">
                  <%= Map.get(@stats.by_status, "archived", 0) %>
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">Arquivados</p>
              </div>
            </div>
          </div>
        </div>
      </div>
      <!-- Filters -->
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4">
          <div class="flex flex-col sm:flex-row gap-4">
            <!-- Search -->
            <div class="flex-1">
              <form phx-change="search" phx-submit="search">
                <div class="relative">
                  <svg
                    class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                    />
                  </svg>
                  <input
                    type="text"
                    name="search[query]"
                    value={@search_query}
                    placeholder="Buscar planejamentos..."
                    class="w-full pl-10 pr-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
                    phx-debounce="300"
                  />
                </div>
              </form>
            </div>
            <!-- Status Filter -->
            <div>
              <select
                phx-change="filter_status"
                name="status"
                class="px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                <option value="">Todos os status</option>
                <option value="draft" selected={@filter_status == "draft"}>Rascunhos</option>
                <option value="published" selected={@filter_status == "published"}>Publicados</option>
                <option value="archived" selected={@filter_status == "archived"}>Arquivados</option>
              </select>
            </div>
            <!-- Subject Filter -->
            <div>
              <select
                phx-change="filter_subject"
                name="subject"
                class="px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                <option value="">Todas as disciplinas</option>
                <%= for subject <- Planning.subjects() do %>
                  <option value={subject} selected={@filter_subject == subject}>
                    <%= Planning.subject_label(subject) %>
                  </option>
                <% end %>
              </select>
            </div>
            <!-- View Toggle -->
            <div class="flex items-center gap-1 bg-slate-100 dark:bg-slate-700 rounded-lg p-1">
              <button
                phx-click="toggle_view"
                phx-value-mode="cards"
                class={"px-3 py-1.5 rounded-md text-sm font-medium transition-colors #{if @view_mode == "cards", do: "bg-white dark:bg-slate-600 text-slate-900 dark:text-white shadow-sm", else: "text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300"}"}
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"
                  />
                </svg>
              </button>
              <button
                phx-click="toggle_view"
                phx-value-mode="table"
                class={"px-3 py-1.5 rounded-md text-sm font-medium transition-colors #{if @view_mode == "table", do: "bg-white dark:bg-slate-600 text-slate-900 dark:text-white shadow-sm", else: "text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300"}"}
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 6h16M4 10h16M4 14h16M4 18h16"
                  />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
      <!-- Plannings List -->
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <%= if Enum.empty?(@plannings) do %>
          <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-12 text-center">
            <svg
              class="mx-auto w-16 h-16 text-slate-300 dark:text-slate-600"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="1.5"
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
            <h3 class="mt-4 text-lg font-medium text-slate-900 dark:text-white">
              Nenhum planejamento encontrado
            </h3>
            <p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
              Comece criando seu primeiro plano de aula
            </p>
            <.link
              navigate={~p"/plannings/new"}
              class="mt-4 inline-flex items-center gap-2 px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white font-medium rounded-lg transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 4v16m8-8H4"
                />
              </svg>
              Criar Planejamento
            </.link>
          </div>
        <% else %>
          <%= if @view_mode == "cards" do %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for planning <- @plannings do %>
                <.planning_card planning={planning} />
              <% end %>
            </div>
          <% else %>
            <.planning_table plannings={@plannings} />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp planning_card(assigns) do
    ~H"""
    <div class="group bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-5 hover:shadow-lg hover:-translate-y-0.5 transition-all duration-200">
      <div class="flex items-start justify-between">
        <.status_badge status={@planning.status} />
        <div class="relative">
          <button
            phx-click={JS.toggle(to: "#menu-#{@planning.id}")}
            class="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"
              />
            </svg>
          </button>
          <div
            id={"menu-#{@planning.id}"}
            class="hidden absolute right-0 mt-1 w-48 bg-white dark:bg-slate-700 rounded-lg shadow-lg border border-slate-200 dark:border-slate-600 py-1 z-10"
          >
            <.link
              navigate={~p"/plannings/#{@planning.id}"}
              class="flex items-center gap-2 px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-600"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                />
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                />
              </svg>
              Ver Detalhes
            </.link>
            <.link
              navigate={~p"/plannings/#{@planning.id}/edit"}
              class="flex items-center gap-2 px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-600"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                />
              </svg>
              Editar
            </.link>
            <button
              phx-click="duplicate"
              phx-value-id={@planning.id}
              class="flex items-center gap-2 w-full px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-600"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                />
              </svg>
              Duplicar
            </button>
            <%= if @planning.status == "draft" do %>
              <button
                phx-click="publish"
                phx-value-id={@planning.id}
                class="flex items-center gap-2 w-full px-4 py-2 text-sm text-emerald-600 dark:text-emerald-400 hover:bg-slate-100 dark:hover:bg-slate-600"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                Publicar
              </button>
            <% end %>
            <%= if @planning.status != "archived" do %>
              <button
                phx-click="archive"
                phx-value-id={@planning.id}
                class="flex items-center gap-2 w-full px-4 py-2 text-sm text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-600"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4"
                  />
                </svg>
                Arquivar
              </button>
            <% end %>
            <hr class="my-1 border-slate-200 dark:border-slate-600" />
            <button
              phx-click="delete"
              phx-value-id={@planning.id}
              data-confirm="Tem certeza que deseja excluir este planejamento?"
              class="flex items-center gap-2 w-full px-4 py-2 text-sm text-red-600 dark:text-red-400 hover:bg-slate-100 dark:hover:bg-slate-600"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                />
              </svg>
              Excluir
            </button>
          </div>
        </div>
      </div>

      <.link navigate={~p"/plannings/#{@planning.id}"} class="block mt-4">
        <h3 class="text-lg font-semibold text-slate-900 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors line-clamp-2">
          <%= @planning.title %>
        </h3>
      </.link>

      <div class="mt-2 flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
        <span class="px-2 py-0.5 bg-slate-100 dark:bg-slate-700 rounded-md">
          <%= Planning.subject_label(@planning.subject) %>
        </span>
        <span>•</span>
        <span><%= Planning.grade_level_label(@planning.grade_level) %></span>
      </div>

      <%= if @planning.description do %>
        <p class="mt-3 text-sm text-slate-600 dark:text-slate-300 line-clamp-2">
          <%= @planning.description %>
        </p>
      <% end %>

      <div class="mt-4 flex items-center justify-between text-xs text-slate-400 dark:text-slate-500">
        <div class="flex items-center gap-1">
          <%= if @planning.generated_by_ai do %>
            <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-violet-100 dark:bg-violet-900/30 text-violet-600 dark:text-violet-400 rounded-full">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 10V3L4 14h7v7l9-11h-7z"
                />
              </svg>
              IA
            </span>
          <% end %>
          <%= if length(@planning.bncc_codes || []) > 0 do %>
            <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-teal-100 dark:bg-teal-900/30 text-teal-600 dark:text-teal-400 rounded-full">
              BNCC: <%= length(@planning.bncc_codes) %>
            </span>
          <% end %>
        </div>
        <span><%= Calendar.strftime(@planning.inserted_at, "%d/%m/%Y") %></span>
      </div>
    </div>
    """
  end

  defp planning_table(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden">
      <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-700">
        <thead class="bg-slate-50 dark:bg-slate-800">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Planejamento
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Disciplina / Ano
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Status
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              BNCC
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Data
            </th>
            <th class="px-6 py-3 text-right text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Ações
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-200 dark:divide-slate-700">
          <%= for planning <- @plannings do %>
            <tr class="hover:bg-slate-50 dark:hover:bg-slate-700/50">
              <td class="px-6 py-4">
                <.link navigate={~p"/plannings/#{planning.id}"} class="block">
                  <div class="font-medium text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400">
                    <%= planning.title %>
                  </div>
                  <%= if planning.generated_by_ai do %>
                    <span class="inline-flex items-center gap-1 text-xs text-violet-600 dark:text-violet-400">
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M13 10V3L4 14h7v7l9-11h-7z"
                        />
                      </svg>
                      Gerado por IA
                    </span>
                  <% end %>
                </.link>
              </td>
              <td class="px-6 py-4 text-sm text-slate-500 dark:text-slate-400">
                <div><%= Planning.subject_label(planning.subject) %></div>
                <div class="text-xs"><%= Planning.grade_level_label(planning.grade_level) %></div>
              </td>
              <td class="px-6 py-4">
                <.status_badge status={planning.status} />
              </td>
              <td class="px-6 py-4 text-sm text-slate-500 dark:text-slate-400">
                <%= length(planning.bncc_codes || []) %> códigos
              </td>
              <td class="px-6 py-4 text-sm text-slate-500 dark:text-slate-400">
                <%= Calendar.strftime(planning.inserted_at, "%d/%m/%Y") %>
              </td>
              <td class="px-6 py-4 text-right">
                <.link
                  navigate={~p"/plannings/#{planning.id}"}
                  class="text-teal-600 dark:text-teal-400 hover:text-teal-800 dark:hover:text-teal-300 font-medium text-sm"
                >
                  Ver
                </.link>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp status_badge(assigns) do
    {bg, text} =
      case assigns.status do
        "draft" ->
          {"bg-amber-100 dark:bg-amber-900/30", "text-amber-700 dark:text-amber-400"}

        "published" ->
          {"bg-emerald-100 dark:bg-emerald-900/30", "text-emerald-700 dark:text-emerald-400"}

        "archived" ->
          {"bg-slate-100 dark:bg-slate-700", "text-slate-600 dark:text-slate-400"}

        _ ->
          {"bg-slate-100 dark:bg-slate-700", "text-slate-600 dark:text-slate-400"}
      end

    assigns = assign(assigns, :bg, bg)
    assigns = assign(assigns, :text, text)

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@bg} #{@text}"}>
      <%= Planning.status_label(@status) %>
    </span>
    """
  end
end
