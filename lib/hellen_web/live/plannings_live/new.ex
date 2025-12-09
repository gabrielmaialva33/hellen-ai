defmodule HellenWeb.PlanningsLive.New do
  @moduledoc """
  LiveView for creating new plannings - manual or AI-generated.
  """

  use HellenWeb, :live_view

  alias Hellen.AI.PlanningGenerator
  alias Hellen.Lessons
  alias Hellen.Plannings
  alias Hellen.Plannings.Planning

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Get user's lessons for AI generation
    lessons = Lessons.list_lessons_by_user(user.id, status: "analyzed", limit: 20)

    changeset = Plannings.change_planning(%Planning{}, %{})

    {:ok,
     socket
     |> assign(:page_title, "Novo Planejamento")
     |> assign(:form, to_form(changeset))
     |> assign(:lessons, lessons)
     |> assign(:mode, "manual")
     |> assign(:generating, false)
     |> assign(:suggesting, false)
     |> assign(:suggestions, nil)
     |> assign(:selected_lesson_id, nil)
     |> assign(:ai_topic, "")}
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :mode, mode)}
  end

  @impl true
  def handle_event("select_lesson", %{"id" => lesson_id}, socket) do
    {:noreply, assign(socket, :selected_lesson_id, lesson_id)}
  end

  @impl true
  def handle_event("update_topic", %{"topic" => topic}, socket) do
    {:noreply, assign(socket, :ai_topic, topic)}
  end

  @impl true
  def handle_event("generate_from_lesson", _params, socket) do
    lesson_id = socket.assigns.selected_lesson_id
    user_id = socket.assigns.current_user.id

    if lesson_id do
      socket = assign(socket, :generating, true)

      # Run AI generation in a task
      task =
        Task.async(fn ->
          PlanningGenerator.from_lesson(lesson_id, user_id)
        end)

      {:noreply, assign(socket, :generation_task, task)}
    else
      {:noreply, put_flash(socket, :error, "Selecione uma aula primeiro")}
    end
  end

  @impl true
  def handle_event(
        "generate_from_topic",
        %{"subject" => subject, "grade_level" => grade_level},
        socket
      ) do
    topic = socket.assigns.ai_topic
    user_id = socket.assigns.current_user.id

    if topic != "" and subject != "" and grade_level != "" do
      socket = assign(socket, :generating, true)

      task =
        Task.async(fn ->
          PlanningGenerator.from_topic(topic, subject, grade_level, user_id)
        end)

      {:noreply, assign(socket, :generation_task, task)}
    else
      {:noreply, put_flash(socket, :error, "Preencha todos os campos")}
    end
  end

  @impl true
  def handle_event("validate", %{"planning" => planning_params}, socket) do
    changeset =
      %Planning{}
      |> Plannings.change_planning(planning_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("request_suggestions", %{"planning" => params}, socket) do
    title = params["title"] || ""
    subject = params["subject"] || ""
    grade_level = params["grade_level"] || ""
    description = params["description"]

    if String.trim(title) != "" and subject != "" and grade_level != "" do
      socket = assign(socket, :suggesting, true)

      task =
        Task.async(fn ->
          PlanningGenerator.suggest_fields(title, subject, grade_level, description)
        end)

      {:noreply, assign(socket, :suggestion_task, task)}
    else
      {:noreply,
       put_flash(socket, :error, "Preencha título, disciplina e série para gerar sugestões")}
    end
  end

  @impl true
  def handle_event("apply_suggestion", %{"field" => field}, socket) do
    suggestions = socket.assigns.suggestions

    if suggestions do
      value = Map.get(suggestions, String.to_existing_atom(field))
      form = socket.assigns.form
      current_params = form.source.changes

      new_params = Map.put(current_params, String.to_existing_atom(field), value)

      changeset =
        %Planning{}
        |> Plannings.change_planning(new_params)

      {:noreply, assign(socket, :form, to_form(changeset))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("dismiss_suggestions", _params, socket) do
    {:noreply, assign(socket, :suggestions, nil)}
  end

  @impl true
  def handle_event("save", %{"planning" => planning_params}, socket) do
    user = socket.assigns.current_user

    planning_params =
      planning_params
      |> Map.put("user_id", user.id)
      |> Map.put("institution_id", user.institution_id)

    case Plannings.create_planning(planning_params) do
      {:ok, planning} ->
        {:noreply,
         socket
         |> put_flash(:info, "Planejamento criado com sucesso!")
         |> push_navigate(to: ~p"/plannings/#{planning.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_info({ref, result}, socket) do
    cond do
      # Handle generation task result
      Map.has_key?(socket.assigns, :generation_task) and
        socket.assigns.generation_task != nil and
          ref == socket.assigns.generation_task.ref ->
        Process.demonitor(ref, [:flush])

        case result do
          {:ok, planning} ->
            {:noreply,
             socket
             |> assign(:generating, false)
             |> put_flash(:info, "Planejamento gerado com sucesso!")
             |> push_navigate(to: ~p"/plannings/#{planning.id}/edit")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:generating, false)
             |> put_flash(:error, "Erro ao gerar planejamento: #{inspect(reason)}")}
        end

      # Handle suggestion task result
      Map.has_key?(socket.assigns, :suggestion_task) and
        socket.assigns.suggestion_task != nil and
          ref == socket.assigns.suggestion_task.ref ->
        Process.demonitor(ref, [:flush])

        case result do
          {:ok, suggestions} ->
            {:noreply,
             socket
             |> assign(:suggesting, false)
             |> assign(:suggestions, suggestions)}

          {:error, _reason} ->
            {:noreply,
             socket
             |> assign(:suggesting, false)
             |> put_flash(:error, "Erro ao gerar sugestões")}
        end

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, assign(socket, :generating, false)}
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
              navigate={~p"/plannings"}
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
                Novo Planejamento
              </h1>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                Crie um plano de aula manual ou use IA
              </p>
            </div>
          </div>
        </div>
      </div>
      <!-- Mode Selector -->
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-1 inline-flex">
          <button
            phx-click="switch_mode"
            phx-value-mode="manual"
            class={"px-4 py-2 rounded-lg text-sm font-medium transition-colors #{if @mode == "manual", do: "bg-teal-600 text-white", else: "text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700"}"}
          >
            Criar Manualmente
          </button>
          <button
            phx-click="switch_mode"
            phx-value-mode="from_lesson"
            class={"px-4 py-2 rounded-lg text-sm font-medium transition-colors #{if @mode == "from_lesson", do: "bg-teal-600 text-white", else: "text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700"}"}
          >
            <span class="inline-flex items-center gap-1">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 10V3L4 14h7v7l9-11h-7z"
                />
              </svg>
              De uma Aula
            </span>
          </button>
          <button
            phx-click="switch_mode"
            phx-value-mode="from_topic"
            class={"px-4 py-2 rounded-lg text-sm font-medium transition-colors #{if @mode == "from_topic", do: "bg-teal-600 text-white", else: "text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700"}"}
          >
            <span class="inline-flex items-center gap-1">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 10V3L4 14h7v7l9-11h-7z"
                />
              </svg>
              De um Tema
            </span>
          </button>
        </div>
      </div>
      <!-- Content -->
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 pb-12">
        <%= if @generating do %>
          <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-12 text-center">
            <div class="animate-spin w-12 h-12 border-4 border-teal-600 border-t-transparent rounded-full mx-auto">
            </div>
            <h3 class="mt-4 text-lg font-medium text-slate-900 dark:text-white">
              Gerando planejamento com IA...
            </h3>
            <p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
              Isso pode levar alguns segundos
            </p>
          </div>
        <% else %>
          <%= case @mode do %>
            <% "manual" -> %>
              <.manual_form form={@form} suggesting={@suggesting} suggestions={@suggestions} />
            <% "from_lesson" -> %>
              <.from_lesson_form lessons={@lessons} selected={@selected_lesson_id} />
            <% "from_topic" -> %>
              <.from_topic_form topic={@ai_topic} />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp manual_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- AI Suggestions Panel -->
      <%= if @suggestions do %>
        <div class="bg-violet-50 dark:bg-violet-900/20 border border-violet-200 dark:border-violet-800 rounded-xl p-4">
          <div class="flex items-start justify-between mb-3">
            <div class="flex items-center gap-2">
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
                  d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
                />
              </svg>
              <h3 class="font-medium text-violet-900 dark:text-violet-200">Sugestoes da IA</h3>
            </div>
            <button
              type="button"
              phx-click="dismiss_suggestions"
              class="text-violet-400 hover:text-violet-600 dark:hover:text-violet-300"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>

          <div class="space-y-3">
            <%= if @suggestions.description do %>
              <div class="bg-white dark:bg-slate-800 rounded-lg p-3">
                <div class="flex items-center justify-between mb-1">
                  <span class="text-xs font-medium text-violet-600 dark:text-violet-400">
                    Descricao
                  </span>
                  <button
                    type="button"
                    phx-click="apply_suggestion"
                    phx-value-field="description"
                    class="text-xs text-violet-600 hover:text-violet-800 dark:text-violet-400 dark:hover:text-violet-300 font-medium"
                  >
                    Aplicar
                  </button>
                </div>
                <p class="text-sm text-slate-700 dark:text-slate-300">
                  <%= @suggestions.description %>
                </p>
              </div>
            <% end %>

            <%= if @suggestions.methodology do %>
              <div class="bg-white dark:bg-slate-800 rounded-lg p-3">
                <div class="flex items-center justify-between mb-1">
                  <span class="text-xs font-medium text-violet-600 dark:text-violet-400">
                    Metodologia
                  </span>
                  <button
                    type="button"
                    phx-click="apply_suggestion"
                    phx-value-field="methodology"
                    class="text-xs text-violet-600 hover:text-violet-800 dark:text-violet-400 dark:hover:text-violet-300 font-medium"
                  >
                    Aplicar
                  </button>
                </div>
                <p class="text-sm text-slate-700 dark:text-slate-300">
                  <%= @suggestions.methodology %>
                </p>
              </div>
            <% end %>

            <%= if @suggestions.assessment_criteria do %>
              <div class="bg-white dark:bg-slate-800 rounded-lg p-3">
                <div class="flex items-center justify-between mb-1">
                  <span class="text-xs font-medium text-violet-600 dark:text-violet-400">
                    Criterios de Avaliacao
                  </span>
                  <button
                    type="button"
                    phx-click="apply_suggestion"
                    phx-value-field="assessment_criteria"
                    class="text-xs text-violet-600 hover:text-violet-800 dark:text-violet-400 dark:hover:text-violet-300 font-medium"
                  >
                    Aplicar
                  </button>
                </div>
                <p class="text-sm text-slate-700 dark:text-slate-300">
                  <%= @suggestions.assessment_criteria %>
                </p>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div class="md:col-span-2">
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Titulo *
              </label>
              <input
                type="text"
                name="planning[title]"
                value={@form[:title].value}
                placeholder="Ex: Introducao as Fracoes"
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
                  <option value={subject} selected={@form[:subject].value == subject}>
                    <%= Planning.subject_label(subject) %>
                  </option>
                <% end %>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Ano/Serie *
              </label>
              <select
                name="planning[grade_level]"
                class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                required
              >
                <option value="">Selecione...</option>
                <%= for level <- Planning.grade_levels() do %>
                  <option value={level} selected={@form[:grade_level].value == level}>
                    <%= Planning.grade_level_label(level) %>
                  </option>
                <% end %>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Duracao (minutos)
              </label>
              <input
                type="number"
                name="planning[duration_minutes]"
                value={@form[:duration_minutes].value || 50}
                min="15"
                max="240"
                class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
              />
            </div>
            <!-- AI Suggest Button -->
            <div class="flex items-end">
              <button
                type="button"
                phx-click="request_suggestions"
                disabled={@suggesting}
                class="w-full inline-flex items-center justify-center gap-2 px-4 py-2 bg-violet-100 hover:bg-violet-200 dark:bg-violet-900/30 dark:hover:bg-violet-900/50 text-violet-700 dark:text-violet-300 font-medium rounded-lg transition-colors disabled:opacity-50"
              >
                <%= if @suggesting do %>
                  <svg class="animate-spin w-4 h-4" fill="none" viewBox="0 0 24 24">
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    >
                    </circle>
                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    >
                    </path>
                  </svg>
                  Gerando...
                <% else %>
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
                    />
                  </svg>
                  Sugerir com IA
                <% end %>
              </button>
            </div>

            <div class="md:col-span-2">
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Descricao
              </label>
              <textarea
                name="planning[description]"
                rows="3"
                placeholder="Breve descricao do que sera abordado na aula"
                class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
              ><%= @form[:description].value %></textarea>
            </div>

            <div class="md:col-span-2">
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Metodologia
              </label>
              <textarea
                name="planning[methodology]"
                rows="4"
                placeholder="Descreva a metodologia que sera utilizada (expositiva, dialogada, pratica, etc.)"
                class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
              ><%= @form[:methodology].value %></textarea>
            </div>

            <div class="md:col-span-2">
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Criterios de Avaliacao
              </label>
              <textarea
                name="planning[assessment_criteria]"
                rows="3"
                placeholder="Como voce avaliara se os objetivos foram alcancados?"
                class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
              ><%= @form[:assessment_criteria].value %></textarea>
            </div>
          </div>

          <div class="flex justify-end gap-3 pt-4 border-t border-slate-200 dark:border-slate-700">
            <.link
              navigate={~p"/plannings"}
              class="px-4 py-2 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors"
            >
              Cancelar
            </.link>
            <button
              type="submit"
              class="px-6 py-2 bg-teal-600 hover:bg-teal-700 text-white font-medium rounded-lg transition-colors"
            >
              Criar Planejamento
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp from_lesson_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-violet-50 dark:bg-violet-900/20 border border-violet-200 dark:border-violet-800 rounded-xl p-4">
        <div class="flex items-start gap-3">
          <svg
            class="w-5 h-5 text-violet-600 dark:text-violet-400 mt-0.5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13 10V3L4 14h7v7l9-11h-7z"
            />
          </svg>
          <div>
            <h3 class="font-medium text-violet-900 dark:text-violet-200">Geração com IA</h3>
            <p class="mt-1 text-sm text-violet-700 dark:text-violet-300">
              Selecione uma aula já analisada para gerar automaticamente um planejamento baseado na transcrição.
            </p>
          </div>
        </div>
      </div>

      <%= if Enum.empty?(@lessons) do %>
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
              d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
            />
          </svg>
          <h3 class="mt-4 text-lg font-medium text-slate-900 dark:text-white">
            Nenhuma aula analisada
          </h3>
          <p class="mt-2 text-sm text-slate-500 dark:text-slate-400">
            Você precisa ter aulas já analisadas para gerar planejamentos automaticamente.
          </p>
          <.link
            navigate={~p"/lessons/new"}
            class="mt-4 inline-flex items-center gap-2 px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white font-medium rounded-lg transition-colors"
          >
            Enviar uma Aula
          </.link>
        </div>
      <% else %>
        <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
          <h3 class="text-lg font-medium text-slate-900 dark:text-white mb-4">
            Selecione uma aula
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3 max-h-96 overflow-y-auto">
            <%= for lesson <- @lessons do %>
              <button
                phx-click="select_lesson"
                phx-value-id={lesson.id}
                class={"p-4 text-left rounded-xl border-2 transition-all #{if @selected == lesson.id, do: "border-teal-500 bg-teal-50 dark:bg-teal-900/20", else: "border-slate-200 dark:border-slate-700 hover:border-slate-300 dark:hover:border-slate-600"}"}
              >
                <div class="font-medium text-slate-900 dark:text-white line-clamp-1">
                  <%= lesson.title %>
                </div>
                <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                  <%= lesson.subject || "Disciplina não definida" %> • <%= lesson.grade_level ||
                    "Série não definida" %>
                </div>
                <div class="mt-2 text-xs text-slate-400 dark:text-slate-500">
                  <%= Calendar.strftime(lesson.inserted_at, "%d/%m/%Y") %>
                </div>
              </button>
            <% end %>
          </div>

          <div class="mt-6 flex justify-end">
            <button
              phx-click="generate_from_lesson"
              disabled={@selected == nil}
              class={"px-6 py-2 font-medium rounded-lg transition-colors #{if @selected, do: "bg-violet-600 hover:bg-violet-700 text-white", else: "bg-slate-200 dark:bg-slate-700 text-slate-400 cursor-not-allowed"}"}
            >
              <span class="inline-flex items-center gap-2">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M13 10V3L4 14h7v7l9-11h-7z"
                  />
                </svg>
                Gerar Planejamento
              </span>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp from_topic_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-violet-50 dark:bg-violet-900/20 border border-violet-200 dark:border-violet-800 rounded-xl p-4">
        <div class="flex items-start gap-3">
          <svg
            class="w-5 h-5 text-violet-600 dark:text-violet-400 mt-0.5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13 10V3L4 14h7v7l9-11h-7z"
            />
          </svg>
          <div>
            <h3 class="font-medium text-violet-900 dark:text-violet-200">Geração com IA</h3>
            <p class="mt-1 text-sm text-violet-700 dark:text-violet-300">
              Descreva o tema que você quer ensinar e a IA criará um planejamento completo.
            </p>
          </div>
        </div>
      </div>

      <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
        <form phx-submit="generate_from_topic" class="space-y-6">
          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Tema da Aula *
            </label>
            <textarea
              name="topic"
              rows="3"
              value={@topic}
              phx-change="update_topic"
              phx-debounce="300"
              placeholder="Descreva o tema que você quer ensinar. Ex: 'Introdução às frações com material concreto para alunos do 5º ano'"
              class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
              required
            ><%= @topic %></textarea>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Disciplina *
              </label>
              <select
                name="subject"
                class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                required
              >
                <option value="">Selecione...</option>
                <%= for subject <- Planning.subjects() do %>
                  <option value={subject}><%= Planning.subject_label(subject) %></option>
                <% end %>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Ano/Série *
              </label>
              <select
                name="grade_level"
                class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                required
              >
                <option value="">Selecione...</option>
                <%= for level <- Planning.grade_levels() do %>
                  <option value={level}><%= Planning.grade_level_label(level) %></option>
                <% end %>
              </select>
            </div>
          </div>

          <div class="flex justify-end">
            <button
              type="submit"
              class="px-6 py-2 bg-violet-600 hover:bg-violet-700 text-white font-medium rounded-lg transition-colors"
            >
              <span class="inline-flex items-center gap-2">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M13 10V3L4 14h7v7l9-11h-7z"
                  />
                </svg>
                Gerar Planejamento
              </span>
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
