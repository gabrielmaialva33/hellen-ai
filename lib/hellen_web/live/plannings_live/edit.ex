defmodule HellenWeb.PlanningsLive.Edit do
  @moduledoc """
  LiveView for editing plannings.
  """

  use HellenWeb, :live_view

  alias Hellen.Plannings
  alias Hellen.Plannings.Planning

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    planning = Plannings.get_planning!(id)
    changeset = Plannings.change_planning(planning)

    {:ok,
     socket
     |> assign(:page_title, "Editar Planejamento")
     |> assign(:planning, planning)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"planning" => planning_params}, socket) do
    changeset =
      socket.assigns.planning
      |> Plannings.change_planning(planning_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"planning" => planning_params}, socket) do
    case Plannings.update_planning(socket.assigns.planning, planning_params) do
      {:ok, planning} ->
        {:noreply,
         socket
         |> put_flash(:info, "Planejamento atualizado com sucesso!")
         |> push_navigate(to: ~p"/plannings/#{planning.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50 dark:bg-slate-900">
      <!-- Header -->
      <div class="bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex items-center gap-4">
            <.link
              navigate={~p"/plannings/#{@planning.id}"}
              class="p-2 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700"
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
              <h1 class="text-2xl font-bold text-slate-900 dark:text-white">
                Editar Planejamento
              </h1>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                <%= @planning.title %>
              </p>
            </div>
          </div>
        </div>
      </div>
      <!-- Content -->
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
          <.form for={@changeset} phx-change="validate" phx-submit="save" class="space-y-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Título *
                </label>
                <input
                  type="text"
                  name="planning[title]"
                  value={Phoenix.HTML.Form.input_value(@changeset, :title)}
                  placeholder="Ex: Introdução às Frações"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Disciplina *
                </label>
                <select
                  name="planning[subject]"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                  required
                >
                  <option value="">Selecione...</option>
                  <%= for subject <- Planning.subjects() do %>
                    <option
                      value={subject}
                      selected={Phoenix.HTML.Form.input_value(@changeset, :subject) == subject}
                    >
                      <%= Planning.subject_label(subject) %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Ano/Série *
                </label>
                <select
                  name="planning[grade_level]"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                  required
                >
                  <option value="">Selecione...</option>
                  <%= for level <- Planning.grade_levels() do %>
                    <option
                      value={level}
                      selected={Phoenix.HTML.Form.input_value(@changeset, :grade_level) == level}
                    >
                      <%= Planning.grade_level_label(level) %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Duração (minutos)
                </label>
                <input
                  type="number"
                  name="planning[duration_minutes]"
                  value={Phoenix.HTML.Form.input_value(@changeset, :duration_minutes)}
                  min="15"
                  max="240"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Status
                </label>
                <select
                  name="planning[status]"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                >
                  <%= for status <- Planning.statuses() do %>
                    <option
                      value={status}
                      selected={Phoenix.HTML.Form.input_value(@changeset, :status) == status}
                    >
                      <%= Planning.status_label(status) %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Descrição
                </label>
                <textarea
                  name="planning[description]"
                  rows="3"
                  placeholder="Breve descrição do que será abordado na aula"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
                ><%= Phoenix.HTML.Form.input_value(@changeset, :description) %></textarea>
              </div>

              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Metodologia
                </label>
                <textarea
                  name="planning[methodology]"
                  rows="4"
                  placeholder="Descreva a metodologia que será utilizada"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
                ><%= Phoenix.HTML.Form.input_value(@changeset, :methodology) %></textarea>
              </div>

              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Critérios de Avaliação
                </label>
                <textarea
                  name="planning[assessment_criteria]"
                  rows="3"
                  placeholder="Como você avaliará se os objetivos foram alcançados?"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
                ><%= Phoenix.HTML.Form.input_value(@changeset, :assessment_criteria) %></textarea>
              </div>
            </div>

            <div class="flex justify-end gap-3 pt-4 border-t border-slate-200 dark:border-slate-700">
              <.link
                navigate={~p"/plannings/#{@planning.id}"}
                class="px-4 py-2 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors"
              >
                Cancelar
              </.link>
              <button
                type="submit"
                class="px-6 py-2 bg-teal-600 hover:bg-teal-700 text-white font-medium rounded-lg transition-colors"
              >
                Salvar Alterações
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
