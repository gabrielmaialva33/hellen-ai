defmodule HellenWeb.AssessmentsLive.New do
  @moduledoc """
  LiveView for creating new assessments.

  Supports three creation modes:
  - Manual: Fill form manually
  - From Planning: AI generates from existing planning
  - From Topic: AI generates from topic description
  """

  use HellenWeb, :live_view

  alias Hellen.AI.AssessmentGenerator
  alias Hellen.Assessments
  alias Hellen.Assessments.Assessment
  alias Hellen.Plannings

  @impl true
  def mount(_params, _session, socket) do
    changeset = Assessments.change_assessment(%Assessment{})
    user_id = socket.assigns.current_user.id
    plannings = Plannings.list_plannings(user_id, status: "published", limit: 50)

    {:ok,
     socket
     |> assign(:page_title, "Nova Avaliação")
     |> assign(:form, to_form(changeset))
     |> assign(:mode, "manual")
     |> assign(:plannings, plannings)
     |> assign(:selected_planning_id, nil)
     |> assign(:topic, "")
     |> assign(:subject, "portugues")
     |> assign(:grade_level, "5_ano")
     |> assign(:assessment_type, "prova")
     |> assign(:difficulty_level, "medio")
     |> assign(:num_questions, 10)
     |> assign(:question_types, ["multiple_choice", "true_false", "short_answer"])
     |> assign(:generating, false)
     |> assign(:generation_error, nil)}
  end

  @impl true
  def handle_event("change_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :mode, mode)}
  end

  @impl true
  def handle_event("validate", %{"assessment" => params}, socket) do
    changeset =
      %Assessment{}
      |> Assessments.change_assessment(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"assessment" => params}, socket) do
    user_id = socket.assigns.current_user.id
    params = Map.put(params, "user_id", user_id)

    case Assessments.create_assessment(params) do
      {:ok, assessment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Avaliação criada com sucesso!")
         |> push_navigate(to: ~p"/assessments/#{assessment.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("select_planning", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_planning_id, id)}
  end

  @impl true
  def handle_event("update_topic", %{"topic" => topic}, socket) do
    {:noreply, assign(socket, :topic, topic)}
  end

  @impl true
  def handle_event("update_config", params, socket) do
    socket =
      socket
      |> maybe_assign(:subject, params["subject"])
      |> maybe_assign(:grade_level, params["grade_level"])
      |> maybe_assign(:assessment_type, params["assessment_type"])
      |> maybe_assign(:difficulty_level, params["difficulty_level"])
      |> maybe_assign_int(:num_questions, params["num_questions"])

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_question_type", %{"type" => type}, socket) do
    types = socket.assigns.question_types

    new_types =
      if type in types do
        List.delete(types, type)
      else
        types ++ [type]
      end

    {:noreply, assign(socket, :question_types, new_types)}
  end

  @impl true
  def handle_event("generate_from_planning", _params, socket) do
    planning_id = socket.assigns.selected_planning_id

    if is_nil(planning_id) do
      {:noreply, put_flash(socket, :error, "Selecione um planejamento")}
    else
      socket = assign(socket, generating: true, generation_error: nil)
      user_id = socket.assigns.current_user.id

      opts = [
        assessment_type: socket.assigns.assessment_type,
        difficulty_level: socket.assigns.difficulty_level,
        num_questions: socket.assigns.num_questions,
        question_types: socket.assigns.question_types
      ]

      task = Task.async(fn -> AssessmentGenerator.from_planning(planning_id, user_id, opts) end)
      {:noreply, assign(socket, :generation_task, task)}
    end
  end

  @impl true
  def handle_event("generate_from_topic", _params, socket) do
    topic = socket.assigns.topic

    if String.trim(topic) == "" do
      {:noreply, put_flash(socket, :error, "Digite um tema para a avaliação")}
    else
      socket = assign(socket, generating: true, generation_error: nil)
      user_id = socket.assigns.current_user.id

      opts = [
        assessment_type: socket.assigns.assessment_type,
        difficulty_level: socket.assigns.difficulty_level,
        num_questions: socket.assigns.num_questions,
        question_types: socket.assigns.question_types
      ]

      task =
        Task.async(fn ->
          AssessmentGenerator.from_topic(
            topic,
            socket.assigns.subject,
            socket.assigns.grade_level,
            user_id,
            opts
          )
        end)

      {:noreply, assign(socket, :generation_task, task)}
    end
  end

  @impl true
  def handle_info({ref, result}, socket) do
    if Map.has_key?(socket.assigns, :generation_task) and
         socket.assigns.generation_task.ref == ref do
      Process.demonitor(ref, [:flush])

      case result do
        {:ok, assessment} ->
          {:noreply,
           socket
           |> assign(:generating, false)
           |> put_flash(:info, "Avaliação gerada com sucesso!")
           |> push_navigate(to: ~p"/assessments/#{assessment.id}")}

        {:error, reason} ->
          error_msg =
            case reason do
              :planning_not_found -> "Planejamento não encontrado"
              :invalid_json_response -> "Erro ao processar resposta da IA"
              %{message: msg} -> msg
              _ -> "Erro ao gerar avaliação"
            end

          {:noreply,
           socket
           |> assign(:generating, false)
           |> assign(:generation_error, error_msg)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:generating, false)
     |> assign(:generation_error, "Erro inesperado ao gerar avaliação")}
  end

  defp maybe_assign(socket, _key, nil), do: socket
  defp maybe_assign(socket, key, value), do: assign(socket, key, value)

  defp maybe_assign_int(socket, _key, nil), do: socket

  defp maybe_assign_int(socket, key, value) do
    case Integer.parse(value) do
      {int, _} -> assign(socket, key, int)
      :error -> socket
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
              navigate={~p"/assessments"}
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
              <h1 class="text-2xl font-bold text-slate-900 dark:text-white">Nova Avaliação</h1>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                Crie uma prova, atividade ou avaliação
              </p>
            </div>
          </div>
        </div>
      </div>
      <!-- Mode Selector -->
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4 mb-6">
          <h3 class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-3">
            Como deseja criar a avaliação?
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <button
              type="button"
              phx-click="change_mode"
              phx-value-mode="manual"
              class={"p-4 rounded-xl border-2 transition-all text-left #{if @mode == "manual", do: "border-teal-500 bg-teal-50 dark:bg-teal-900/20", else: "border-slate-200 dark:border-slate-600 hover:border-slate-300 dark:hover:border-slate-500"}"}
            >
              <div class="flex items-center gap-3 mb-2">
                <div class={"p-2 rounded-lg #{if @mode == "manual", do: "bg-teal-100 dark:bg-teal-900/40", else: "bg-slate-100 dark:bg-slate-700"}"}>
                  <svg
                    class={"w-5 h-5 #{if @mode == "manual", do: "text-teal-600 dark:text-teal-400", else: "text-slate-500"}"}
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
                <span class={"font-medium #{if @mode == "manual", do: "text-teal-700 dark:text-teal-300", else: "text-slate-700 dark:text-slate-300"}"}>
                  Manual
                </span>
              </div>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                Crie do zero preenchendo os campos
              </p>
            </button>

            <button
              type="button"
              phx-click="change_mode"
              phx-value-mode="from_planning"
              class={"p-4 rounded-xl border-2 transition-all text-left #{if @mode == "from_planning", do: "border-violet-500 bg-violet-50 dark:bg-violet-900/20", else: "border-slate-200 dark:border-slate-600 hover:border-slate-300 dark:hover:border-slate-500"}"}
            >
              <div class="flex items-center gap-3 mb-2">
                <div class={"p-2 rounded-lg #{if @mode == "from_planning", do: "bg-violet-100 dark:bg-violet-900/40", else: "bg-slate-100 dark:bg-slate-700"}"}>
                  <svg
                    class={"w-5 h-5 #{if @mode == "from_planning", do: "text-violet-600 dark:text-violet-400", else: "text-slate-500"}"}
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
                </div>
                <span class={"font-medium #{if @mode == "from_planning", do: "text-violet-700 dark:text-violet-300", else: "text-slate-700 dark:text-slate-300"}"}>
                  De Planejamento
                </span>
              </div>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                IA gera a partir de um planejamento existente
              </p>
            </button>

            <button
              type="button"
              phx-click="change_mode"
              phx-value-mode="from_topic"
              class={"p-4 rounded-xl border-2 transition-all text-left #{if @mode == "from_topic", do: "border-cyan-500 bg-cyan-50 dark:bg-cyan-900/20", else: "border-slate-200 dark:border-slate-600 hover:border-slate-300 dark:hover:border-slate-500"}"}
            >
              <div class="flex items-center gap-3 mb-2">
                <div class={"p-2 rounded-lg #{if @mode == "from_topic", do: "bg-cyan-100 dark:bg-cyan-900/40", else: "bg-slate-100 dark:bg-slate-700"}"}>
                  <svg
                    class={"w-5 h-5 #{if @mode == "from_topic", do: "text-cyan-600 dark:text-cyan-400", else: "text-slate-500"}"}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
                    />
                  </svg>
                </div>
                <span class={"font-medium #{if @mode == "from_topic", do: "text-cyan-700 dark:text-cyan-300", else: "text-slate-700 dark:text-slate-300"}"}>
                  De Tema
                </span>
              </div>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                IA gera a partir de um tema descrito
              </p>
            </button>
          </div>
        </div>
        <!-- Error Message -->
        <%= if @generation_error do %>
          <div class="mb-6 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl">
            <div class="flex items-center gap-3">
              <svg class="w-5 h-5 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <p class="text-red-700 dark:text-red-300"><%= @generation_error %></p>
            </div>
          </div>
        <% end %>
        <!-- Mode Content -->
        <%= if @mode == "manual" do %>
          <.manual_form form={@form} />
        <% end %>

        <%= if @mode == "from_planning" do %>
          <.from_planning_form
            plannings={@plannings}
            selected_planning_id={@selected_planning_id}
            assessment_type={@assessment_type}
            difficulty_level={@difficulty_level}
            num_questions={@num_questions}
            question_types={@question_types}
            generating={@generating}
          />
        <% end %>

        <%= if @mode == "from_topic" do %>
          <.from_topic_form
            topic={@topic}
            subject={@subject}
            grade_level={@grade_level}
            assessment_type={@assessment_type}
            difficulty_level={@difficulty_level}
            num_questions={@num_questions}
            question_types={@question_types}
            generating={@generating}
          />
        <% end %>
      </div>
    </div>
    """
  end

  defp manual_form(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
      <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="md:col-span-2">
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Título *
            </label>
            <input
              type="text"
              name="assessment[title]"
              value={@form[:title].value}
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
                <option value={subject} selected={@form[:subject].value == subject}>
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
                <option value={level} selected={@form[:grade_level].value == level}>
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
                <option value={type} selected={@form[:assessment_type].value == type}>
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
                <option value={level} selected={@form[:difficulty_level].value == level}>
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
              value={@form[:duration_minutes].value}
              min="15"
              max="480"
              class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
            />
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
            ><%= @form[:description].value %></textarea>
          </div>

          <div class="md:col-span-2">
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Instruções para os Alunos
            </label>
            <textarea
              name="assessment[instructions]"
              rows="3"
              placeholder="Instruções que aparecerão no início da avaliação"
              class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
            ><%= @form[:instructions].value %></textarea>
          </div>
        </div>

        <div class="flex justify-end gap-3 pt-4 border-t border-slate-200 dark:border-slate-700">
          <.link
            navigate={~p"/assessments"}
            class="px-4 py-2 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors"
          >
            Cancelar
          </.link>
          <button
            type="submit"
            class="px-6 py-2 bg-teal-600 hover:bg-teal-700 text-white font-medium rounded-lg transition-colors"
          >
            Criar Avaliação
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp from_planning_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Planning Selection -->
      <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
          Selecione o Planejamento
        </h3>

        <%= if Enum.empty?(@plannings) do %>
          <div class="text-center py-8">
            <svg
              class="w-12 h-12 mx-auto text-slate-300 mb-4"
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
            <p class="text-slate-500 dark:text-slate-400 mb-4">
              Você não tem planejamentos publicados
            </p>
            <.link navigate={~p"/plannings/new"} class="text-teal-600 hover:text-teal-700 font-medium">
              Criar um planejamento primeiro
            </.link>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3 max-h-64 overflow-y-auto">
            <%= for planning <- @plannings do %>
              <button
                type="button"
                phx-click="select_planning"
                phx-value-id={planning.id}
                class={"p-4 rounded-lg border-2 text-left transition-all #{if @selected_planning_id == planning.id, do: "border-violet-500 bg-violet-50 dark:bg-violet-900/20", else: "border-slate-200 dark:border-slate-600 hover:border-slate-300"}"}
              >
                <p class="font-medium text-slate-900 dark:text-white line-clamp-1">
                  <%= planning.title %>
                </p>
                <p class="text-sm text-slate-500 dark:text-slate-400">
                  <%= Assessment.subject_label(planning.subject) %> • <%= Assessment.grade_level_label(
                    planning.grade_level
                  ) %>
                </p>
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
      <!-- Generation Config -->
      <.generation_config
        assessment_type={@assessment_type}
        difficulty_level={@difficulty_level}
        num_questions={@num_questions}
        question_types={@question_types}
      />
      <!-- Generate Button -->
      <div class="flex justify-end gap-3">
        <.link
          navigate={~p"/assessments"}
          class="px-4 py-2 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors"
        >
          Cancelar
        </.link>
        <button
          type="button"
          phx-click="generate_from_planning"
          disabled={@generating or is_nil(@selected_planning_id)}
          class="inline-flex items-center gap-2 px-6 py-2 bg-violet-600 hover:bg-violet-700 disabled:bg-slate-400 text-white font-medium rounded-lg transition-colors"
        >
          <%= if @generating do %>
            <svg class="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
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
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
              />
            </svg>
            Gerar com IA
          <% end %>
        </button>
      </div>
    </div>
    """
  end

  defp from_topic_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Topic Input -->
      <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
          Descreva o Tema
        </h3>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
              Tema da Avaliação *
            </label>
            <textarea
              phx-change="update_topic"
              name="topic"
              rows="4"
              placeholder="Ex: Frações equivalentes e operações com frações. Incluir problemas do cotidiano que envolvam divisão de partes iguais."
              class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-teal-500"
              phx-debounce="300"
            ><%= @topic %></textarea>
            <p class="mt-1 text-xs text-slate-500">
              Quanto mais detalhado, melhor será a avaliação gerada
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                Disciplina *
              </label>
              <select
                phx-change="update_config"
                name="subject"
                class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                <%= for subject <- Assessment.subjects() do %>
                  <option value={subject} selected={@subject == subject}>
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
                phx-change="update_config"
                name="grade_level"
                class="w-full px-4 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                <%= for level <- Assessment.grade_levels() do %>
                  <option value={level} selected={@grade_level == level}>
                    <%= Assessment.grade_level_label(level) %>
                  </option>
                <% end %>
              </select>
            </div>
          </div>
        </div>
      </div>
      <!-- Generation Config -->
      <.generation_config
        assessment_type={@assessment_type}
        difficulty_level={@difficulty_level}
        num_questions={@num_questions}
        question_types={@question_types}
      />
      <!-- Generate Button -->
      <div class="flex justify-end gap-3">
        <.link
          navigate={~p"/assessments"}
          class="px-4 py-2 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors"
        >
          Cancelar
        </.link>
        <button
          type="button"
          phx-click="generate_from_topic"
          disabled={@generating or String.trim(@topic) == ""}
          class="inline-flex items-center gap-2 px-6 py-2 bg-cyan-600 hover:bg-cyan-700 disabled:bg-slate-400 text-white font-medium rounded-lg transition-colors"
        >
          <%= if @generating do %>
            <svg class="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
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
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
              />
            </svg>
            Gerar com IA
          <% end %>
        </button>
      </div>
    </div>
    """
  end

  defp generation_config(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
      <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
        Configurações da Avaliação
      </h3>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <div>
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
            Tipo
          </label>
          <select
            phx-change="update_config"
            name="assessment_type"
            class="w-full px-3 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
          >
            <%= for type <- Assessment.assessment_types() do %>
              <option value={type} selected={@assessment_type == type}>
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
            phx-change="update_config"
            name="difficulty_level"
            class="w-full px-3 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
          >
            <%= for level <- Assessment.difficulty_levels() do %>
              <option value={level} selected={@difficulty_level == level}>
                <%= Assessment.difficulty_label(level) %>
              </option>
            <% end %>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
            Nº de Questões
          </label>
          <input
            type="number"
            phx-change="update_config"
            name="num_questions"
            value={@num_questions}
            min="3"
            max="30"
            class="w-full px-3 py-2 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-900 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
          />
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
          Tipos de Questões
        </label>
        <div class="flex flex-wrap gap-2">
          <%= for type <- Assessment.question_types() do %>
            <button
              type="button"
              phx-click="toggle_question_type"
              phx-value-type={type}
              class={"px-3 py-1.5 rounded-lg text-sm font-medium transition-colors #{if type in @question_types, do: "bg-teal-100 text-teal-700 dark:bg-teal-900/40 dark:text-teal-300", else: "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-400 hover:bg-slate-200"}"}
            >
              <%= Assessment.question_type_label(type) %>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
