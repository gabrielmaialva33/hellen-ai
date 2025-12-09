defmodule HellenWeb.AssessmentsLive.Edit do
  @moduledoc """
  LiveView for editing assessments.
  """

  use HellenWeb, :live_view

  alias Hellen.Assessments
  alias Hellen.Assessments.Assessment

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    assessment = Assessments.get_assessment!(id)
    changeset = Assessments.change_assessment(assessment)

    {:ok,
     socket
     |> assign(:page_title, "Editar Avaliação")
     |> assign(:assessment, assessment)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"assessment" => assessment_params}, socket) do
    changeset =
      socket.assigns.assessment
      |> Assessments.change_assessment(assessment_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"assessment" => assessment_params}, socket) do
    case Assessments.update_assessment(socket.assigns.assessment, assessment_params) do
      {:ok, assessment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Avaliação atualizada com sucesso!")
         |> push_navigate(to: ~p"/assessments/#{assessment.id}")}

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
              navigate={~p"/assessments/#{@assessment.id}"}
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
                Editar Avaliação
              </h1>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                <%= @assessment.title %>
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
                  name="assessment[title]"
                  value={Phoenix.HTML.Form.input_value(@changeset, :title)}
                  placeholder="Ex: Prova de Matemática - 1º Bimestre"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Disciplina *
                </label>
                <select
                  name="assessment[subject]"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                  required
                >
                  <option value="">Selecione...</option>
                  <%= for subject <- Assessment.subjects() do %>
                    <option
                      value={subject}
                      selected={Phoenix.HTML.Form.input_value(@changeset, :subject) == subject}
                    >
                      <%= Assessment.subject_label(subject) %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Ano/Série *
                </label>
                <select
                  name="assessment[grade_level]"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                  required
                >
                  <option value="">Selecione...</option>
                  <%= for level <- Assessment.grade_levels() do %>
                    <option
                      value={level}
                      selected={Phoenix.HTML.Form.input_value(@changeset, :grade_level) == level}
                    >
                      <%= Assessment.grade_level_label(level) %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Tipo de Avaliação
                </label>
                <select
                  name="assessment[assessment_type]"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                >
                  <%= for type <- Assessment.assessment_types() do %>
                    <option
                      value={type}
                      selected={Phoenix.HTML.Form.input_value(@changeset, :assessment_type) == type}
                    >
                      <%= Assessment.assessment_type_label(type) %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Dificuldade
                </label>
                <select
                  name="assessment[difficulty_level]"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                >
                  <%= for level <- Assessment.difficulty_levels() do %>
                    <option
                      value={level}
                      selected={Phoenix.HTML.Form.input_value(@changeset, :difficulty_level) == level}
                    >
                      <%= Assessment.difficulty_label(level) %>
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
                  name="assessment[duration_minutes]"
                  value={Phoenix.HTML.Form.input_value(@changeset, :duration_minutes)}
                  min="15"
                  max="480"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Status
                </label>
                <select
                  name="assessment[status]"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                >
                  <%= for status <- Assessment.statuses() do %>
                    <option
                      value={status}
                      selected={Phoenix.HTML.Form.input_value(@changeset, :status) == status}
                    >
                      <%= Assessment.status_label(status) %>
                    </option>
                  <% end %>
                </select>
              </div>

              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Descrição
                </label>
                <textarea
                  name="assessment[description]"
                  rows="3"
                  placeholder="Breve descrição do que será avaliado"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
                ><%= Phoenix.HTML.Form.input_value(@changeset, :description) %></textarea>
              </div>

              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Instruções para os Alunos
                </label>
                <textarea
                  name="assessment[instructions]"
                  rows="4"
                  placeholder="Instruções que aparecerão no início da avaliação"
                  class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
                ><%= Phoenix.HTML.Form.input_value(@changeset, :instructions) %></textarea>
              </div>
            </div>

            <div class="flex justify-end gap-3 pt-4 border-t border-slate-200 dark:border-slate-700">
              <.link
                navigate={~p"/assessments/#{@assessment.id}"}
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
