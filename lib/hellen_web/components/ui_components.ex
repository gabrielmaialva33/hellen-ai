defmodule HellenWeb.UIComponents do
  @moduledoc """
  UI components using LiveView 1.1 patterns.
  2025 Design System with teal/sage/mint palette.

  Includes:
  - lesson_card - Lesson display card
  - page_header - Page title with actions
  - score_display - Circular score indicator
  - analysis_section - Analysis content section
  - quick_action_card - Dashboard quick action buttons
  """
  use Phoenix.Component

  import HellenWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: HellenWeb.Endpoint,
    router: HellenWeb.Router,
    statics: HellenWeb.static_paths()

  # ============================================================================
  # LESSON CARD (2025 Design)
  # ============================================================================

  @doc """
  Renders a modern lesson card for lists.

  ## Examples

      <.lesson_card lesson={@lesson} />
  """
  attr :lesson, :map, required: true

  def lesson_card(assigns) do
    ~H"""
    <.link navigate={~p"/lessons/#{@lesson.id}"} class="block group">
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-card border border-slate-200/50 dark:border-slate-700/50 p-5 hover:shadow-elevated hover:border-teal-300/50 dark:hover:border-teal-600/50 transition-all duration-300">
        <div class="flex justify-between items-start gap-4">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-1">
              <.badge variant={status_variant(@lesson.status)}>
                <%= status_label(@lesson.status) %>
              </.badge>
            </div>
            <h3 class="text-base font-semibold text-slate-900 dark:text-white truncate group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors">
              <%= @lesson.title || "Aula sem titulo" %>
            </h3>
            <p class="mt-1 text-sm text-slate-500 dark:text-slate-400 truncate">
              <%= @lesson.subject || "Disciplina nao informada" %>
              <%= if @lesson.grade, do: " · #{@lesson.grade}" %>
            </p>
          </div>

          <div class="flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity">
            <div class="w-8 h-8 rounded-lg bg-teal-500/10 dark:bg-teal-500/20 flex items-center justify-center">
              <.icon name="hero-arrow-right" class="h-4 w-4 text-teal-600 dark:text-teal-400" />
            </div>
          </div>
        </div>

        <div class="mt-4 flex items-center gap-4 text-xs text-slate-500 dark:text-slate-400">
          <span class="flex items-center gap-1.5">
            <.icon name="hero-calendar" class="h-3.5 w-3.5" />
            <%= format_date(@lesson.inserted_at) %>
          </span>

          <span :if={@lesson.duration_seconds} class="flex items-center gap-1.5">
            <.icon name="hero-clock" class="h-3.5 w-3.5" />
            <%= format_duration(@lesson.duration_seconds) %>
          </span>

          <span :if={@lesson.overall_score} class="flex items-center gap-1.5 text-teal-600 dark:text-teal-400 font-medium">
            <.icon name="hero-chart-bar" class="h-3.5 w-3.5" />
            <%= round(@lesson.overall_score * 100) %>%
          </span>
        </div>
      </div>
    </.link>
    """
  end

  # Helper functions used in HEEx templates (public to avoid compiler warnings)
  @doc false
  def status_variant("pending"), do: "pending"
  def status_variant("transcribing"), do: "processing"
  def status_variant("transcribed"), do: "processing"
  def status_variant("analyzing"), do: "processing"
  def status_variant("completed"), do: "completed"
  def status_variant("failed"), do: "failed"
  def status_variant(_), do: "default"

  @doc false
  def status_label("pending"), do: "Pendente"
  def status_label("transcribing"), do: "Transcrevendo"
  def status_label("transcribed"), do: "Analisando"
  def status_label("analyzing"), do: "Analisando"
  def status_label("completed"), do: "Concluido"
  def status_label("failed"), do: "Falhou"
  def status_label(_), do: "Desconhecido"

  @doc false
  def format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y")
  end

  @doc false
  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y as %H:%M")
  end

  @doc false
  def format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    if minutes > 0, do: "#{minutes}min #{secs}s", else: "#{secs}s"
  end

  def format_duration(_), do: "-"

  # ============================================================================
  # PAGE HEADER
  # ============================================================================

  @doc """
  Renders a page header with title, description and optional actions.

  ## Examples

      <.page_header title="Dashboard" description="Suas aulas e analises">
        <:actions>
          <.button>Nova Aula</.button>
        </:actions>
      </.page_header>
  """
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :icon, :string, default: nil

  slot :actions

  def page_header(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row justify-between items-start gap-4 mb-8">
      <div class="flex items-start gap-4">
        <div
          :if={@icon}
          class="flex-shrink-0 w-12 h-12 rounded-xl bg-teal-500/10 dark:bg-teal-500/20 flex items-center justify-center"
        >
          <.icon name={@icon} class="h-6 w-6 text-teal-600 dark:text-teal-400" />
        </div>
        <div>
          <h1 class="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">
            <%= @title %>
          </h1>
          <p :if={@description} class="mt-1 text-sm text-slate-500 dark:text-slate-400">
            <%= @description %>
          </p>
        </div>
      </div>
      <div :if={@actions != []} class="flex items-center gap-3 flex-shrink-0">
        <%= render_slot(@actions) %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # SCORE DISPLAY (2025 Design)
  # ============================================================================

  @doc """
  Renders a score display with circular progress indicator.

  ## Examples

      <.score_display score={85} label="Pontuacao Geral" />
  """
  attr :score, :integer, required: true
  attr :label, :string, default: nil
  attr :size, :string, default: "lg", values: ~w(sm md lg)

  def score_display(assigns) do
    ~H"""
    <div class="text-center">
      <div class={["relative inline-flex items-center justify-center", score_size(@size)]}>
        <svg class="transform -rotate-90" viewBox="0 0 36 36">
          <path
            class="text-slate-200 dark:text-slate-700"
            stroke="currentColor"
            stroke-width="3"
            fill="none"
            d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
          />
          <path
            class={score_color(@score)}
            stroke="currentColor"
            stroke-width="3"
            stroke-linecap="round"
            fill="none"
            stroke-dasharray={"#{@score}, 100"}
            d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
          />
        </svg>
        <span class={["absolute font-bold", score_text_size(@size), score_color(@score)]}>
          <%= @score %>%
        </span>
      </div>
      <p :if={@label} class="mt-2 text-sm text-slate-500 dark:text-slate-400"><%= @label %></p>
    </div>
    """
  end

  defp score_size("sm"), do: "w-16 h-16"
  defp score_size("md"), do: "w-24 h-24"
  defp score_size("lg"), do: "w-32 h-32"

  defp score_text_size("sm"), do: "text-sm"
  defp score_text_size("md"), do: "text-xl"
  defp score_text_size("lg"), do: "text-2xl"

  defp score_color(score) when score >= 80, do: "text-teal-500"
  defp score_color(score) when score >= 60, do: "text-sage-500"
  defp score_color(score) when score >= 40, do: "text-ochre-500"
  defp score_color(_), do: "text-red-500"

  # ============================================================================
  # ANALYSIS SECTION
  # ============================================================================

  @doc """
  Renders an analysis section with icon and title.

  ## Examples

      <.analysis_section title="Pontos Fortes" icon="hero-check-circle">
        Content here
      </.analysis_section>
  """
  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :class, :string, default: nil
  attr :variant, :string, default: "default", values: ~w(default success warning error info)

  slot :inner_block, required: true

  def analysis_section(assigns) do
    ~H"""
    <div class={[
      "rounded-xl p-5 border",
      analysis_section_bg(@variant),
      @class
    ]}>
      <div class="flex items-center gap-2 mb-3">
        <.icon name={@icon} class={"h-5 w-5 #{analysis_section_icon(@variant)}"} />
        <h4 class="font-semibold text-slate-900 dark:text-white"><%= @title %></h4>
      </div>
      <div class="text-sm text-slate-700 dark:text-slate-300">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  defp analysis_section_bg("success"), do: "bg-emerald-50 dark:bg-emerald-900/20 border-emerald-200 dark:border-emerald-800/50"
  defp analysis_section_bg("warning"), do: "bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800/50"
  defp analysis_section_bg("error"), do: "bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800/50"
  defp analysis_section_bg("info"), do: "bg-cyan-50 dark:bg-cyan-900/20 border-cyan-200 dark:border-cyan-800/50"
  defp analysis_section_bg(_), do: "bg-slate-50 dark:bg-slate-800/50 border-slate-200 dark:border-slate-700/50"

  defp analysis_section_icon("success"), do: "text-emerald-600 dark:text-emerald-400"
  defp analysis_section_icon("warning"), do: "text-amber-600 dark:text-amber-400"
  defp analysis_section_icon("error"), do: "text-red-600 dark:text-red-400"
  defp analysis_section_icon("info"), do: "text-cyan-600 dark:text-cyan-400"
  defp analysis_section_icon(_), do: "text-teal-600 dark:text-teal-400"

  # ============================================================================
  # QUICK ACTION CARD
  # ============================================================================

  @doc """
  Renders a quick action card for dashboards.

  ## Examples

      <.quick_action_card
        title="Nova Aula"
        description="Enviar gravacao para analise"
        icon="hero-plus-circle"
        href={~p"/lessons/new"}
        variant="primary"
      />
  """
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :icon, :string, required: true
  attr :href, :string, required: true
  attr :variant, :string, default: "default", values: ~w(primary default highlight)

  def quick_action_card(assigns) do
    ~H"""
    <.link navigate={@href} class="block group">
      <div class={[
        "rounded-xl p-6 transition-all duration-300",
        quick_action_variant(@variant)
      ]}>
        <div class="flex items-center gap-4">
          <div class={[
            "flex-shrink-0 p-3 rounded-xl transition-transform duration-300 group-hover:scale-110",
            quick_action_icon_bg(@variant)
          ]}>
            <.icon name={@icon} class={"h-7 w-7 #{quick_action_icon_color(@variant)}"} />
          </div>
          <div class="flex-1 min-w-0">
            <h3 class={["font-semibold text-lg", quick_action_title(@variant)]}>
              <%= @title %>
            </h3>
            <p :if={@description} class={["text-sm", quick_action_desc(@variant)]}>
              <%= @description %>
            </p>
          </div>
          <.icon
            name="hero-chevron-right"
            class={"h-5 w-5 #{quick_action_icon_color(@variant)} opacity-0 group-hover:opacity-100 transition-opacity"}
          />
        </div>
      </div>
    </.link>
    """
  end

  defp quick_action_variant("primary"), do: "bg-gradient-to-br from-teal-500 to-teal-600 shadow-lg hover:shadow-xl hover:shadow-teal-500/25"
  defp quick_action_variant("highlight"), do: "bg-white dark:bg-slate-800 border-2 border-amber-300 dark:border-amber-600 hover:shadow-lg"
  defp quick_action_variant(_), do: "bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 hover:border-teal-300 dark:hover:border-teal-600 hover:shadow-lg"

  defp quick_action_icon_bg("primary"), do: "bg-white/20"
  defp quick_action_icon_bg("highlight"), do: "bg-amber-100 dark:bg-amber-900/30"
  defp quick_action_icon_bg(_), do: "bg-teal-100 dark:bg-teal-900/30"

  defp quick_action_icon_color("primary"), do: "text-white"
  defp quick_action_icon_color("highlight"), do: "text-amber-600 dark:text-amber-400"
  defp quick_action_icon_color(_), do: "text-teal-600 dark:text-teal-400"

  defp quick_action_title("primary"), do: "text-white"
  defp quick_action_title(_), do: "text-slate-900 dark:text-white"

  defp quick_action_desc("primary"), do: "text-white/80"
  defp quick_action_desc(_), do: "text-slate-500 dark:text-slate-400"
end
