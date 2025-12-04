defmodule HellenWeb.UIComponents do
  @moduledoc """
  UI components using LiveView 1.1 patterns.

  Includes:
  - async_result - Loading/error states for assign_async
  - stat_card - Dashboard statistics
  - empty_state - Empty content placeholder
  - lesson_card - Lesson display card
  - page_header - Page title with actions
  """
  use Phoenix.Component

  import HellenWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: HellenWeb.Endpoint,
    router: HellenWeb.Router,
    statics: HellenWeb.static_paths()

  # ============================================================================
  # STAT CARD - Dashboard statistics
  # ============================================================================

  @doc """
  Renders a statistics card for dashboards.

  ## Examples

      <.stat_card title="Total" value={42} icon="hero-document" />
      <.stat_card title="Completed" value={10} icon="hero-check" variant="success" />
  """
  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true

  attr :variant, :string,
    default: "default",
    values: ~w(default success processing pending warning)

  attr :subtitle, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <div class={[
      "bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6",
      stat_card_border(@variant)
    ]}>
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm font-medium text-gray-600 dark:text-gray-400"><%= @title %></p>
          <p class="mt-1 text-3xl font-semibold text-gray-900 dark:text-white"><%= @value %></p>
          <p :if={@subtitle} class="mt-1 text-xs text-gray-500 dark:text-gray-400">
            <%= @subtitle %>
          </p>
        </div>
        <div class={["p-3 rounded-full", stat_icon_bg(@variant)]}>
          <.icon name={@icon} class={"h-6 w-6 #{stat_icon_color(@variant)}"} />
        </div>
      </div>
    </div>
    """
  end

  defp stat_card_border("success"), do: "border-l-4 border-l-green-500"
  defp stat_card_border("processing"), do: "border-l-4 border-l-blue-500"
  defp stat_card_border("pending"), do: "border-l-4 border-l-yellow-500"
  defp stat_card_border("warning"), do: "border-l-4 border-l-orange-500"
  defp stat_card_border(_), do: "border-l-4 border-l-indigo-500"

  defp stat_icon_bg("success"), do: "bg-green-100 dark:bg-green-900/30"
  defp stat_icon_bg("processing"), do: "bg-blue-100 dark:bg-blue-900/30"
  defp stat_icon_bg("pending"), do: "bg-yellow-100 dark:bg-yellow-900/30"
  defp stat_icon_bg("warning"), do: "bg-orange-100 dark:bg-orange-900/30"
  defp stat_icon_bg(_), do: "bg-indigo-100 dark:bg-indigo-900/30"

  defp stat_icon_color("success"), do: "text-green-600 dark:text-green-400"
  defp stat_icon_color("processing"), do: "text-blue-600 dark:text-blue-400"
  defp stat_icon_color("pending"), do: "text-yellow-600 dark:text-yellow-400"
  defp stat_icon_color("warning"), do: "text-orange-600 dark:text-orange-400"
  defp stat_icon_color(_), do: "text-indigo-600 dark:text-indigo-400"

  # ============================================================================
  # EMPTY STATE
  # ============================================================================

  @doc """
  Renders an empty state placeholder.

  ## Examples

      <.empty_state
        icon="hero-document-text"
        title="Nenhuma aula"
        description="Comece enviando sua primeira aula."
      >
        <.button>Nova Aula</.button>
      </.empty_state>
  """
  attr :icon, :string, default: "hero-inbox"
  attr :title, :string, required: true
  attr :description, :string, default: nil

  slot :inner_block

  def empty_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <.icon name={@icon} class="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500" />
      <h3 class="mt-2 text-sm font-semibold text-gray-900 dark:text-white"><%= @title %></h3>
      <p :if={@description} class="mt-1 text-sm text-gray-500 dark:text-gray-400">
        <%= @description %>
      </p>
      <div :if={@inner_block != []} class="mt-6">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # LESSON CARD
  # ============================================================================

  @doc """
  Renders a lesson card for lists.

  ## Examples

      <.lesson_card lesson={@lesson} />
  """
  attr :lesson, :map, required: true

  def lesson_card(assigns) do
    ~H"""
    <.link navigate={~p"/lessons/#{@lesson.id}"} class="block group">
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6 hover:shadow-md hover:border-indigo-300 dark:hover:border-indigo-600 transition-all">
        <div class="flex justify-between items-start">
          <div class="flex-1 min-w-0">
            <h3 class="text-base font-semibold text-gray-900 dark:text-white truncate group-hover:text-indigo-600 dark:group-hover:text-indigo-400">
              <%= @lesson.title || "Aula sem título" %>
            </h3>
            <p class="mt-1 text-sm text-gray-500 dark:text-gray-400 truncate">
              <%= @lesson.subject || "Disciplina não informada" %>
            </p>
          </div>
          <.badge variant={status_variant(@lesson.status)}>
            <%= status_label(@lesson.status) %>
          </.badge>
        </div>

        <div class="mt-4 flex items-center text-xs text-gray-500 dark:text-gray-400">
          <.icon name="hero-calendar-mini" class="h-4 w-4 mr-1" />
          <%= format_date(@lesson.inserted_at) %>

          <span :if={@lesson.duration_seconds} class="ml-4 flex items-center">
            <.icon name="hero-clock-mini" class="h-4 w-4 mr-1" />
            <%= format_duration(@lesson.duration_seconds) %>
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
  def status_label("completed"), do: "Concluído"
  def status_label("failed"), do: "Falhou"
  def status_label(_), do: "Desconhecido"

  @doc false
  def format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y")
  end

  @doc false
  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y às %H:%M")
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

      <.page_header title="Dashboard" description="Suas aulas e análises">
        <:actions>
          <.button>Nova Aula</.button>
        </:actions>
      </.page_header>
  """
  attr :title, :string, required: true
  attr :description, :string, default: nil

  slot :actions

  def page_header(assigns) do
    ~H"""
    <div class="flex justify-between items-start mb-8">
      <div>
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white"><%= @title %></h1>
        <p :if={@description} class="mt-1 text-sm text-gray-500 dark:text-gray-400">
          <%= @description %>
        </p>
      </div>
      <div :if={@actions != []} class="flex items-center gap-3">
        <%= render_slot(@actions) %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # SCORE DISPLAY
  # ============================================================================

  @doc """
  Renders a score display with circular progress indicator.

  ## Examples

      <.score_display score={85} label="Pontuação Geral" />
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
            class="text-gray-200 dark:text-slate-700"
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
      <p :if={@label} class="mt-2 text-sm text-gray-500 dark:text-gray-400"><%= @label %></p>
    </div>
    """
  end

  defp score_size("sm"), do: "w-16 h-16"
  defp score_size("md"), do: "w-24 h-24"
  defp score_size("lg"), do: "w-32 h-32"

  defp score_text_size("sm"), do: "text-sm"
  defp score_text_size("md"), do: "text-xl"
  defp score_text_size("lg"), do: "text-2xl"

  defp score_color(score) when score >= 80, do: "text-green-500"
  defp score_color(score) when score >= 60, do: "text-yellow-500"
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

  slot :inner_block, required: true

  def analysis_section(assigns) do
    ~H"""
    <div class={["bg-gray-50 dark:bg-slate-800/50 rounded-lg p-4", @class]}>
      <div class="flex items-center gap-2 mb-3">
        <.icon name={@icon} class="h-5 w-5 text-indigo-600 dark:text-indigo-400" />
        <h4 class="font-semibold text-gray-900 dark:text-white"><%= @title %></h4>
      </div>
      <div class="text-sm text-gray-700 dark:text-gray-300">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
