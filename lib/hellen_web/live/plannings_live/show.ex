defmodule HellenWeb.PlanningsLive.Show do
  @moduledoc """
  LiveView for viewing planning details.
  """

  use HellenWeb, :live_view

  alias Hellen.Plannings
  alias Hellen.Plannings.Planning

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    planning = Plannings.get_planning!(id)

    {:ok,
     socket
     |> assign(:page_title, planning.title)
     |> assign(:planning, planning)}
  end

  @impl true
  def handle_event("publish", _params, socket) do
    case Plannings.publish_planning(socket.assigns.planning) do
      {:ok, planning} ->
        {:noreply,
         socket
         |> assign(:planning, planning)
         |> put_flash(:info, "Planejamento publicado!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao publicar")}
    end
  end

  @impl true
  def handle_event("archive", _params, socket) do
    case Plannings.archive_planning(socket.assigns.planning) do
      {:ok, planning} ->
        {:noreply,
         socket
         |> assign(:planning, planning)
         |> put_flash(:info, "Planejamento arquivado!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao arquivar")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50 dark:bg-slate-900">
      <!-- Header -->
      <div class="bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700">
        <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
            <div class="flex items-start gap-4">
              <.link
                navigate={~p"/plannings"}
                class="p-2 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 mt-1"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10 19l-7-7m0 0l7-7m-7 7h18"
                  />
                </svg>
              </.link>
              <div>
                <div class="flex items-center gap-2">
                  <.status_badge status={@planning.status} />
                  <%= if @planning.generated_by_ai do %>
                    <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-violet-100 dark:bg-violet-900/30 text-violet-600 dark:text-violet-400 rounded-full text-xs font-medium">
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
                </div>
                <h1 class="mt-2 text-2xl font-bold text-slate-900 dark:text-white">
                  <%= @planning.title %>
                </h1>
                <div class="mt-2 flex flex-wrap items-center gap-3 text-sm text-slate-500 dark:text-slate-400">
                  <span class="inline-flex items-center gap-1">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"
                      />
                    </svg>
                    <%= Planning.subject_label(@planning.subject) %>
                  </span>
                  <span class="inline-flex items-center gap-1">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"
                      />
                    </svg>
                    <%= Planning.grade_level_label(@planning.grade_level) %>
                  </span>
                  <%= if @planning.duration_minutes do %>
                    <span class="inline-flex items-center gap-1">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                        />
                      </svg>
                      <%= @planning.duration_minutes %> min
                    </span>
                  <% end %>
                </div>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <.link
                navigate={~p"/plannings/#{@planning.id}/edit"}
                class="inline-flex items-center gap-2 px-4 py-2 border border-slate-200 dark:border-slate-600 text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors"
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
              <%= if @planning.status == "draft" do %>
                <button
                  phx-click="publish"
                  class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg transition-colors"
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
            </div>
          </div>
        </div>
      </div>
      <!-- Content -->
      <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Main Content -->
          <div class="lg:col-span-2 space-y-6">
            <!-- Description -->
            <%= if @planning.description do %>
              <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
                <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-3">
                  Descrição
                </h2>
                <p class="text-slate-600 dark:text-slate-300 whitespace-pre-wrap">
                  <%= @planning.description %>
                </p>
              </div>
            <% end %>
            <!-- Objectives -->
            <%= if length(@planning.objectives || []) > 0 do %>
              <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
                <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-3">
                  Objetivos de Aprendizagem
                </h2>
                <ul class="space-y-2">
                  <%= for objective <- @planning.objectives do %>
                    <li class="flex items-start gap-2 text-slate-600 dark:text-slate-300">
                      <svg
                        class="w-5 h-5 text-teal-500 mt-0.5 flex-shrink-0"
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
                      <%= objective %>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>
            <!-- Content Structure -->
            <%= if @planning.content && map_size(@planning.content) > 0 do %>
              <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
                <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
                  Estrutura da Aula
                </h2>
                <div class="space-y-4">
                  <%= if @planning.content["introduction"] do %>
                    <div class="p-4 bg-teal-50 dark:bg-teal-900/20 rounded-lg border border-teal-200 dark:border-teal-800">
                      <h3 class="font-medium text-teal-900 dark:text-teal-200 mb-2">
                        Introdução
                      </h3>
                      <p class="text-teal-800 dark:text-teal-300 text-sm">
                        <%= @planning.content["introduction"] %>
                      </p>
                    </div>
                  <% end %>

                  <%= if @planning.content["development"] do %>
                    <div>
                      <h3 class="font-medium text-slate-900 dark:text-white mb-3">
                        Desenvolvimento
                      </h3>
                      <div class="space-y-3">
                        <%= for step <- @planning.content["development"] || [] do %>
                          <div class="flex gap-4 p-4 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
                            <div class="flex-shrink-0 w-8 h-8 bg-teal-600 text-white rounded-full flex items-center justify-center font-semibold text-sm">
                              <%= step["step"] %>
                            </div>
                            <div class="flex-1">
                              <p class="text-slate-700 dark:text-slate-200">
                                <%= step["activity"] %>
                              </p>
                              <%= if step["duration_minutes"] do %>
                                <p class="mt-1 text-xs text-slate-500 dark:text-slate-400">
                                  <%= step["duration_minutes"] %> minutos
                                </p>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <%= if @planning.content["closure"] do %>
                    <div class="p-4 bg-emerald-50 dark:bg-emerald-900/20 rounded-lg border border-emerald-200 dark:border-emerald-800">
                      <h3 class="font-medium text-emerald-900 dark:text-emerald-200 mb-2">
                        Encerramento
                      </h3>
                      <p class="text-emerald-800 dark:text-emerald-300 text-sm">
                        <%= @planning.content["closure"] %>
                      </p>
                    </div>
                  <% end %>

                  <%= if @planning.content["homework"] && @planning.content["homework"] != "" do %>
                    <div class="p-4 bg-amber-50 dark:bg-amber-900/20 rounded-lg border border-amber-200 dark:border-amber-800">
                      <h3 class="font-medium text-amber-900 dark:text-amber-200 mb-2">
                        Tarefa de Casa
                      </h3>
                      <p class="text-amber-800 dark:text-amber-300 text-sm">
                        <%= @planning.content["homework"] %>
                      </p>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
            <!-- Methodology -->
            <%= if @planning.methodology do %>
              <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
                <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-3">
                  Metodologia
                </h2>
                <p class="text-slate-600 dark:text-slate-300 whitespace-pre-wrap">
                  <%= @planning.methodology %>
                </p>
              </div>
            <% end %>
            <!-- Assessment -->
            <%= if @planning.assessment_criteria do %>
              <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
                <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-3">
                  Critérios de Avaliação
                </h2>
                <p class="text-slate-600 dark:text-slate-300 whitespace-pre-wrap">
                  <%= @planning.assessment_criteria %>
                </p>
              </div>
            <% end %>
          </div>
          <!-- Sidebar -->
          <div class="space-y-6">
            <!-- BNCC Codes -->
            <%= if length(@planning.bncc_codes || []) > 0 do %>
              <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
                <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-3">
                  Códigos BNCC
                </h2>
                <div class="flex flex-wrap gap-2">
                  <%= for code <- @planning.bncc_codes do %>
                    <span class="px-3 py-1 bg-teal-100 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300 rounded-full text-sm font-medium">
                      <%= code %>
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
            <!-- Materials -->
            <%= if length(@planning.materials || []) > 0 do %>
              <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
                <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-3">
                  Materiais Necessários
                </h2>
                <ul class="space-y-2">
                  <%= for material <- @planning.materials do %>
                    <li class="flex items-center gap-2 text-slate-600 dark:text-slate-300 text-sm">
                      <svg
                        class="w-4 h-4 text-slate-400"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M5 13l4 4L19 7"
                        />
                      </svg>
                      <%= material %>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>
            <!-- Info -->
            <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
              <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-3">
                Informações
              </h2>
              <dl class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <dt class="text-slate-500 dark:text-slate-400">Criado em</dt>
                  <dd class="text-slate-900 dark:text-white font-medium">
                    <%= Calendar.strftime(@planning.inserted_at, "%d/%m/%Y às %H:%M") %>
                  </dd>
                </div>
                <div class="flex justify-between">
                  <dt class="text-slate-500 dark:text-slate-400">Atualizado em</dt>
                  <dd class="text-slate-900 dark:text-white font-medium">
                    <%= Calendar.strftime(@planning.updated_at, "%d/%m/%Y às %H:%M") %>
                  </dd>
                </div>
                <%= if @planning.source_lesson do %>
                  <div class="pt-3 border-t border-slate-200 dark:border-slate-700">
                    <dt class="text-slate-500 dark:text-slate-400 mb-1">Baseado na aula</dt>
                    <dd>
                      <.link
                        navigate={~p"/lessons/#{@planning.source_lesson.id}"}
                        class="text-teal-600 dark:text-teal-400 hover:underline font-medium"
                      >
                        <%= @planning.source_lesson.title %>
                      </.link>
                    </dd>
                  </div>
                <% end %>
              </dl>
            </div>
            <!-- Actions -->
            <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
              <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-3">
                Ações
              </h2>
              <div class="space-y-2">
                <.link
                  navigate={~p"/assessments/new?planning_id=#{@planning.id}"}
                  class="flex items-center gap-2 w-full px-4 py-2 text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors"
                >
                  <svg
                    class="w-5 h-5 text-violet-500"
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
                  Gerar Prova
                </.link>
                <button
                  onclick="window.print()"
                  class="flex items-center gap-2 w-full px-4 py-2 text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors"
                >
                  <svg
                    class="w-5 h-5 text-slate-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"
                    />
                  </svg>
                  Imprimir
                </button>
                <%= if @planning.status != "archived" do %>
                  <button
                    phx-click="archive"
                    class="flex items-center gap-2 w-full px-4 py-2 text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
              </div>
            </div>
          </div>
        </div>
      </div>
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
