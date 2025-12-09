defmodule HellenWeb.ReportsLive.Index do
  @moduledoc """
  LiveView para pagina de relatorios do professor.
  Oferece visualizacao de dados, analytics e exportacao PDF.
  """

  use HellenWeb, :live_view

  import Ecto.Query, warn: false

  alias Hellen.Analysis.{Analysis, BnccMatch, BullyingAlert}
  alias Hellen.Assessments.Assessment
  alias Hellen.Lessons.Lesson
  alias Hellen.Plannings.Planning
  alias Hellen.Repo

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    current_date = Date.utc_today()

    # Default to current month
    start_date = Date.beginning_of_month(current_date)
    end_date = Date.end_of_month(current_date)

    socket =
      socket
      |> assign(:page_title, "Relatorios")
      |> assign(:selected_period, "month")
      |> assign(:start_date, start_date)
      |> assign(:end_date, end_date)
      |> assign(:selected_report, nil)
      |> assign(:generating, false)
      |> load_stats(user.id, start_date, end_date)
      |> load_charts_data(user.id, start_date, end_date)

    {:ok, socket}
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) do
    current_date = Date.utc_today()

    {start_date, end_date} =
      case period do
        "week" ->
          start = Date.add(current_date, -7)
          {start, current_date}

        "month" ->
          {Date.beginning_of_month(current_date), Date.end_of_month(current_date)}

        "quarter" ->
          start = Date.add(current_date, -90)
          {start, current_date}

        "year" ->
          start = Date.new!(current_date.year, 1, 1)
          {start, current_date}

        "all" ->
          {~D[2020-01-01], current_date}

        _ ->
          {Date.beginning_of_month(current_date), Date.end_of_month(current_date)}
      end

    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:selected_period, period)
      |> assign(:start_date, start_date)
      |> assign(:end_date, end_date)
      |> load_stats(user.id, start_date, end_date)
      |> load_charts_data(user.id, start_date, end_date)

    {:noreply, socket}
  end

  def handle_event("select_report", %{"type" => type}, socket) do
    {:noreply, assign(socket, :selected_report, type)}
  end

  def handle_event("clear_report", _params, socket) do
    {:noreply, assign(socket, :selected_report, nil)}
  end

  def handle_event("generate_pdf", %{"type" => type}, socket) do
    {:noreply, assign(socket, :generating, true)}

    user_id = socket.assigns.current_user.id
    start_date = socket.assigns.start_date
    end_date = socket.assigns.end_date

    # Spawn async task to generate PDF
    Task.start(fn ->
      case generate_report(type, user_id, start_date, end_date) do
        {:ok, _pdf} ->
          send(self(), {:pdf_generated, type})

        {:error, _reason} ->
          send(self(), {:pdf_error, type})
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:pdf_generated, _type}, socket) do
    {:noreply,
     socket
     |> assign(:generating, false)
     |> put_flash(:info, "Relatorio gerado com sucesso!")}
  end

  def handle_info({:pdf_error, _type}, socket) do
    {:noreply,
     socket
     |> assign(:generating, false)
     |> put_flash(:error, "Erro ao gerar relatorio. Tente novamente.")}
  end

  # ============================================
  # Private Functions - Data Loading
  # ============================================

  defp load_stats(socket, user_id, start_date, end_date) do
    date_range = build_date_range(start_date, end_date)
    stats = fetch_all_stats(user_id, date_range)
    assign(socket, :stats, stats)
  end

  defp build_date_range(start_date, end_date) do
    %{
      start_dt: DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC"),
      end_dt: DateTime.new!(Date.add(end_date, 1), ~T[00:00:00], "Etc/UTC")
    }
  end

  defp fetch_all_stats(user_id, date_range) do
    {lessons_count, total_duration} = fetch_lesson_stats(user_id, date_range)
    {analyses_count, avg_score} = fetch_analysis_stats(user_id, date_range)

    %{
      lessons: lessons_count,
      duration_hours: Float.round(total_duration / 3600, 1),
      analyses: analyses_count,
      avg_score: avg_score && Float.round(avg_score, 1),
      bncc_matches: fetch_bncc_count(user_id, date_range),
      alerts: fetch_alerts_count(user_id, date_range),
      plannings: fetch_plannings_count(user_id, date_range),
      assessments: fetch_assessments_count(user_id, date_range)
    }
  end

  defp fetch_lesson_stats(user_id, %{start_dt: start_dt, end_dt: end_dt}) do
    base_query =
      Lesson
      |> where([l], l.user_id == ^user_id)
      |> where([l], l.inserted_at >= ^start_dt and l.inserted_at < ^end_dt)

    count = Repo.aggregate(base_query, :count)

    duration =
      base_query
      |> where([l], not is_nil(l.duration))
      |> Repo.aggregate(:sum, :duration) || 0

    {count, duration}
  end

  defp fetch_analysis_stats(user_id, %{start_dt: start_dt, end_dt: end_dt}) do
    base_query =
      Analysis
      |> join(:inner, [a], l in assoc(a, :lesson))
      |> where([a, l], l.user_id == ^user_id)
      |> where([a], a.inserted_at >= ^start_dt and a.inserted_at < ^end_dt)

    count = Repo.aggregate(base_query, :count)

    avg =
      base_query
      |> where([a], not is_nil(a.overall_score))
      |> Repo.aggregate(:avg, :overall_score)

    {count, avg}
  end

  defp fetch_bncc_count(user_id, %{start_dt: start_dt, end_dt: end_dt}) do
    BnccMatch
    |> join(:inner, [m], a in assoc(m, :analysis))
    |> join(:inner, [m, a], l in assoc(a, :lesson))
    |> where([m, a, l], l.user_id == ^user_id)
    |> where([m, a], a.inserted_at >= ^start_dt and a.inserted_at < ^end_dt)
    |> Repo.aggregate(:count)
  end

  defp fetch_alerts_count(user_id, %{start_dt: start_dt, end_dt: end_dt}) do
    BullyingAlert
    |> join(:inner, [b], a in assoc(b, :analysis))
    |> join(:inner, [b, a], l in assoc(a, :lesson))
    |> where([b, a, l], l.user_id == ^user_id)
    |> where([b], b.inserted_at >= ^start_dt and b.inserted_at < ^end_dt)
    |> Repo.aggregate(:count)
  end

  defp fetch_plannings_count(user_id, %{start_dt: start_dt, end_dt: end_dt}) do
    Planning
    |> where([p], p.user_id == ^user_id)
    |> where([p], p.inserted_at >= ^start_dt and p.inserted_at < ^end_dt)
    |> Repo.aggregate(:count)
  end

  defp fetch_assessments_count(user_id, %{start_dt: start_dt, end_dt: end_dt}) do
    Assessment
    |> where([a], a.user_id == ^user_id)
    |> where([a], a.inserted_at >= ^start_dt and a.inserted_at < ^end_dt)
    |> Repo.aggregate(:count)
  end

  defp load_charts_data(socket, user_id, start_date, end_date) do
    start_dt = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(Date.add(end_date, 1), ~T[00:00:00], "Etc/UTC")

    # Score evolution data
    score_data =
      Analysis
      |> join(:inner, [a], l in assoc(a, :lesson))
      |> where([a, l], l.user_id == ^user_id)
      |> where([a], a.inserted_at >= ^start_dt and a.inserted_at < ^end_dt)
      |> where([a], not is_nil(a.overall_score))
      |> order_by([a], asc: a.inserted_at)
      |> select([a, l], %{
        date: a.inserted_at,
        score: a.overall_score,
        title: l.title
      })
      |> Repo.all()

    # BNCC coverage data
    bncc_data =
      BnccMatch
      |> join(:inner, [m], a in assoc(m, :analysis))
      |> join(:inner, [m, a], l in assoc(a, :lesson))
      |> where([m, a, l], l.user_id == ^user_id)
      |> where([m, a], a.inserted_at >= ^start_dt and a.inserted_at < ^end_dt)
      |> group_by([m], [m.competencia_code, m.competencia_name])
      |> select([m], %{
        code: m.competencia_code,
        name: m.competencia_name,
        count: count(m.id),
        avg_score: avg(m.match_score)
      })
      |> order_by([m], desc: count(m.id))
      |> limit(10)
      |> Repo.all()
      |> Enum.map(fn row ->
        %{row | avg_score: row.avg_score && Float.round(row.avg_score, 2)}
      end)

    # Lessons by subject
    lessons_by_subject =
      Lesson
      |> where([l], l.user_id == ^user_id)
      |> where([l], l.inserted_at >= ^start_dt and l.inserted_at < ^end_dt)
      |> where([l], not is_nil(l.disciplina))
      |> group_by([l], l.disciplina)
      |> select([l], %{
        subject: l.disciplina,
        count: count(l.id)
      })
      |> order_by([l], desc: count(l.id))
      |> Repo.all()

    # Lessons by status
    lessons_by_status =
      Lesson
      |> where([l], l.user_id == ^user_id)
      |> where([l], l.inserted_at >= ^start_dt and l.inserted_at < ^end_dt)
      |> group_by([l], l.status)
      |> select([l], %{
        status: l.status,
        count: count(l.id)
      })
      |> Repo.all()

    # Recent activity (last 10 items)
    recent_lessons =
      Lesson
      |> where([l], l.user_id == ^user_id)
      |> order_by([l], desc: l.inserted_at)
      |> limit(5)
      |> preload(:analyses)
      |> Repo.all()
      |> Enum.map(fn lesson ->
        latest_analysis = Enum.max_by(lesson.analyses, & &1.inserted_at, fn -> nil end)

        %{
          type: :lesson,
          title: lesson.title || "Aula sem titulo",
          date: lesson.inserted_at,
          status: lesson.status,
          score: latest_analysis && latest_analysis.overall_score
        }
      end)

    socket
    |> assign(:score_data, score_data)
    |> assign(:bncc_data, bncc_data)
    |> assign(:lessons_by_subject, lessons_by_subject)
    |> assign(:lessons_by_status, lessons_by_status)
    |> assign(:recent_activity, recent_lessons)
  end

  defp generate_report(type, user_id, start_date, _end_date) do
    opts = [
      month: start_date.month,
      year: start_date.year
    ]

    case type do
      "performance" ->
        Hellen.Reports.generate_teacher_report(user_id, opts)

      "bncc" ->
        # Future: implement BNCC-specific report
        {:error, :not_implemented}

      "detailed" ->
        Hellen.Reports.generate_teacher_report(user_id, opts)

      _ ->
        {:error, :invalid_type}
    end
  end

  # ============================================
  # Render
  # ============================================

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
                Relatorios & Analytics
              </h1>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                Acompanhe seu desempenho e gere relatorios detalhados
              </p>
            </div>
            <!-- Period Selector -->
            <div class="flex items-center gap-2">
              <span class="text-sm text-slate-500 dark:text-slate-400">Periodo:</span>
              <select
                phx-change="change_period"
                name="period"
                class="rounded-lg border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
              >
                <option value="week" selected={@selected_period == "week"}>Ultima semana</option>
                <option value="month" selected={@selected_period == "month"}>Este mes</option>
                <option value="quarter" selected={@selected_period == "quarter"}>
                  Ultimo trimestre
                </option>
                <option value="year" selected={@selected_period == "year"}>Este ano</option>
                <option value="all" selected={@selected_period == "all"}>Todo periodo</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8">
        <!-- Stats Cards -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <.reports_stat_card
            label="Aulas"
            value={@stats.lessons}
            icon="hero-academic-cap"
            color="teal"
          />
          <.reports_stat_card
            label="Horas Gravadas"
            value={@stats.duration_hours}
            suffix="h"
            icon="hero-clock"
            color="violet"
          />
          <.reports_stat_card
            label="Score Medio"
            value={@stats.avg_score || "-"}
            suffix={if @stats.avg_score, do: "/10", else: ""}
            icon="hero-star"
            color="amber"
          />
          <.reports_stat_card
            label="Competencias BNCC"
            value={@stats.bncc_matches}
            icon="hero-bookmark"
            color="emerald"
          />
        </div>
        <!-- Secondary Stats -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <.mini_stat label="Analises" value={@stats.analyses} />
          <.mini_stat label="Alertas" value={@stats.alerts} color={if @stats.alerts > 0, do: "red"} />
          <.mini_stat label="Planejamentos" value={@stats.plannings} />
          <.mini_stat label="Avaliacoes" value={@stats.assessments} />
        </div>
        <!-- Charts Section -->
        <div class="grid lg:grid-cols-2 gap-6">
          <!-- Score Evolution -->
          <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
            <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
              Evolucao do Score
            </h3>
            <%= if Enum.empty?(@score_data) do %>
              <div class="flex flex-col items-center justify-center py-12 text-slate-400">
                <.icon name="hero-chart-bar" class="h-12 w-12 mb-3" />
                <p>Sem dados de score no periodo</p>
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for item <- Enum.take(@score_data, 8) do %>
                  <div class="flex items-center gap-3">
                    <div class="w-24 text-xs text-slate-500 dark:text-slate-400 truncate">
                      <%= fmt_date(item.date) %>
                    </div>
                    <div class="flex-1 h-6 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden">
                      <div
                        class={[
                          "h-full rounded-full transition-all",
                          score_color(item.score)
                        ]}
                        style={"width: #{item.score * 10}%"}
                      >
                      </div>
                    </div>
                    <div class={[
                      "w-12 text-right text-sm font-semibold",
                      score_text_color(item.score)
                    ]}>
                      <%= Float.round(item.score, 1) %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
          <!-- BNCC Coverage -->
          <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
            <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
              Cobertura BNCC
            </h3>
            <%= if Enum.empty?(@bncc_data) do %>
              <div class="flex flex-col items-center justify-center py-12 text-slate-400">
                <.icon name="hero-bookmark" class="h-12 w-12 mb-3" />
                <p>Sem competencias identificadas no periodo</p>
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for comp <- Enum.take(@bncc_data, 6) do %>
                  <div class="group">
                    <div class="flex items-center justify-between mb-1">
                      <span class="text-xs font-medium text-teal-600 dark:text-teal-400">
                        <%= comp.code %>
                      </span>
                      <span class="text-xs text-slate-500 dark:text-slate-400">
                        <%= comp.count %> ocorrencias
                      </span>
                    </div>
                    <div class="h-2 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden">
                      <div
                        class="h-full bg-gradient-to-r from-teal-500 to-emerald-500 rounded-full"
                        style={"width: #{min(comp.count * 10, 100)}%"}
                      >
                      </div>
                    </div>
                    <p class="text-xs text-slate-500 dark:text-slate-400 mt-1 truncate group-hover:whitespace-normal">
                      <%= truncate(comp.name, 60) %>
                    </p>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
        <!-- Distribution Charts -->
        <div class="grid lg:grid-cols-2 gap-6">
          <!-- By Subject -->
          <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
            <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
              Aulas por Disciplina
            </h3>
            <%= if Enum.empty?(@lessons_by_subject) do %>
              <div class="flex flex-col items-center justify-center py-8 text-slate-400">
                <.icon name="hero-squares-2x2" class="h-10 w-10 mb-2" />
                <p class="text-sm">Sem dados de disciplina</p>
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for item <- @lessons_by_subject do %>
                  <div class="flex items-center gap-3">
                    <div class="w-32 text-sm text-slate-700 dark:text-slate-300 truncate">
                      <%= item.subject || "Nao definida" %>
                    </div>
                    <div class="flex-1 h-4 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden">
                      <div
                        class="h-full bg-gradient-to-r from-violet-500 to-purple-500 rounded-full"
                        style={"width: #{min(item.count * 20, 100)}%"}
                      >
                      </div>
                    </div>
                    <div class="w-8 text-right text-sm font-medium text-slate-700 dark:text-slate-300">
                      <%= item.count %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
          <!-- By Status -->
          <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
            <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
              Status das Aulas
            </h3>
            <%= if Enum.empty?(@lessons_by_status) do %>
              <div class="flex flex-col items-center justify-center py-8 text-slate-400">
                <.icon name="hero-signal" class="h-10 w-10 mb-2" />
                <p class="text-sm">Sem dados de status</p>
              </div>
            <% else %>
              <div class="grid grid-cols-2 gap-4">
                <%= for item <- @lessons_by_status do %>
                  <div class={[
                    "p-4 rounded-xl text-center",
                    status_bg(item.status)
                  ]}>
                    <div class="text-2xl font-bold text-slate-900 dark:text-white">
                      <%= item.count %>
                    </div>
                    <div class="text-xs text-slate-500 dark:text-slate-400 capitalize">
                      <%= get_status_label(item.status) %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
        <!-- Recent Activity -->
        <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
          <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
            Atividade Recente
          </h3>
          <%= if Enum.empty?(@recent_activity) do %>
            <div class="flex flex-col items-center justify-center py-8 text-slate-400">
              <.icon name="hero-clock" class="h-10 w-10 mb-2" />
              <p class="text-sm">Nenhuma atividade recente</p>
            </div>
          <% else %>
            <div class="divide-y divide-slate-100 dark:divide-slate-700">
              <%= for item <- @recent_activity do %>
                <div class="flex items-center gap-4 py-3">
                  <div class={[
                    "w-10 h-10 rounded-lg flex items-center justify-center",
                    status_icon_bg(item.status)
                  ]}>
                    <.icon name="hero-academic-cap" class="h-5 w-5 text-white" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-slate-900 dark:text-white truncate">
                      <%= item.title %>
                    </p>
                    <p class="text-xs text-slate-500 dark:text-slate-400">
                      <%= fmt_datetime(item.date) %>
                    </p>
                  </div>
                  <div class="flex items-center gap-3">
                    <%= if item.score do %>
                      <span class={[
                        "px-2 py-1 text-xs font-semibold rounded-full",
                        score_badge_class(item.score)
                      ]}>
                        <%= Float.round(item.score, 1) %>
                      </span>
                    <% end %>
                    <span class={[
                      "px-2 py-1 text-xs font-medium rounded-full",
                      status_badge_class(item.status)
                    ]}>
                      <%= get_status_label(item.status) %>
                    </span>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        <!-- Export Section -->
        <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-6">
          <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-2">
            Exportar Relatorios
          </h3>
          <p class="text-sm text-slate-500 dark:text-slate-400 mb-6">
            Gere relatorios em PDF para apresentacoes e documentacao
          </p>

          <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <!-- Performance Report -->
            <.report_card
              title="Relatorio de Performance"
              description="Resumo completo do periodo com scores, evolucao e estatisticas"
              icon="hero-chart-bar"
              color="teal"
              href={
                ~p"/reports/download/teacher/#{@current_user.id}?month=#{@start_date.month}&year=#{@start_date.year}"
              }
            />
            <!-- BNCC Report -->
            <.report_card
              title="Cobertura BNCC"
              description="Detalhamento das competencias trabalhadas no periodo"
              icon="hero-bookmark"
              color="violet"
              disabled={true}
            />
            <!-- Detailed Report -->
            <.report_card
              title="Relatorio Detalhado"
              description="Todas as aulas e analises do periodo com detalhes completos"
              icon="hero-document-text"
              color="emerald"
              disabled={true}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================
  # Components
  # ============================================

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :suffix, :string, default: ""
  attr :icon, :string, required: true
  attr :color, :string, default: "slate"

  defp reports_stat_card(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-5">
      <div class="flex items-start justify-between">
        <div>
          <p class="text-sm text-slate-500 dark:text-slate-400"><%= @label %></p>
          <p class="mt-1 text-2xl font-bold text-slate-900 dark:text-white">
            <%= @value %><span class="text-base font-normal text-slate-400"><%= @suffix %></span>
          </p>
        </div>
        <div class={[
          "p-2.5 rounded-xl",
          icon_bg(@color)
        ]}>
          <.icon name={@icon} class={"h-5 w-5 #{icon_color(@color)}"} />
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :color, :string, default: nil

  defp mini_stat(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 px-4 py-3 flex items-center justify-between">
      <span class="text-sm text-slate-500 dark:text-slate-400"><%= @label %></span>
      <span class={[
        "text-lg font-semibold",
        @color == "red" && "text-red-600 dark:text-red-400",
        @color != "red" && "text-slate-900 dark:text-white"
      ]}>
        <%= @value %>
      </span>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icon, :string, required: true
  attr :color, :string, default: "slate"
  attr :href, :string, default: nil
  attr :disabled, :boolean, default: false

  defp report_card(assigns) do
    ~H"""
    <%= if @disabled do %>
      <div class="p-5 rounded-xl border-2 border-dashed border-slate-200 dark:border-slate-700 opacity-60">
        <div class="flex items-start gap-4">
          <div class={["p-2.5 rounded-xl", icon_bg(@color)]}>
            <.icon name={@icon} class={"h-5 w-5 #{icon_color(@color)}"} />
          </div>
          <div>
            <h4 class="font-medium text-slate-900 dark:text-white">
              <%= @title %>
              <span class="ml-2 text-xs font-normal text-slate-400">Em breve</span>
            </h4>
            <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
              <%= @description %>
            </p>
          </div>
        </div>
      </div>
    <% else %>
      <a
        href={@href}
        target="_blank"
        class="group p-5 rounded-xl border border-slate-200 dark:border-slate-700 hover:border-teal-300 dark:hover:border-teal-600 hover:shadow-md transition-all"
      >
        <div class="flex items-start gap-4">
          <div class={[
            "p-2.5 rounded-xl transition-colors",
            icon_bg(@color),
            "group-hover:scale-105 transition-transform"
          ]}>
            <.icon name={@icon} class={"h-5 w-5 #{icon_color(@color)}"} />
          </div>
          <div>
            <h4 class="font-medium text-slate-900 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors">
              <%= @title %>
            </h4>
            <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
              <%= @description %>
            </p>
          </div>
        </div>
        <div class="mt-4 flex items-center gap-2 text-sm font-medium text-teal-600 dark:text-teal-400">
          <.icon name="hero-document-arrow-down" class="h-4 w-4" /> Baixar PDF
        </div>
      </a>
    <% end %>
    """
  end

  # ============================================
  # Helpers
  # ============================================

  defp icon_bg("teal"), do: "bg-teal-100 dark:bg-teal-900/30"
  defp icon_bg("violet"), do: "bg-violet-100 dark:bg-violet-900/30"
  defp icon_bg("amber"), do: "bg-amber-100 dark:bg-amber-900/30"
  defp icon_bg("emerald"), do: "bg-emerald-100 dark:bg-emerald-900/30"
  defp icon_bg(_), do: "bg-slate-100 dark:bg-slate-700"

  defp icon_color("teal"), do: "text-teal-600 dark:text-teal-400"
  defp icon_color("violet"), do: "text-violet-600 dark:text-violet-400"
  defp icon_color("amber"), do: "text-amber-600 dark:text-amber-400"
  defp icon_color("emerald"), do: "text-emerald-600 dark:text-emerald-400"
  defp icon_color(_), do: "text-slate-600 dark:text-slate-400"

  defp score_color(score) when score >= 8, do: "bg-emerald-500"
  defp score_color(score) when score >= 6, do: "bg-amber-500"
  defp score_color(_), do: "bg-red-500"

  defp score_text_color(score) when score >= 8, do: "text-emerald-600 dark:text-emerald-400"
  defp score_text_color(score) when score >= 6, do: "text-amber-600 dark:text-amber-400"
  defp score_text_color(_), do: "text-red-600 dark:text-red-400"

  defp score_badge_class(score) when score >= 8,
    do: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400"

  defp score_badge_class(score) when score >= 6,
    do: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"

  defp score_badge_class(_),
    do: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"

  defp status_bg("completed"), do: "bg-emerald-50 dark:bg-emerald-900/20"
  defp status_bg("analyzing"), do: "bg-cyan-50 dark:bg-cyan-900/20"
  defp status_bg("transcribing"), do: "bg-blue-50 dark:bg-blue-900/20"
  defp status_bg("pending"), do: "bg-amber-50 dark:bg-amber-900/20"
  defp status_bg("failed"), do: "bg-red-50 dark:bg-red-900/20"
  defp status_bg(_), do: "bg-slate-50 dark:bg-slate-900/20"

  defp status_icon_bg("completed"), do: "bg-emerald-500"
  defp status_icon_bg("analyzing"), do: "bg-cyan-500"
  defp status_icon_bg("transcribing"), do: "bg-blue-500"
  defp status_icon_bg("pending"), do: "bg-amber-500"
  defp status_icon_bg("failed"), do: "bg-red-500"
  defp status_icon_bg(_), do: "bg-slate-500"

  defp status_badge_class("completed"),
    do: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400"

  defp status_badge_class("analyzing"),
    do: "bg-cyan-100 text-cyan-700 dark:bg-cyan-900/30 dark:text-cyan-400"

  defp status_badge_class("transcribing"),
    do: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400"

  defp status_badge_class("pending"),
    do: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"

  defp status_badge_class("failed"),
    do: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"

  defp status_badge_class(_),
    do: "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300"

  defp get_status_label("completed"), do: "Concluida"
  defp get_status_label("analyzing"), do: "Analisando"
  defp get_status_label("transcribing"), do: "Transcrevendo"
  defp get_status_label("transcribed"), do: "Transcrita"
  defp get_status_label("pending"), do: "Pendente"
  defp get_status_label("failed"), do: "Falhou"
  defp get_status_label(other), do: other || "Desconhecido"

  defp truncate(nil, _max), do: ""
  defp truncate(string, max) when byte_size(string) <= max, do: string
  defp truncate(string, max), do: String.slice(string, 0, max) <> "..."

  defp fmt_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m")
  end

  defp fmt_date(_), do: "-"

  defp fmt_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y as %H:%M")
  end

  defp fmt_datetime(_), do: "-"
end
