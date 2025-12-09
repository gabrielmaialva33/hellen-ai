defmodule HellenWeb.DashboardLive.Index do
  @moduledoc """
  Dashboard LiveView - 2025 Modern Design
  Clean, impactful layout with visual hierarchy.
  """
  use HellenWeb, :live_view

  alias Hellen.Lessons

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(page_title: "Dashboard")
     |> assign(greeting: get_greeting())
     |> assign(loading: true)
     |> stream(:recent_lessons, [])
     |> assign_async(:stats, fn -> load_stats(user.id) end)
     |> load_lessons_async(user.id)}
  end

  defp load_lessons_async(socket, user_id) do
    if connected?(socket) do
      start_async(socket, :load_lessons, fn ->
        Lessons.list_lessons_by_user(user_id, limit: 5)
      end)
    else
      socket
    end
  end

  # PWA OfflineIndicator hook events - ignore silently
  @impl true
  def handle_event("online", _params, socket), do: {:noreply, socket}
  def handle_event("offline", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_async(:load_lessons, {:ok, lessons}, socket) do
    {:noreply,
     socket
     |> assign(loading: false)
     |> stream(:recent_lessons, lessons, reset: true)}
  end

  def handle_async(:load_lessons, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(loading: false)
     |> put_flash(:error, "Erro ao carregar aulas")}
  end

  defp load_stats(user_id) do
    lessons = Lessons.list_lessons_by_user(user_id)

    stats = %{
      total: length(lessons),
      completed: Enum.count(lessons, &(&1.status == "completed")),
      processing:
        Enum.count(lessons, &(&1.status in ["transcribing", "analyzing", "transcribed"])),
      pending: Enum.count(lessons, &(&1.status == "pending"))
    }

    # assign_async expects {:ok, %{key: value}} where key matches the assign name
    # When using <.async_result :let={data}>, data = stats (the value)
    {:ok, %{stats: stats}}
  end

  defp get_greeting do
    hour = DateTime.utc_now() |> DateTime.to_time() |> Map.get(:hour)

    cond do
      hour >= 5 and hour < 12 -> "Bom dia"
      hour >= 12 and hour < 18 -> "Boa tarde"
      true -> "Boa noite"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6 lg:space-y-8">
      <!-- Hero Section with CTA -->
      <div class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-teal-600 via-teal-500 to-emerald-500 p-6 sm:p-8 lg:p-10">
        <!-- Background Pattern -->
        <div class="absolute inset-0 opacity-10">
          <svg class="h-full w-full" viewBox="0 0 100 100" preserveAspectRatio="none">
            <defs>
              <pattern
                id="hero-pattern"
                x="0"
                y="0"
                width="20"
                height="20"
                patternUnits="userSpaceOnUse"
              >
                <circle cx="2" cy="2" r="1" fill="white" />
              </pattern>
            </defs>
            <rect fill="url(#hero-pattern)" width="100" height="100" />
          </svg>
        </div>

        <div class="relative flex flex-col lg:flex-row items-start lg:items-center justify-between gap-6">
          <div class="flex-1">
            <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/20 backdrop-blur-sm mb-4">
              <span class="relative flex h-2 w-2">
                <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-white opacity-75">
                </span>
                <span class="relative inline-flex rounded-full h-2 w-2 bg-white"></span>
              </span>
              <span class="text-sm font-medium text-white/90">Hellen AI</span>
            </div>
            <h1 class="text-2xl sm:text-3xl lg:text-4xl font-bold text-white mb-2">
              <%= @greeting %>, <%= @current_user.name || "Professor" %>!
            </h1>
            <p class="text-white/80 text-base sm:text-lg max-w-xl">
              Transforme suas aulas em insights pedagogicos com inteligencia artificial.
            </p>
          </div>

          <div class="flex flex-col sm:flex-row gap-3 w-full lg:w-auto">
            <.link navigate={~p"/lessons/new"} class="flex-1 lg:flex-none">
              <button class="w-full lg:w-auto inline-flex items-center justify-center gap-2 px-6 py-3 rounded-xl bg-white text-teal-600 font-semibold shadow-lg hover:shadow-xl hover:bg-slate-50 transition-all duration-200">
                <.icon name="hero-plus" class="h-5 w-5" /> Nova Aula
              </button>
            </.link>
            <.link navigate={~p"/aulas"} class="flex-1 lg:flex-none">
              <button class="w-full lg:w-auto inline-flex items-center justify-center gap-2 px-6 py-3 rounded-xl bg-white/10 backdrop-blur-sm text-white font-medium border border-white/20 hover:bg-white/20 transition-all duration-200">
                <.icon name="hero-folder" class="h-5 w-5" /> Ver Aulas
              </button>
            </.link>
          </div>
        </div>
        <!-- Floating decoration -->
        <div class="absolute -bottom-8 -right-8 w-32 h-32 bg-white/10 rounded-full blur-2xl"></div>
        <div class="absolute -top-8 -left-8 w-24 h-24 bg-emerald-400/20 rounded-full blur-2xl"></div>
      </div>
      <!-- Stats Grid -->
      <.async_result :let={data} assign={@stats}>
        <:loading>
          <div class="grid gap-4 grid-cols-2 lg:grid-cols-4">
            <.stat_skeleton :for={_ <- 1..4} />
          </div>
        </:loading>
        <:failed>
          <.alert variant="error">Erro ao carregar estatisticas</.alert>
        </:failed>

        <div class="grid gap-4 grid-cols-2 lg:grid-cols-4">
          <.modern_stat_card
            value={data.total}
            label="Total de Aulas"
            icon="hero-academic-cap"
            color="teal"
          />
          <.modern_stat_card
            value={data.completed}
            label="Concluidas"
            icon="hero-check-circle"
            color="emerald"
          />
          <.modern_stat_card
            value={data.processing}
            label="Processando"
            icon="hero-arrow-path"
            color="cyan"
            animate={data.processing > 0}
          />
          <.modern_stat_card value={data.pending} label="Pendentes" icon="hero-clock" color="amber" />
        </div>
      </.async_result>
      <!-- Main Content Grid -->
      <div class="grid gap-6 lg:grid-cols-3">
        <!-- Recent Lessons (2 cols) -->
        <div class="lg:col-span-2 space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-slate-900 dark:text-white flex items-center gap-2">
              <.icon name="hero-clock" class="h-5 w-5 text-slate-400" /> Aulas Recentes
            </h2>
            <.link
              navigate={~p"/aulas"}
              class="text-sm font-medium text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300 transition-colors flex items-center gap-1 group"
            >
              Ver todas
              <.icon
                name="hero-arrow-right-mini"
                class="h-4 w-4 group-hover:translate-x-0.5 transition-transform"
              />
            </.link>
          </div>

          <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 overflow-hidden">
            <div id="recent-lessons-container" phx-update="stream">
              <div
                :for={{dom_id, lesson} <- @streams.recent_lessons}
                id={dom_id}
                class="p-4 border-b border-slate-100 dark:border-slate-700/50 last:border-0 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
              >
                <.lesson_row lesson={lesson} />
              </div>
            </div>
            <!-- Empty State -->
            <div
              :if={match?(%{ok?: true, result: %{total: 0}}, @stats)}
              class="p-8 sm:p-12 text-center"
            >
              <div class="mx-auto w-16 h-16 rounded-2xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30 flex items-center justify-center mb-4">
                <.icon name="hero-document-plus" class="h-8 w-8 text-teal-600 dark:text-teal-400" />
              </div>
              <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-2">
                Comece sua jornada!
              </h3>
              <p class="text-slate-500 dark:text-slate-400 mb-6 max-w-sm mx-auto">
                Envie sua primeira aula para receber analise pedagogica com IA em minutos.
              </p>
              <.link navigate={~p"/lessons/new"}>
                <button class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-teal-600 text-white font-medium hover:bg-teal-700 transition-colors">
                  <.icon name="hero-plus" class="h-5 w-5" /> Enviar Primeira Aula
                </button>
              </.link>
            </div>
          </div>
        </div>
        <!-- Sidebar (1 col) -->
        <div class="space-y-4">
          <!-- Credits Card -->
          <div class="bg-gradient-to-br from-slate-800 to-slate-900 rounded-2xl p-5 text-white">
            <div class="flex items-center gap-4 mb-4">
              <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-teal-400 to-emerald-500 flex items-center justify-center shadow-lg">
                <.icon name="hero-bolt" class="h-6 w-6 text-white" />
              </div>
              <div>
                <p class="text-slate-400 text-sm">Creditos</p>
                <p
                  class="text-3xl font-bold"
                  phx-hook="AnimatedCounter"
                  id="credits-counter"
                  data-target={@current_user.credits || 0}
                >
                  <span class="counter-value"><%= @current_user.credits || 0 %></span>
                </p>
              </div>
            </div>
            <.link navigate={~p"/billing"} class="block">
              <button class="w-full py-2.5 rounded-xl bg-white/10 hover:bg-white/20 text-white font-medium transition-colors flex items-center justify-center gap-2">
                <.icon name="hero-plus" class="h-4 w-4" /> Comprar Creditos
              </button>
            </.link>
          </div>
          <!-- Quick Tips -->
          <div class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 p-5">
            <h3 class="font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
              <.icon name="hero-light-bulb" class="h-5 w-5 text-amber-500" /> Dica do dia
            </h3>
            <div class="space-y-3">
              <p class="text-sm text-slate-600 dark:text-slate-300">
                Grave aulas de
                <span class="font-medium text-teal-600 dark:text-teal-400">15-30 minutos</span>
                para obter analises mais precisas da IA.
              </p>
              <div class="flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400">
                <.icon name="hero-clock" class="h-4 w-4" /> Duracao ideal para melhor qualidade
              </div>
            </div>
          </div>
          <!-- BNCC Info -->
          <div class="bg-gradient-to-br from-violet-50 to-purple-50 dark:from-violet-900/20 dark:to-purple-900/20 rounded-2xl border border-violet-200/50 dark:border-violet-800/50 p-5">
            <div class="flex items-start gap-3">
              <div class="w-10 h-10 rounded-xl bg-violet-100 dark:bg-violet-900/50 flex items-center justify-center flex-shrink-0">
                <.icon
                  name="hero-document-check"
                  class="h-5 w-5 text-violet-600 dark:text-violet-400"
                />
              </div>
              <div>
                <h4 class="font-semibold text-slate-900 dark:text-white text-sm">
                  Alinhado a BNCC
                </h4>
                <p class="text-xs text-slate-600 dark:text-slate-400 mt-1">
                  Analise automatica de competencias e habilidades da Base Nacional Comum Curricular.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp modern_stat_card(assigns) do
    assigns = assign_new(assigns, :animate, fn -> false end)

    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl p-4 sm:p-5 border border-slate-200/50 dark:border-slate-700/50 hover:shadow-lg hover:border-slate-300 dark:hover:border-slate-600 transition-all duration-300 group">
      <div class="flex items-center justify-between mb-3">
        <div class={[
          "w-10 h-10 rounded-xl flex items-center justify-center transition-transform duration-300 group-hover:scale-110",
          stat_bg(@color),
          @animate && "animate-pulse"
        ]}>
          <.icon name={@icon} class={"h-5 w-5 #{stat_text(@color)}"} />
        </div>
        <div :if={@animate} class="flex items-center gap-1.5">
          <span class="relative flex h-2 w-2">
            <span class={"animate-ping absolute inline-flex h-full w-full rounded-full #{stat_dot(@color)} opacity-75"}>
            </span>
            <span class={"relative inline-flex rounded-full h-2 w-2 #{stat_dot(@color)}"}></span>
          </span>
          <span class="text-xs font-medium text-slate-500 dark:text-slate-400">Ativo</span>
        </div>
      </div>
      <p class="text-2xl sm:text-3xl font-bold text-slate-900 dark:text-white tracking-tight">
        <%= @value %>
      </p>
      <p class="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-1">
        <%= @label %>
      </p>
    </div>
    """
  end

  defp stat_bg("teal"), do: "bg-teal-100 dark:bg-teal-900/30"
  defp stat_bg("emerald"), do: "bg-emerald-100 dark:bg-emerald-900/30"
  defp stat_bg("cyan"), do: "bg-cyan-100 dark:bg-cyan-900/30"
  defp stat_bg("amber"), do: "bg-amber-100 dark:bg-amber-900/30"
  defp stat_bg(_), do: "bg-slate-100 dark:bg-slate-700"

  defp stat_text("teal"), do: "text-teal-600 dark:text-teal-400"
  defp stat_text("emerald"), do: "text-emerald-600 dark:text-emerald-400"
  defp stat_text("cyan"), do: "text-cyan-600 dark:text-cyan-400"
  defp stat_text("amber"), do: "text-amber-600 dark:text-amber-400"
  defp stat_text(_), do: "text-slate-600 dark:text-slate-400"

  defp stat_dot("teal"), do: "bg-teal-500"
  defp stat_dot("emerald"), do: "bg-emerald-500"
  defp stat_dot("cyan"), do: "bg-cyan-500"
  defp stat_dot("amber"), do: "bg-amber-500"
  defp stat_dot(_), do: "bg-slate-500"

  defp lesson_row(assigns) do
    ~H"""
    <.link navigate={~p"/lessons/#{@lesson.id}"} class="flex items-center gap-4 group">
      <div class={[
        "w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0",
        lesson_status_bg(@lesson.status)
      ]}>
        <.icon
          name={lesson_status_icon(@lesson.status)}
          class={"h-5 w-5 #{lesson_status_color(@lesson.status)}"}
        />
      </div>
      <div class="flex-1 min-w-0">
        <p class="font-medium text-slate-900 dark:text-white truncate group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors">
          <%= @lesson.title || "Aula sem titulo" %>
        </p>
        <p class="text-sm text-slate-500 dark:text-slate-400 flex items-center gap-2">
          <span><%= @lesson.subject || "Geral" %></span>
          <span class="text-slate-300 dark:text-slate-600">•</span>
          <span><%= format_lesson_date(@lesson.inserted_at) %></span>
        </p>
      </div>
      <.lesson_status_badge status={@lesson.status} />
      <.icon
        name="hero-chevron-right"
        class="h-5 w-5 text-slate-300 dark:text-slate-600 group-hover:text-slate-400 dark:group-hover:text-slate-500 transition-colors"
      />
    </.link>
    """
  end

  defp lesson_status_badge(assigns) do
    ~H"""
    <span class={[
      "px-2.5 py-1 rounded-full text-xs font-medium",
      lesson_badge_class(@status)
    ]}>
      <%= lesson_status_label(@status) %>
    </span>
    """
  end

  defp lesson_status_bg("completed"), do: "bg-emerald-100 dark:bg-emerald-900/30"
  defp lesson_status_bg("analyzing"), do: "bg-cyan-100 dark:bg-cyan-900/30"
  defp lesson_status_bg("transcribing"), do: "bg-blue-100 dark:bg-blue-900/30"
  defp lesson_status_bg("transcribed"), do: "bg-violet-100 dark:bg-violet-900/30"
  defp lesson_status_bg("pending"), do: "bg-amber-100 dark:bg-amber-900/30"
  defp lesson_status_bg("failed"), do: "bg-red-100 dark:bg-red-900/30"
  defp lesson_status_bg(_), do: "bg-slate-100 dark:bg-slate-700"

  defp lesson_status_icon("completed"), do: "hero-check-circle"
  defp lesson_status_icon("analyzing"), do: "hero-cpu-chip"
  defp lesson_status_icon("transcribing"), do: "hero-microphone"
  defp lesson_status_icon("transcribed"), do: "hero-document-text"
  defp lesson_status_icon("pending"), do: "hero-clock"
  defp lesson_status_icon("failed"), do: "hero-x-circle"
  defp lesson_status_icon(_), do: "hero-document"

  defp lesson_status_color("completed"), do: "text-emerald-600 dark:text-emerald-400"
  defp lesson_status_color("analyzing"), do: "text-cyan-600 dark:text-cyan-400"
  defp lesson_status_color("transcribing"), do: "text-blue-600 dark:text-blue-400"
  defp lesson_status_color("transcribed"), do: "text-violet-600 dark:text-violet-400"
  defp lesson_status_color("pending"), do: "text-amber-600 dark:text-amber-400"
  defp lesson_status_color("failed"), do: "text-red-600 dark:text-red-400"
  defp lesson_status_color(_), do: "text-slate-600 dark:text-slate-400"

  defp lesson_badge_class("completed"),
    do: "bg-emerald-100 dark:bg-emerald-900/50 text-emerald-700 dark:text-emerald-300"

  defp lesson_badge_class("analyzing"),
    do: "bg-cyan-100 dark:bg-cyan-900/50 text-cyan-700 dark:text-cyan-300"

  defp lesson_badge_class("transcribing"),
    do: "bg-blue-100 dark:bg-blue-900/50 text-blue-700 dark:text-blue-300"

  defp lesson_badge_class("transcribed"),
    do: "bg-violet-100 dark:bg-violet-900/50 text-violet-700 dark:text-violet-300"

  defp lesson_badge_class("pending"),
    do: "bg-amber-100 dark:bg-amber-900/50 text-amber-700 dark:text-amber-300"

  defp lesson_badge_class("failed"),
    do: "bg-red-100 dark:bg-red-900/50 text-red-700 dark:text-red-300"

  defp lesson_badge_class(_),
    do: "bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300"

  defp lesson_status_label("completed"), do: "Concluida"
  defp lesson_status_label("analyzing"), do: "Analisando"
  defp lesson_status_label("transcribing"), do: "Transcrevendo"
  defp lesson_status_label("transcribed"), do: "Transcrita"
  defp lesson_status_label("pending"), do: "Pendente"
  defp lesson_status_label("failed"), do: "Erro"
  defp lesson_status_label(_), do: "Desconhecido"

  defp format_lesson_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y")
  end

  defp stat_skeleton(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl p-4 sm:p-5 border border-slate-200/50 dark:border-slate-700/50 animate-pulse">
      <div class="flex items-center justify-between mb-3">
        <div class="w-10 h-10 bg-slate-200 dark:bg-slate-700 rounded-xl"></div>
      </div>
      <div class="h-8 w-12 bg-slate-200 dark:bg-slate-700 rounded mb-2"></div>
      <div class="h-4 w-20 bg-slate-200 dark:bg-slate-700 rounded"></div>
    </div>
    """
  end
end
