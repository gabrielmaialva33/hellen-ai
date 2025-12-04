defmodule HellenWeb.LessonLive.Show do
  @moduledoc """
  Lesson details LiveView with analysis, score evolution chart, and trend indicators.
  """
  use HellenWeb, :live_view

  alias Hellen.Analysis
  alias Hellen.Lessons

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user
    lesson = Lessons.get_lesson_with_transcription!(id, user.institution_id)
    analyses = Analysis.list_analyses_by_lesson(id, user.institution_id)
    latest_analysis = List.first(analyses)

    # Subscribe to real-time updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Hellen.PubSub, "lesson:#{id}")
    end

    {:ok,
     socket
     |> assign(page_title: lesson.title || "Detalhes da Aula")
     |> assign(lesson: lesson)
     |> assign(analyses: analyses)
     |> assign(latest_analysis: latest_analysis)
     |> assign(show_analysis: socket.assigns.live_action == :analysis)
     |> load_analytics_async(user, lesson)}
  end

  defp load_analytics_async(socket, user, lesson) do
    if connected?(socket) do
      start_async(socket, :load_analytics, fn ->
        score_history = Analysis.get_user_score_history(user.id)
        {trend, trend_change} = Analysis.get_user_trend(user.id)

        discipline_avg =
          if lesson.subject && user.institution_id do
            Analysis.get_discipline_average(lesson.subject, user.institution_id)
          end

        bncc_coverage = Analysis.get_bncc_coverage(user.id, limit: 20)

        %{
          score_history: score_history,
          trend: trend,
          trend_change: trend_change,
          discipline_avg: discipline_avg,
          bncc_coverage: bncc_coverage
        }
      end)
    else
      socket
      |> assign(score_history: [])
      |> assign(trend: :stable)
      |> assign(trend_change: 0.0)
      |> assign(discipline_avg: nil)
      |> assign(bncc_coverage: [])
    end
  end

  @impl true
  def handle_async(:load_analytics, {:ok, analytics}, socket) do
    {:noreply,
     socket
     |> assign(score_history: analytics.score_history)
     |> assign(trend: analytics.trend)
     |> assign(trend_change: analytics.trend_change)
     |> assign(discipline_avg: analytics.discipline_avg)
     |> assign(bncc_coverage: analytics.bncc_coverage)}
  end

  def handle_async(:load_analytics, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(score_history: [])
     |> assign(trend: :stable)
     |> assign(trend_change: 0.0)
     |> assign(discipline_avg: nil)
     |> assign(bncc_coverage: [])}
  end

  @impl true
  def handle_params(%{"id" => _id}, _uri, socket) do
    {:noreply, assign(socket, show_analysis: socket.assigns.live_action == :analysis)}
  end

  @impl true
  def handle_info({"transcription_progress", %{progress: progress}}, socket) do
    {:noreply, assign(socket, transcription_progress: progress)}
  end

  @impl true
  def handle_info({"transcription_complete", _payload}, socket) do
    lesson = Lessons.get_lesson_with_transcription!(socket.assigns.lesson.id)
    {:noreply, assign(socket, lesson: lesson, transcription_progress: 100)}
  end

  @impl true
  def handle_info({"analysis_progress", %{progress: progress}}, socket) do
    {:noreply, assign(socket, analysis_progress: progress)}
  end

  @impl true
  def handle_info({"analysis_complete", %{analysis: analysis}}, socket) do
    lesson = %{socket.assigns.lesson | status: "completed"}
    analyses = [analysis | socket.assigns.analyses]

    {:noreply,
     socket
     |> assign(lesson: lesson, analyses: analyses, latest_analysis: analysis)
     |> put_flash(:info, "Análise concluída!")}
  end

  @impl true
  def handle_info({"status_update", %{status: status}}, socket) do
    lesson = %{socket.assigns.lesson | status: status}
    {:noreply, assign(socket, lesson: lesson)}
  end

  @impl true
  def handle_info({"transcription_failed", %{error: error}}, socket) do
    lesson = %{socket.assigns.lesson | status: "failed"}

    {:noreply,
     socket
     |> assign(lesson: lesson)
     |> put_flash(:error, "Transcrição falhou: #{error}")}
  end

  @impl true
  def handle_info({"analysis_failed", %{error: error}}, socket) do
    lesson = %{socket.assigns.lesson | status: "failed"}

    {:noreply,
     socket
     |> assign(lesson: lesson)
     |> put_flash(:error, "Análise falhou: #{error}")}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_processing", _params, socket) do
    lesson = socket.assigns.lesson
    user = socket.assigns.current_user

    case Lessons.start_processing(lesson, user) do
      {:ok, updated_lesson} ->
        {:noreply,
         socket
         |> assign(lesson: updated_lesson)
         |> put_flash(:info, "Processamento iniciado!")}

      {:error, :insufficient_credits} ->
        {:noreply, put_flash(socket, :error, "Créditos insuficientes")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Erro ao iniciar: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Header -->
      <div class="flex justify-between items-start">
        <div>
          <.link
            navigate={~p"/aulas"}
            class="text-sm text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 flex items-center mb-2"
          >
            <.icon name="hero-arrow-left-mini" class="h-4 w-4 mr-1" /> Voltar para Minhas Aulas
          </.link>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
            <%= @lesson.title || "Aula sem título" %>
          </h1>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
            <%= @lesson.subject || "Disciplina não informada" %> • <%= format_datetime(
              @lesson.inserted_at
            ) %>
          </p>
        </div>
        <div class="flex items-center gap-3">
          <!-- Trend Indicator -->
          <.trend_indicator
            :if={assigns[:trend] && @lesson.status == "completed"}
            trend={@trend}
            change={@trend_change}
          />
          <.badge variant={status_variant(@lesson.status)} class="text-sm px-3 py-1">
            <%= status_label(@lesson.status) %>
          </.badge>
        </div>
      </div>
      <!-- Pending State -->
      <div :if={@lesson.status == "pending"} class="text-center py-8">
        <.card>
          <div class="py-6">
            <.icon name="hero-play-circle" class="mx-auto h-16 w-16 text-indigo-400" />
            <h3 class="mt-4 text-lg font-semibold text-gray-900 dark:text-white">
              Pronto para processar
            </h3>
            <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
              Clique no botão abaixo para iniciar a transcrição e análise da aula.
            </p>
            <div class="mt-6">
              <.button phx-click="start_processing">
                <.icon name="hero-play" class="h-4 w-4 mr-2" /> Iniciar Processamento
              </.button>
            </div>
          </div>
        </.card>
      </div>
      <!-- Processing State -->
      <div :if={@lesson.status in ["transcribing", "analyzing"]} class="text-center py-8">
        <.card>
          <div class="py-6">
            <div class="mx-auto h-16 w-16 text-indigo-400 animate-spin">
              <.icon name="hero-arrow-path" class="h-16 w-16" />
            </div>
            <h3 class="mt-4 text-lg font-semibold text-gray-900 dark:text-white">
              <%= if @lesson.status == "transcribing", do: "Transcrevendo...", else: "Analisando..." %>
            </h3>
            <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
              <%= if @lesson.status == "transcribing",
                do: "Convertendo áudio em texto usando IA",
                else: "Gerando feedback pedagógico baseado na BNCC" %>
            </p>
            <div class="mt-6 max-w-md mx-auto">
              <.progress value={assigns[:transcription_progress] || assigns[:analysis_progress] || 0} />
            </div>
          </div>
        </.card>
      </div>
      <!-- Failed State -->
      <div :if={@lesson.status == "failed"}>
        <.alert variant="error" title="Erro no processamento">
          Ocorreu um erro ao processar esta aula. O crédito foi reembolsado automaticamente.
          Você pode tentar novamente.
        </.alert>
      </div>
      <!-- Completed State - Main Content -->
      <div :if={@lesson.status in ["transcribed", "completed"]} class="space-y-8">
        <!-- Score Evolution Chart -->
        <.card :if={assigns[:score_history] && length(@score_history) > 1}>
          <:header>
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
                  Evolução do Score
                </h2>
                <p class="text-sm text-gray-500 dark:text-gray-400">
                  Histórico de pontuações das suas aulas
                </p>
              </div>
              <.trend_badge :if={assigns[:trend]} trend={@trend} change={@trend_change} />
            </div>
          </:header>
          <div
            id="score-chart"
            phx-hook="ScoreChart"
            phx-update="ignore"
            data-chart-data={Jason.encode!(@score_history)}
            data-average={@discipline_avg || 0}
          >
          </div>
          <div
            :if={@discipline_avg}
            class="mt-4 pt-4 border-t border-gray-200 dark:border-slate-700 flex items-center justify-center gap-6 text-sm"
          >
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 rounded-full bg-indigo-500"></div>
              <span class="text-gray-600 dark:text-gray-400">Suas Aulas</span>
            </div>
            <div class="flex items-center gap-2">
              <div class="w-3 h-0.5 bg-amber-500"></div>
              <span class="text-gray-600 dark:text-gray-400">
                Média da Disciplina: <%= round((@discipline_avg || 0) * 100) %>%
              </span>
            </div>
          </div>
        </.card>
        <!-- Transcription & Analysis Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Transcription -->
          <.card>
            <:header>
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Transcrição</h2>
                <.badge variant="success">Concluída</.badge>
              </div>
            </:header>
            <div
              :if={@lesson.transcription}
              class="prose prose-sm dark:prose-invert max-w-none max-h-96 overflow-y-auto"
            >
              <p class="whitespace-pre-wrap text-gray-700 dark:text-gray-300">
                <%= @lesson.transcription.full_text %>
              </p>
            </div>
            <div :if={!@lesson.transcription} class="text-gray-500 dark:text-gray-400 text-sm">
              Transcrição não disponível
            </div>
          </.card>
          <!-- Analysis -->
          <.card>
            <:header>
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
                  Análise Pedagógica
                </h2>
                <.badge :if={@latest_analysis} variant="success">Concluída</.badge>
                <.badge :if={!@latest_analysis && @lesson.status == "completed"} variant="pending">
                  Pendente
                </.badge>
              </div>
            </:header>

            <div :if={@latest_analysis} class="space-y-4">
              <div :if={@latest_analysis.overall_score} class="flex items-center justify-center">
                <.score_display
                  score={round(@latest_analysis.overall_score * 100)}
                  label="Pontuação Geral"
                />
              </div>

              <div :if={@latest_analysis.result} class="space-y-4">
                <.analysis_section
                  :if={@latest_analysis.result["feedback"]}
                  title="Feedback"
                  icon="hero-chat-bubble-left-right"
                >
                  <%= @latest_analysis.result["feedback"] %>
                </.analysis_section>

                <.analysis_section
                  :if={@latest_analysis.result["strengths"]}
                  title="Pontos Fortes"
                  icon="hero-check-circle"
                >
                  <ul class="list-disc list-inside space-y-1">
                    <li
                      :for={strength <- @latest_analysis.result["strengths"]}
                      class="text-sm text-gray-700 dark:text-gray-300"
                    >
                      <%= strength %>
                    </li>
                  </ul>
                </.analysis_section>

                <.analysis_section
                  :if={@latest_analysis.result["improvements"]}
                  title="Sugestões de Melhoria"
                  icon="hero-light-bulb"
                >
                  <ul class="list-disc list-inside space-y-1">
                    <li
                      :for={improvement <- @latest_analysis.result["improvements"]}
                      class="text-sm text-gray-700 dark:text-gray-300"
                    >
                      <%= improvement %>
                    </li>
                  </ul>
                </.analysis_section>
              </div>
            </div>

            <div :if={!@latest_analysis} class="text-center py-6 text-gray-500 dark:text-gray-400">
              <.icon
                name="hero-document-magnifying-glass"
                class="mx-auto h-12 w-12 text-gray-300 dark:text-gray-600"
              />
              <p class="mt-2 text-sm">Análise não disponível</p>
            </div>
          </.card>
        </div>
        <!-- BNCC Coverage -->
        <.card :if={assigns[:bncc_coverage] && length(@bncc_coverage) > 0}>
          <:header>
            <div>
              <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
                Competências BNCC Trabalhadas
              </h2>
              <p class="text-sm text-gray-500 dark:text-gray-400">
                Frequência das competências identificadas em suas aulas
              </p>
            </div>
          </:header>
          <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <div
              :for={comp <- @bncc_coverage}
              class="p-3 rounded-lg bg-gray-50 dark:bg-slate-800 border border-gray-200 dark:border-slate-700"
            >
              <div class="flex items-center justify-between mb-1">
                <span class="text-xs font-mono text-indigo-600 dark:text-indigo-400">
                  <%= comp.code %>
                </span>
                <span class="text-xs text-gray-500 dark:text-gray-400">
                  <%= comp.count %>x
                </span>
              </div>
              <p class="text-sm text-gray-700 dark:text-gray-300 line-clamp-2">
                <%= comp.name || "Competência BNCC" %>
              </p>
              <div class="mt-2 h-1.5 bg-gray-200 dark:bg-slate-700 rounded-full overflow-hidden">
                <div
                  class="h-full bg-gradient-to-r from-indigo-500 to-purple-500 rounded-full"
                  style={"width: #{round((comp.avg_score || 0) * 100)}%"}
                >
                </div>
              </div>
            </div>
          </div>
        </.card>
      </div>
    </div>
    """
  end

  # Trend indicator component
  defp trend_indicator(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-1 px-2 py-1 rounded-full text-sm font-medium",
      @trend == :improving && "bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400",
      @trend == :declining && "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400",
      @trend == :stable && "bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-400"
    ]}>
      <.icon
        :if={@trend == :improving}
        name="hero-arrow-trending-up"
        class="h-4 w-4 text-green-600 dark:text-green-400"
      />
      <.icon
        :if={@trend == :declining}
        name="hero-arrow-trending-down"
        class="h-4 w-4 text-red-600 dark:text-red-400"
      />
      <.icon
        :if={@trend == :stable}
        name="hero-minus"
        class="h-4 w-4 text-gray-500 dark:text-gray-400"
      />
      <span :if={abs(@change) > 0}>
        <%= if @change > 0, do: "+", else: "" %><%= Float.round(@change, 1) %>%
      </span>
    </div>
    """
  end

  # Trend badge for chart header
  defp trend_badge(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-1 px-3 py-1.5 rounded-lg text-sm font-medium",
      @trend == :improving && "bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400",
      @trend == :declining && "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400",
      @trend == :stable && "bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-400"
    ]}>
      <.icon
        :if={@trend == :improving}
        name="hero-arrow-trending-up"
        class="h-5 w-5 text-green-600 dark:text-green-400"
      />
      <.icon
        :if={@trend == :declining}
        name="hero-arrow-trending-down"
        class="h-5 w-5 text-red-600 dark:text-red-400"
      />
      <.icon
        :if={@trend == :stable}
        name="hero-minus"
        class="h-5 w-5 text-gray-500 dark:text-gray-400"
      />
      <span>
        <%= case @trend do
          :improving -> "Melhorando"
          :declining -> "Em queda"
          :stable -> "Estável"
        end %>
      </span>
    </div>
    """
  end
end
