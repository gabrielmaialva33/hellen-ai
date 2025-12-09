defmodule HellenWeb.AssessmentsLive.Index do
  @moduledoc """
  LiveView for listing and managing assessments.
  """

  use HellenWeb, :live_view

  alias Hellen.Assessments
  alias Hellen.Assessments.Assessment

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Avaliações")
     |> assign(:filter_status, nil)
     |> assign(:filter_subject, nil)
     |> assign(:filter_type, nil)
     |> assign(:search_query, "")
     |> assign(:view_mode, "cards")
     |> load_assessments()
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
     |> load_assessments()}
  end

  @impl true
  def handle_event("filter_subject", %{"subject" => subject}, socket) do
    subject = if subject == "", do: nil, else: subject

    {:noreply,
     socket
     |> assign(:filter_subject, subject)
     |> load_assessments()}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    type = if type == "", do: nil, else: type

    {:noreply,
     socket
     |> assign(:filter_type, type)
     |> load_assessments()}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_assessments()}
  end

  @impl true
  def handle_event("toggle_view", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, mode)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    assessment = Assessments.get_assessment!(id)

    case Assessments.delete_assessment(assessment) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Avaliação excluída com sucesso!")
         |> load_assessments()
         |> load_stats()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao excluir avaliação")}
    end
  end

  @impl true
  def handle_event("duplicate", %{"id" => id}, socket) do
    assessment = Assessments.get_assessment!(id)
    user_id = socket.assigns.current_user.id

    case Assessments.duplicate_assessment(assessment, user_id) do
      {:ok, new_assessment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Avaliação duplicada!")
         |> push_navigate(to: ~p"/assessments/#{new_assessment.id}/edit")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao duplicar avaliação")}
    end
  end

  @impl true
  def handle_event("publish", %{"id" => id}, socket) do
    assessment = Assessments.get_assessment!(id)

    case Assessments.publish_assessment(assessment) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Avaliação publicada!")
         |> load_assessments()
         |> load_stats()}

      {:error, changeset} ->
        error_msg = error_message(changeset)
        {:noreply, put_flash(socket, :error, error_msg)}
    end
  end

  @impl true
  def handle_event("archive", %{"id" => id}, socket) do
    assessment = Assessments.get_assessment!(id)

    case Assessments.archive_assessment(assessment) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Avaliação arquivada!")
         |> load_assessments()
         |> load_stats()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao arquivar avaliação")}
    end
  end

  defp load_assessments(socket) do
    user_id = socket.assigns.current_user.id

    filters =
      [
        status: socket.assigns.filter_status,
        subject: socket.assigns.filter_subject,
        assessment_type: socket.assigns.filter_type,
        search: socket.assigns.search_query
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)

    assessments = Assessments.list_assessments(user_id, filters)
    assign(socket, :assessments, assessments)
  end

  defp load_stats(socket) do
    user_id = socket.assigns.current_user.id
    stats = Assessments.get_stats(user_id)
    assign(socket, :stats, stats)
  end

  defp error_message(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50 dark:bg-slate-900">
      <!-- Header -->
      <div class="bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <h1 class="text-2xl font-bold text-slate-900 dark:text-white">Avaliações</h1>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                Gerencie suas provas, atividades e avaliações
              </p>
            </div>
            <.link
              navigate={~p"/assessments/new"}
              class="inline-flex items-center gap-2 px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white font-medium rounded-lg transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 4v16m8-8H4"
                />
              </svg>
              Nova Avaliação
            </.link>
          </div>
        </div>
      </div>
      <!-- Stats Cards -->
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
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
                    d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
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
                  <%= @stats.by_status["draft"] || 0 %>
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
                  <%= @stats.by_status["published"] || 0 %>
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">Publicadas</p>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <div class="flex items-center gap-3">
              <div class="p-2 bg-violet-100 dark:bg-violet-900/30 rounded-lg">
                <svg
                  class="w-5 h-5 text-violet-600 dark:text-violet-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>
              <div>
                <p class="text-2xl font-bold text-slate-900 dark:text-white">
                  <%= @stats.total_questions %>
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">Questões</p>
              </div>
            </div>
          </div>
        </div>
        <!-- Filters -->
        <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700 mb-6">
          <div class="flex flex-wrap items-center gap-4">
            <div class="flex-1 min-w-[200px]">
              <form phx-change="search" phx-submit="search">
                <div class="relative">
                  <svg
                    class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400"
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
                    name="query"
                    value={@search_query}
                    placeholder="Buscar avaliações..."
                    class="w-full pl-10 pr-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
                    phx-debounce="300"
                  />
                </div>
              </form>
            </div>

            <form phx-change="filter_status">
              <select
                name="status"
                class="px-3 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                <option value="">Todos os status</option>
                <%= for status <- Assessment.statuses() do %>
                  <option value={status} selected={@filter_status == status}>
                    <%= Assessment.status_label(status) %>
                  </option>
                <% end %>
              </select>
            </form>

            <form phx-change="filter_subject">
              <select
                name="subject"
                class="px-3 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                <option value="">Todas as disciplinas</option>
                <%= for subject <- Assessment.subjects() do %>
                  <option value={subject} selected={@filter_subject == subject}>
                    <%= Assessment.subject_label(subject) %>
                  </option>
                <% end %>
              </select>
            </form>

            <form phx-change="filter_type">
              <select
                name="type"
                class="px-3 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                <option value="">Todos os tipos</option>
                <%= for type <- Assessment.assessment_types() do %>
                  <option value={type} selected={@filter_type == type}>
                    <%= Assessment.assessment_type_label(type) %>
                  </option>
                <% end %>
              </select>
            </form>

            <div class="flex items-center gap-1 bg-slate-100 dark:bg-slate-700 rounded-lg p-1">
              <button
                type="button"
                phx-click="toggle_view"
                phx-value-mode="cards"
                class={"px-3 py-1 rounded text-sm transition-colors #{if @view_mode == "cards", do: "bg-white dark:bg-slate-600 text-slate-900 dark:text-white shadow-sm", else: "text-slate-500 hover:text-slate-700 dark:text-slate-400"}"}
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"
                  />
                </svg>
              </button>
              <button
                type="button"
                phx-click="toggle_view"
                phx-value-mode="table"
                class={"px-3 py-1 rounded text-sm transition-colors #{if @view_mode == "table", do: "bg-white dark:bg-slate-600 text-slate-900 dark:text-white shadow-sm", else: "text-slate-500 hover:text-slate-700 dark:text-slate-400"}"}
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
        <!-- Content -->
        <%= if Enum.empty?(@assessments) do %>
          <div class="bg-white dark:bg-slate-800 rounded-xl p-12 border border-slate-200 dark:border-slate-700 text-center">
            <div class="w-16 h-16 mx-auto mb-4 bg-slate-100 dark:bg-slate-700 rounded-full flex items-center justify-center">
              <svg
                class="w-8 h-8 text-slate-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"
                />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-slate-900 dark:text-white mb-2">
              Nenhuma avaliação encontrada
            </h3>
            <p class="text-slate-500 dark:text-slate-400 mb-6">
              Crie sua primeira avaliação para começar
            </p>
            <.link
              navigate={~p"/assessments/new"}
              class="inline-flex items-center gap-2 px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white font-medium rounded-lg transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 4v16m8-8H4"
                />
              </svg>
              Nova Avaliação
            </.link>
          </div>
        <% else %>
          <%= if @view_mode == "cards" do %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for assessment <- @assessments do %>
                <.assessment_card assessment={assessment} />
              <% end %>
            </div>
          <% else %>
            <.assessments_table assessments={@assessments} />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp assessment_card(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-5 hover:shadow-lg transition-shadow">
      <div class="flex items-start justify-between mb-3">
        <span class={"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium #{status_color(@assessment.status)}"}>
          <%= Assessment.status_label(@assessment.status) %>
        </span>
        <span class="text-xs text-slate-400">
          <%= Calendar.strftime(@assessment.inserted_at, "%d/%m/%Y") %>
        </span>
      </div>

      <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-2 line-clamp-2">
        <%= @assessment.title %>
      </h3>

      <div class="flex flex-wrap gap-2 mb-4 text-xs text-slate-500 dark:text-slate-400">
        <span class="inline-flex items-center gap-1">
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
            />
          </svg>
          <%= Assessment.subject_label(@assessment.subject) %>
        </span>
        <span class="inline-flex items-center gap-1">
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
            />
          </svg>
          <%= Assessment.grade_level_label(@assessment.grade_level) %>
        </span>
        <span class={"inline-flex items-center gap-1 #{type_color(@assessment.assessment_type)}"}>
          <%= Assessment.assessment_type_label(@assessment.assessment_type) %>
        </span>
      </div>

      <div class="flex items-center gap-4 mb-4">
        <div class="text-center">
          <p class="text-lg font-bold text-slate-900 dark:text-white">
            <%= length(@assessment.questions || []) %>
          </p>
          <p class="text-xs text-slate-500">questões</p>
        </div>
        <div class="text-center">
          <p class="text-lg font-bold text-slate-900 dark:text-white">
            <%= @assessment.total_points || 0 %>
          </p>
          <p class="text-xs text-slate-500">pontos</p>
        </div>
        <div class="text-center">
          <p class="text-lg font-bold text-slate-900 dark:text-white">
            <%= @assessment.duration_minutes || "-" %>
          </p>
          <p class="text-xs text-slate-500">min</p>
        </div>
      </div>

      <%= if @assessment.generated_by_ai do %>
        <div class="mb-4">
          <span class="inline-flex items-center gap-1 px-2 py-1 bg-violet-100 dark:bg-violet-900/30 text-violet-600 dark:text-violet-400 rounded text-xs">
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
              />
            </svg>
            Gerado com IA
          </span>
        </div>
      <% end %>

      <div class="flex items-center justify-between pt-4 border-t border-slate-200 dark:border-slate-700">
        <.link
          navigate={~p"/assessments/#{@assessment.id}"}
          class="text-teal-600 hover:text-teal-700 dark:text-teal-400 dark:hover:text-teal-300 font-medium text-sm"
        >
          Ver detalhes
        </.link>

        <div class="flex items-center gap-1">
          <.link
            navigate={~p"/assessments/#{@assessment.id}/edit"}
            class="p-2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors"
            title="Editar"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
              />
            </svg>
          </.link>

          <button
            type="button"
            phx-click="duplicate"
            phx-value-id={@assessment.id}
            class="p-2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors"
            title="Duplicar"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
              />
            </svg>
          </button>

          <button
            type="button"
            phx-click="delete"
            phx-value-id={@assessment.id}
            data-confirm="Tem certeza que deseja excluir esta avaliação?"
            class="p-2 text-slate-400 hover:text-red-600 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
            title="Excluir"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
              />
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp assessments_table(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden">
      <table class="w-full">
        <thead class="bg-slate-50 dark:bg-slate-700/50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Avaliação
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Tipo
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Questões
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Status
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
          <%= for assessment <- @assessments do %>
            <tr class="hover:bg-slate-50 dark:hover:bg-slate-700/30 transition-colors">
              <td class="px-6 py-4">
                <div>
                  <.link
                    navigate={~p"/assessments/#{assessment.id}"}
                    class="font-medium text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400"
                  >
                    <%= assessment.title %>
                  </.link>
                  <p class="text-sm text-slate-500 dark:text-slate-400">
                    <%= Assessment.subject_label(assessment.subject) %> • <%= Assessment.grade_level_label(
                      assessment.grade_level
                    ) %>
                  </p>
                </div>
              </td>
              <td class="px-6 py-4">
                <span class={"text-sm #{type_color(assessment.assessment_type)}"}>
                  <%= Assessment.assessment_type_label(assessment.assessment_type) %>
                </span>
              </td>
              <td class="px-6 py-4 text-sm text-slate-900 dark:text-white">
                <%= length(assessment.questions || []) %>
              </td>
              <td class="px-6 py-4">
                <span class={"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium #{status_color(assessment.status)}"}>
                  <%= Assessment.status_label(assessment.status) %>
                </span>
              </td>
              <td class="px-6 py-4 text-sm text-slate-500 dark:text-slate-400">
                <%= Calendar.strftime(assessment.inserted_at, "%d/%m/%Y") %>
              </td>
              <td class="px-6 py-4 text-right">
                <div class="flex items-center justify-end gap-1">
                  <.link
                    navigate={~p"/assessments/#{assessment.id}/edit"}
                    class="p-2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                      />
                    </svg>
                  </.link>
                  <button
                    type="button"
                    phx-click="delete"
                    phx-value-id={assessment.id}
                    data-confirm="Tem certeza?"
                    class="p-2 text-slate-400 hover:text-red-600 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                      />
                    </svg>
                  </button>
                </div>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp status_color("draft"),
    do: "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400"

  defp status_color("published"),
    do: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400"

  defp status_color("archived"),
    do: "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-400"

  defp status_color(_), do: "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-400"

  defp type_color("prova"), do: "text-teal-600 dark:text-teal-400"
  defp type_color("simulado"), do: "text-violet-600 dark:text-violet-400"
  defp type_color("quiz"), do: "text-pink-600 dark:text-pink-400"
  defp type_color(_), do: "text-slate-600 dark:text-slate-400"
end
