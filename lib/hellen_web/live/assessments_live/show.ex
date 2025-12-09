defmodule HellenWeb.AssessmentsLive.Show do
  @moduledoc """
  LiveView for displaying assessment details and questions.
  """

  use HellenWeb, :live_view

  alias Hellen.Assessments
  alias Hellen.Assessments.Assessment

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    assessment = Assessments.get_assessment_with_preloads!(id)

    {:ok,
     socket
     |> assign(:page_title, assessment.title)
     |> assign(:assessment, assessment)
     |> assign(:show_answers, false)
     |> assign(:active_tab, "questions")}
  end

  @impl true
  def handle_event("toggle_answers", _params, socket) do
    {:noreply, assign(socket, :show_answers, !socket.assigns.show_answers)}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("publish", _params, socket) do
    case Assessments.publish_assessment(socket.assigns.assessment) do
      {:ok, assessment} ->
        {:noreply,
         socket
         |> assign(:assessment, assessment)
         |> put_flash(:info, "Avaliação publicada!")}

      {:error, changeset} ->
        error_msg = error_message(changeset)
        {:noreply, put_flash(socket, :error, error_msg)}
    end
  end

  @impl true
  def handle_event("archive", _params, socket) do
    case Assessments.archive_assessment(socket.assigns.assessment) do
      {:ok, assessment} ->
        {:noreply,
         socket
         |> assign(:assessment, assessment)
         |> put_flash(:info, "Avaliação arquivada!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao arquivar")}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Assessments.delete_assessment(socket.assigns.assessment) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Avaliação excluída!")
         |> push_navigate(to: ~p"/assessments")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao excluir")}
    end
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
        <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex items-start justify-between gap-4">
            <div class="flex items-start gap-4">
              <.link
                navigate={~p"/assessments"}
                class="mt-1 p-2 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700"
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
                <div class="flex items-center gap-3 mb-2">
                  <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_color(@assessment.status)}"}>
                    <%= Assessment.status_label(@assessment.status) %>
                  </span>
                  <span class={"text-sm #{type_color(@assessment.assessment_type)}"}>
                    <%= Assessment.assessment_type_label(@assessment.assessment_type) %>
                  </span>
                  <%= if @assessment.generated_by_ai do %>
                    <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-violet-100 dark:bg-violet-900/30 text-violet-600 dark:text-violet-400 rounded text-xs">
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
                        />
                      </svg>
                      IA
                    </span>
                  <% end %>
                </div>
                <h1 class="text-2xl font-bold text-slate-900 dark:text-white">
                  <%= @assessment.title %>
                </h1>
                <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                  <%= Assessment.subject_label(@assessment.subject) %> • <%= Assessment.grade_level_label(
                    @assessment.grade_level
                  ) %>
                </p>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <%= if @assessment.status == "draft" do %>
                <button
                  type="button"
                  phx-click="publish"
                  class="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-medium rounded-lg transition-colors text-sm"
                >
                  Publicar
                </button>
              <% end %>

              <.link
                navigate={~p"/assessments/#{@assessment.id}/edit"}
                class="px-4 py-2 bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-300 font-medium rounded-lg transition-colors text-sm"
              >
                Editar
              </.link>

              <div class="relative" x-data="{ open: false }">
                <button
                  type="button"
                  @click="open = !open"
                  class="p-2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg"
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
                  x-show="open"
                  @click.away="open = false"
                  x-transition
                  class="absolute right-0 mt-2 w-48 bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-slate-200 dark:border-slate-700 py-1 z-10"
                >
                  <button
                    type="button"
                    @click="window.print(); open = false"
                    class="w-full px-4 py-2 text-left text-sm text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
                  >
                    Imprimir
                  </button>
                  <%= if @assessment.status != "archived" do %>
                    <button
                      type="button"
                      phx-click="archive"
                      @click="open = false"
                      class="w-full px-4 py-2 text-left text-sm text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
                    >
                      Arquivar
                    </button>
                  <% end %>
                  <button
                    type="button"
                    phx-click="delete"
                    @click="open = false"
                    data-confirm="Tem certeza que deseja excluir esta avaliação?"
                    class="w-full px-4 py-2 text-left text-sm text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20"
                  >
                    Excluir
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <!-- Stats -->
      <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <p class="text-2xl font-bold text-slate-900 dark:text-white">
              <%= length(@assessment.questions || []) %>
            </p>
            <p class="text-sm text-slate-500">Questões</p>
          </div>
          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <p class="text-2xl font-bold text-slate-900 dark:text-white">
              <%= @assessment.total_points || 0 %>
            </p>
            <p class="text-sm text-slate-500">Pontos</p>
          </div>
          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <p class="text-2xl font-bold text-slate-900 dark:text-white">
              <%= @assessment.duration_minutes || "-" %>
            </p>
            <p class="text-sm text-slate-500">Minutos</p>
          </div>
          <div class="bg-white dark:bg-slate-800 rounded-xl p-4 border border-slate-200 dark:border-slate-700">
            <p class="text-2xl font-bold text-slate-900 dark:text-white">
              <%= Assessment.difficulty_label(@assessment.difficulty_level) %>
            </p>
            <p class="text-sm text-slate-500">Dificuldade</p>
          </div>
        </div>
        <!-- Tabs -->
        <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden">
          <div class="border-b border-slate-200 dark:border-slate-700">
            <nav class="flex -mb-px">
              <button
                type="button"
                phx-click="change_tab"
                phx-value-tab="questions"
                class={"px-6 py-3 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "questions", do: "border-teal-500 text-teal-600 dark:text-teal-400", else: "border-transparent text-slate-500 hover:text-slate-700 dark:hover:text-slate-300"}"}
              >
                Questões
              </button>
              <button
                type="button"
                phx-click="change_tab"
                phx-value-tab="info"
                class={"px-6 py-3 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "info", do: "border-teal-500 text-teal-600 dark:text-teal-400", else: "border-transparent text-slate-500 hover:text-slate-700 dark:hover:text-slate-300"}"}
              >
                Informações
              </button>
              <button
                type="button"
                phx-click="change_tab"
                phx-value-tab="rubrics"
                class={"px-6 py-3 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "rubrics", do: "border-teal-500 text-teal-600 dark:text-teal-400", else: "border-transparent text-slate-500 hover:text-slate-700 dark:hover:text-slate-300"}"}
              >
                Gabarito e Rubricas
              </button>
            </nav>
          </div>

          <div class="p-6">
            <%= if @active_tab == "questions" do %>
              <.questions_tab assessment={@assessment} show_answers={@show_answers} />
            <% end %>

            <%= if @active_tab == "info" do %>
              <.info_tab assessment={@assessment} />
            <% end %>

            <%= if @active_tab == "rubrics" do %>
              <.rubrics_tab assessment={@assessment} />
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp questions_tab(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-slate-900 dark:text-white">
          Questões (<%= length(@assessment.questions || []) %>)
        </h3>
        <button
          type="button"
          phx-click="toggle_answers"
          class={"px-3 py-1.5 rounded-lg text-sm font-medium transition-colors #{if @show_answers, do: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400", else: "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-400"}"}
        >
          <%= if @show_answers, do: "Ocultar Respostas", else: "Mostrar Respostas" %>
        </button>
      </div>

      <%= if Enum.empty?(@assessment.questions || []) do %>
        <div class="text-center py-12">
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
              d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <p class="text-slate-500 dark:text-slate-400">
            Nenhuma questão cadastrada
          </p>
        </div>
      <% else %>
        <div class="space-y-6">
          <%= for {question, index} <- Enum.with_index(@assessment.questions || []) do %>
            <.question_card question={question} index={index} show_answer={@show_answers} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp question_card(assigns) do
    ~H"""
    <div class="p-4 bg-slate-50 dark:bg-slate-700/50 rounded-xl">
      <div class="flex items-start gap-4">
        <div class="flex-shrink-0 w-8 h-8 bg-teal-100 dark:bg-teal-900/40 rounded-full flex items-center justify-center">
          <span class="text-sm font-bold text-teal-600 dark:text-teal-400"><%= @index + 1 %></span>
        </div>
        <div class="flex-1">
          <div class="flex items-center gap-2 mb-2">
            <span class={"px-2 py-0.5 rounded text-xs font-medium #{question_type_color(@question["type"])}"}>
              <%= Assessment.question_type_label(@question["type"]) %>
            </span>
            <span class="text-xs text-slate-500">
              <%= @question["points"] || 1 %> ponto(s)
            </span>
            <%= if @question["difficulty"] do %>
              <span class="text-xs text-slate-400">
                • <%= difficulty_label(@question["difficulty"]) %>
              </span>
            <% end %>
          </div>

          <p class="text-slate-900 dark:text-white mb-3 whitespace-pre-wrap">
            <%= @question["text"] %>
          </p>

          <%= case @question["type"] do %>
            <% "multiple_choice" -> %>
              <div class="space-y-2 ml-4">
                <%= for option <- @question["options"] || [] do %>
                  <div class={"flex items-center gap-2 p-2 rounded #{if @show_answer and String.starts_with?(option, @question["correct_answer"] <> ")"), do: "bg-emerald-100 dark:bg-emerald-900/30", else: ""}"}>
                    <span class="text-slate-700 dark:text-slate-300"><%= option %></span>
                  </div>
                <% end %>
              </div>
            <% "true_false" -> %>
              <div class="flex gap-4 ml-4">
                <span class={"px-3 py-1 rounded #{if @show_answer and @question["correct_answer"] == true, do: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400", else: "bg-slate-200 dark:bg-slate-600 text-slate-700 dark:text-slate-300"}"}>
                  Verdadeiro
                </span>
                <span class={"px-3 py-1 rounded #{if @show_answer and @question["correct_answer"] == false, do: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400", else: "bg-slate-200 dark:bg-slate-600 text-slate-700 dark:text-slate-300"}"}>
                  Falso
                </span>
              </div>
            <% "matching" -> %>
              <div class="grid grid-cols-2 gap-4 ml-4">
                <div>
                  <p class="text-xs font-medium text-slate-500 mb-2">Coluna A</p>
                  <%= for {item, idx} <- Enum.with_index(@question["left_column"] || []) do %>
                    <div class="p-2 bg-white dark:bg-slate-800 rounded mb-1 text-sm">
                      <%= idx + 1 %>. <%= item %>
                    </div>
                  <% end %>
                </div>
                <div>
                  <p class="text-xs font-medium text-slate-500 mb-2">Coluna B</p>
                  <%= for {item, idx} <- Enum.with_index(@question["right_column"] || []) do %>
                    <div class="p-2 bg-white dark:bg-slate-800 rounded mb-1 text-sm">
                      <%= <<65 + idx>> %>. <%= item %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% "fill_blank" -> %>
              <div class="ml-4 text-sm text-slate-500">
                Preencher lacunas
              </div>
            <% "short_answer" -> %>
              <div class="ml-4 p-3 bg-white dark:bg-slate-800 rounded border border-dashed border-slate-300 dark:border-slate-600">
                <p class="text-xs text-slate-400">Espaço para resposta curta</p>
              </div>
            <% "essay" -> %>
              <div class="ml-4 p-3 bg-white dark:bg-slate-800 rounded border border-dashed border-slate-300 dark:border-slate-600 min-h-[100px]">
                <p class="text-xs text-slate-400">Espaço para resposta dissertativa</p>
              </div>
            <% _ -> %>
              <div></div>
          <% end %>

          <%= if @show_answer and @question["explanation"] do %>
            <div class="mt-4 p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800">
              <p class="text-xs font-medium text-blue-700 dark:text-blue-300 mb-1">Explicação:</p>
              <p class="text-sm text-blue-600 dark:text-blue-400"><%= @question["explanation"] %></p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp info_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @assessment.description do %>
        <div>
          <h4 class="text-sm font-medium text-slate-500 dark:text-slate-400 mb-2">Descrição</h4>
          <p class="text-slate-900 dark:text-white"><%= @assessment.description %></p>
        </div>
      <% end %>

      <%= if @assessment.instructions do %>
        <div>
          <h4 class="text-sm font-medium text-slate-500 dark:text-slate-400 mb-2">Instruções</h4>
          <p class="text-slate-900 dark:text-white whitespace-pre-wrap">
            <%= @assessment.instructions %>
          </p>
        </div>
      <% end %>

      <%= if not Enum.empty?(@assessment.bncc_codes || []) do %>
        <div>
          <h4 class="text-sm font-medium text-slate-500 dark:text-slate-400 mb-2">Códigos BNCC</h4>
          <div class="flex flex-wrap gap-2">
            <%= for code <- @assessment.bncc_codes do %>
              <span class="px-3 py-1 bg-teal-100 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300 rounded-full text-sm font-medium">
                <%= code %>
              </span>
            <% end %>
          </div>
        </div>
      <% end %>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <h4 class="text-sm font-medium text-slate-500 dark:text-slate-400 mb-1">Criado em</h4>
          <p class="text-slate-900 dark:text-white">
            <%= Calendar.strftime(@assessment.inserted_at, "%d/%m/%Y às %H:%M") %>
          </p>
        </div>
        <div>
          <h4 class="text-sm font-medium text-slate-500 dark:text-slate-400 mb-1">Atualizado em</h4>
          <p class="text-slate-900 dark:text-white">
            <%= Calendar.strftime(@assessment.updated_at, "%d/%m/%Y às %H:%M") %>
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp rubrics_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h4 class="text-sm font-medium text-slate-500 dark:text-slate-400 mb-3">Gabarito</h4>
        <%= if Enum.empty?(@assessment.answer_key || %{}) do %>
          <p class="text-slate-400">Nenhum gabarito definido</p>
        <% else %>
          <div class="bg-slate-50 dark:bg-slate-700/50 rounded-lg p-4">
            <div class="grid grid-cols-5 gap-2">
              <%= for {key, value} <- @assessment.answer_key || %{} do %>
                <div class="text-center p-2 bg-white dark:bg-slate-800 rounded">
                  <p class="text-xs text-slate-500">Q<%= String.to_integer(key) + 1 %></p>
                  <p class="font-bold text-slate-900 dark:text-white"><%= value %></p>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <div>
        <h4 class="text-sm font-medium text-slate-500 dark:text-slate-400 mb-3">
          Rubricas de Avaliação
        </h4>
        <%= if Enum.empty?(@assessment.rubrics || %{}) do %>
          <p class="text-slate-400">Nenhuma rubrica definida</p>
        <% else %>
          <div class="space-y-3">
            <%= if @assessment.rubrics["general"] do %>
              <div class="p-4 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
                <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Critérios Gerais
                </p>
                <p class="text-slate-600 dark:text-slate-400">
                  <%= @assessment.rubrics["general"] %>
                </p>
              </div>
            <% end %>
            <%= if @assessment.rubrics["partial_credit"] do %>
              <div class="p-4 bg-slate-50 dark:bg-slate-700/50 rounded-lg">
                <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Crédito Parcial
                </p>
                <p class="text-slate-600 dark:text-slate-400">
                  <%= @assessment.rubrics["partial_credit"] %>
                </p>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp status_color("draft"),
    do: "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400"

  defp status_color("published"),
    do: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400"

  defp status_color("archived"),
    do: "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-400"

  defp status_color(_), do: "bg-slate-100 text-slate-600"

  defp type_color("prova"), do: "text-teal-600 dark:text-teal-400"
  defp type_color("simulado"), do: "text-violet-600 dark:text-violet-400"
  defp type_color("quiz"), do: "text-pink-600 dark:text-pink-400"
  defp type_color(_), do: "text-slate-600 dark:text-slate-400"

  defp question_type_color("multiple_choice"),
    do: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400"

  defp question_type_color("true_false"),
    do: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400"

  defp question_type_color("short_answer"),
    do: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"

  defp question_type_color("essay"),
    do: "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400"

  defp question_type_color("matching"),
    do: "bg-cyan-100 text-cyan-700 dark:bg-cyan-900/30 dark:text-cyan-400"

  defp question_type_color("fill_blank"),
    do: "bg-pink-100 text-pink-700 dark:bg-pink-900/30 dark:text-pink-400"

  defp question_type_color(_),
    do: "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300"

  defp difficulty_label("facil"), do: "Fácil"
  defp difficulty_label("medio"), do: "Médio"
  defp difficulty_label("dificil"), do: "Difícil"
  defp difficulty_label(_), do: ""
end
