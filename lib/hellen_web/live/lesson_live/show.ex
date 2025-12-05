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
    <div class="space-y-8 animate-fade-in">
      <!-- Header -->
      <div class="flex flex-col sm:flex-row justify-between items-start gap-4">
        <div>
          <.link
            navigate={~p"/aulas"}
            class="text-sm text-slate-500 dark:text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 flex items-center mb-3 transition-colors"
          >
            <.icon name="hero-arrow-left-mini" class="h-4 w-4 mr-1" /> Voltar para Minhas Aulas
          </.link>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900 dark:text-white tracking-tight">
            <%= @lesson.title || "Aula sem titulo" %>
          </h1>
          <p class="mt-2 text-sm text-slate-500 dark:text-slate-400 flex items-center gap-3">
            <span class="flex items-center gap-1.5">
              <.icon name="hero-academic-cap" class="h-4 w-4" />
              <%= @lesson.subject || "Disciplina nao informada" %>
            </span>
            <span class="flex items-center gap-1.5">
              <.icon name="hero-calendar" class="h-4 w-4" />
              <%= format_datetime(@lesson.inserted_at) %>
            </span>
          </p>
        </div>
        <div class="flex items-center gap-3">
          <!-- Trend Indicator -->
          <.trend_indicator
            :if={assigns[:trend] && @lesson.status == "completed"}
            trend={@trend}
            change={@trend_change}
          />
          <.badge variant={status_variant(@lesson.status)} class="text-sm px-3 py-1.5">
            <%= status_label(@lesson.status) %>
          </.badge>
        </div>
      </div>

      <!-- Pending State -->
      <div :if={@lesson.status == "pending"} class="animate-fade-in-up">
        <.card>
          <div class="py-8 text-center">
            <div class="inline-flex items-center justify-center w-20 h-20 rounded-2xl bg-teal-100 dark:bg-teal-900/30 mb-4">
              <.icon name="hero-play-circle" class="h-10 w-10 text-teal-600 dark:text-teal-400" />
            </div>
            <h3 class="text-xl font-semibold text-slate-900 dark:text-white">
              Pronto para processar
            </h3>
            <p class="mt-2 text-sm text-slate-500 dark:text-slate-400 max-w-md mx-auto">
              Clique no botao abaixo para iniciar a transcricao e analise pedagogica da aula.
            </p>
            <div class="mt-6">
              <.button phx-click="start_processing" icon="hero-play">
                Iniciar Processamento
              </.button>
            </div>
          </div>
        </.card>
      </div>

      <!-- Processing State -->
      <div :if={@lesson.status in ["transcribing", "analyzing"]} class="animate-fade-in-up">
        <.card>
          <div class="py-8 text-center">
            <div class="inline-flex items-center justify-center w-20 h-20 rounded-2xl bg-cyan-100 dark:bg-cyan-900/30 mb-4">
              <.icon name="hero-arrow-path" class="h-10 w-10 text-cyan-600 dark:text-cyan-400 animate-spin" />
            </div>
            <h3 class="text-xl font-semibold text-slate-900 dark:text-white">
              <%= if @lesson.status == "transcribing", do: "Transcrevendo...", else: "Analisando..." %>
            </h3>
            <p class="mt-2 text-sm text-slate-500 dark:text-slate-400 max-w-md mx-auto">
              <%= if @lesson.status == "transcribing",
                do: "Convertendo audio em texto usando IA",
                else: "Gerando feedback pedagogico baseado na BNCC" %>
            </p>
            <div class="mt-6 max-w-md mx-auto">
              <.progress value={assigns[:transcription_progress] || assigns[:analysis_progress] || 0} color="teal" />
            </div>
          </div>
        </.card>
      </div>

      <!-- Failed State -->
      <div :if={@lesson.status == "failed"} class="animate-fade-in-up">
        <.alert variant="error" title="Erro no processamento">
          Ocorreu um erro ao processar esta aula. O credito foi reembolsado automaticamente.
          Voce pode tentar novamente.
        </.alert>
      </div>

      <!-- Completed State - Main Content -->
      <div :if={@lesson.status in ["transcribed", "completed"]} class="space-y-8">
        <!-- Score Evolution Chart -->
        <.card :if={assigns[:score_history] && length(@score_history) > 1} class="animate-fade-in-up">
          <:header>
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-lg font-semibold text-slate-900 dark:text-white">
                  Evolucao do Score
                </h2>
                <p class="text-sm text-slate-500 dark:text-slate-400">
                  Historico de pontuacoes das suas aulas
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
            class="min-h-[300px]"
          >
          </div>
          <div
            :if={@discipline_avg}
            class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700 flex items-center justify-center gap-6 text-sm"
          >
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 rounded-full bg-teal-500"></div>
              <span class="text-slate-600 dark:text-slate-400">Suas Aulas</span>
            </div>
            <div class="flex items-center gap-2">
              <div class="w-3 h-0.5 bg-ochre-500"></div>
              <span class="text-slate-600 dark:text-slate-400">
                Media da Disciplina: <%= round((@discipline_avg || 0) * 100) %>%
              </span>
            </div>
          </div>
        </.card>

        <!-- Transcription & Analysis Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- Transcription -->
          <.card class="animate-fade-in-up">
            <:header>
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <.icon name="hero-document-text" class="h-5 w-5 text-teal-600 dark:text-teal-400" />
                  <h2 class="text-lg font-semibold text-slate-900 dark:text-white">Transcricao</h2>
                </div>
                <.badge variant="completed">Concluida</.badge>
              </div>
            </:header>
            <div
              :if={@lesson.transcription}
              class="prose prose-sm dark:prose-invert max-w-none max-h-96 overflow-y-auto scrollbar-thin scrollbar-thumb-slate-300 dark:scrollbar-thumb-slate-600"
            >
              <p class="whitespace-pre-wrap text-slate-700 dark:text-slate-300 leading-relaxed">
                <%= @lesson.transcription.full_text %>
              </p>
            </div>
            <div :if={!@lesson.transcription} class="text-center py-8">
              <.icon name="hero-document-text" class="mx-auto h-12 w-12 text-slate-300 dark:text-slate-600" />
              <p class="mt-2 text-sm text-slate-500 dark:text-slate-400">Transcricao nao disponivel</p>
            </div>
          </.card>

          <!-- Analysis -->
          <.card class="animate-fade-in-up" style="animation-delay: 100ms">
            <:header>
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <.icon name="hero-chart-bar" class="h-5 w-5 text-sage-600 dark:text-sage-400" />
                  <h2 class="text-lg font-semibold text-slate-900 dark:text-white">
                    Analise Pedagogica
                  </h2>
                </div>
                <.badge :if={@latest_analysis} variant="completed">Concluida</.badge>
                <.badge :if={!@latest_analysis && @lesson.status == "completed"} variant="pending">
                  Pendente
                </.badge>
              </div>
            </:header>

            <div :if={@latest_analysis} class="space-y-5">
              <div :if={@latest_analysis.overall_score} class="flex items-center justify-center py-2">
                <.score_display
                  score={round(@latest_analysis.overall_score * 100)}
                  label="Pontuacao Geral"
                />
              </div>

              <div :if={@latest_analysis.result} class="space-y-4">
                <.analysis_section
                  :if={@latest_analysis.result["feedback"]}
                  title="Feedback"
                  icon="hero-chat-bubble-left-right"
                  variant="info"
                >
                  <%= @latest_analysis.result["feedback"] %>
                </.analysis_section>

                <.analysis_section
                  :if={@latest_analysis.result["strengths"]}
                  title="Pontos Fortes"
                  icon="hero-check-circle"
                  variant="success"
                >
                  <ul class="list-disc list-inside space-y-1">
                    <li
                      :for={strength <- @latest_analysis.result["strengths"]}
                      class="text-sm text-slate-700 dark:text-slate-300"
                    >
                      <%= strength %>
                    </li>
                  </ul>
                </.analysis_section>

                <.analysis_section
                  :if={@latest_analysis.result["improvements"]}
                  title="Sugestoes de Melhoria"
                  icon="hero-light-bulb"
                  variant="warning"
                >
                  <ul class="list-disc list-inside space-y-1">
                    <li
                      :for={improvement <- @latest_analysis.result["improvements"]}
                      class="text-sm text-slate-700 dark:text-slate-300"
                    >
                      <%= improvement %>
                    </li>
                  </ul>
                </.analysis_section>
              </div>
            </div>

            <div :if={!@latest_analysis} class="text-center py-8">
              <.icon
                name="hero-document-magnifying-glass"
                class="mx-auto h-12 w-12 text-slate-300 dark:text-slate-600"
              />
              <p class="mt-2 text-sm text-slate-500 dark:text-slate-400">Analise nao disponivel</p>
            </div>
          </.card>
        </div>

        <!-- BNCC Coverage -->
        <.card :if={assigns[:bncc_coverage] && length(@bncc_coverage) > 0} class="animate-fade-in-up" style="animation-delay: 200ms">
          <:header>
            <div class="flex items-center gap-2">
              <.icon name="hero-academic-cap" class="h-5 w-5 text-violet-600 dark:text-violet-400" />
              <div>
                <h2 class="text-lg font-semibold text-slate-900 dark:text-white">
                  Competencias BNCC Trabalhadas
                </h2>
                <p class="text-sm text-slate-500 dark:text-slate-400">
                  Frequencia das competencias identificadas em suas aulas
                </p>
              </div>
            </div>
          </:header>
          <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <div
              :for={comp <- @bncc_coverage}
              class="p-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200/50 dark:border-slate-700/50 hover:border-teal-300/50 dark:hover:border-teal-600/50 transition-all duration-200"
            >
              <div class="flex items-center justify-between mb-2">
                <span class="text-xs font-mono font-medium text-teal-600 dark:text-teal-400 bg-teal-50 dark:bg-teal-900/30 px-2 py-0.5 rounded">
                  <%= comp.code %>
                </span>
                <span class="text-xs text-slate-500 dark:text-slate-400 font-medium">
                  <%= comp.count %>x
                </span>
              </div>
              <p class="text-sm text-slate-700 dark:text-slate-300 line-clamp-2">
                <%= comp.name || "Competencia BNCC" %>
              </p>
              <div class="mt-3 h-1.5 bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden">
                <div
                  class="h-full bg-gradient-to-r from-teal-500 to-sage-500 rounded-full transition-all duration-500"
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
      "flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium transition-colors",
      @trend == :improving && "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400",
      @trend == :declining && "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400",
      @trend == :stable && "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400"
    ]}>
      <.icon
        :if={@trend == :improving}
        name="hero-arrow-trending-up"
        class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
      />
      <.icon
        :if={@trend == :declining}
        name="hero-arrow-trending-down"
        class="h-4 w-4 text-red-600 dark:text-red-400"
      />
      <.icon
        :if={@trend == :stable}
        name="hero-minus"
        class="h-4 w-4 text-slate-500 dark:text-slate-400"
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
      "flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-sm font-medium transition-colors",
      @trend == :improving && "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400",
      @trend == :declining && "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400",
      @trend == :stable && "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400"
    ]}>
      <.icon
        :if={@trend == :improving}
        name="hero-arrow-trending-up"
        class="h-5 w-5 text-emerald-600 dark:text-emerald-400"
      />
      <.icon
        :if={@trend == :declining}
        name="hero-arrow-trending-down"
        class="h-5 w-5 text-red-600 dark:text-red-400"
      />
      <.icon
        :if={@trend == :stable}
        name="hero-minus"
        class="h-5 w-5 text-slate-500 dark:text-slate-400"
      />
      <span>
        <%= case @trend do
          :improving -> "Melhorando"
          :declining -> "Em queda"
          :stable -> "Estavel"
        end %>
      </span>
    </div>
    """
  end
end
