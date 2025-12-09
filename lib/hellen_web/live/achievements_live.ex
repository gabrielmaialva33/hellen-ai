defmodule HellenWeb.AchievementsLive do
  @moduledoc """
  LiveView for displaying user achievements and progress.
  """
  use HellenWeb, :live_view

  alias Hellen.Gamification

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    achievements = Gamification.get_user_achievement_progress(user.id)
    level_progress = Gamification.get_level_progress(user)
    unlocked_count = Gamification.count_user_achievements(user.id)
    total_count = Gamification.total_achievements_count()

    {:ok,
     socket
     |> assign(page_title: "Conquistas")
     |> assign(achievements: achievements)
     |> assign(level_progress: level_progress)
     |> assign(unlocked_count: unlocked_count)
     |> assign(total_count: total_count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6 lg:space-y-8">
      <!-- Header with Level Progress -->
      <div class="bg-gradient-to-br from-violet-600 via-purple-600 to-indigo-600 rounded-2xl p-6 sm:p-8 text-white relative overflow-hidden">
        <!-- Background decoration -->
        <div class="absolute inset-0 opacity-10">
          <div class="absolute top-0 right-0 w-64 h-64 bg-white rounded-full blur-3xl"></div>
          <div class="absolute bottom-0 left-0 w-48 h-48 bg-white rounded-full blur-2xl"></div>
        </div>

        <div class="relative flex flex-col lg:flex-row items-start lg:items-center justify-between gap-6">
          <div class="flex-1">
            <div class="flex items-center gap-4 mb-4">
              <div class="w-16 h-16 rounded-2xl bg-white/20 backdrop-blur-sm flex items-center justify-center">
                <span class="text-3xl font-bold"><%= @level_progress.level %></span>
              </div>
              <div>
                <p class="text-white/80 text-sm">Seu nivel</p>
                <h1 class="text-2xl font-bold">
                  <%= level_title(@level_progress.level) %>
                </h1>
              </div>
            </div>
            <!-- XP Progress Bar -->
            <div class="max-w-md">
              <div class="flex items-center justify-between mb-2 text-sm">
                <span class="text-white/80">Experiencia</span>
                <span class="font-medium">
                  <%= @level_progress.current_xp %>/<%= @level_progress.xp_for_next_level %> XP
                </span>
              </div>
              <div class="h-3 bg-white/20 rounded-full overflow-hidden">
                <div
                  class="h-full bg-gradient-to-r from-amber-400 to-orange-500 rounded-full transition-all duration-500"
                  style={"width: #{@level_progress.progress_percent}%"}
                >
                </div>
              </div>
              <p class="text-xs text-white/60 mt-2">
                Faltam <%= @level_progress.xp_for_next_level - @level_progress.current_xp %> XP para o proximo nivel
              </p>
            </div>
          </div>
          <!-- Achievement Stats -->
          <div class="flex items-center gap-6">
            <div class="text-center">
              <div class="text-4xl font-bold"><%= @unlocked_count %></div>
              <p class="text-white/80 text-sm">Conquistas</p>
            </div>
            <div class="w-px h-12 bg-white/20"></div>
            <div class="text-center">
              <div class="text-4xl font-bold"><%= @total_count %></div>
              <p class="text-white/80 text-sm">Total</p>
            </div>
          </div>
        </div>
      </div>
      <!-- Achievement Grid -->
      <div>
        <h2 class="text-xl font-bold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
          <.icon name="hero-trophy" class="h-6 w-6 text-amber-500" /> Todas as Conquistas
        </h2>

        <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <.achievement_card :for={achievement <- @achievements} achievement={achievement} />
        </div>
      </div>
    </div>
    """
  end

  defp achievement_card(assigns) do
    ~H"""
    <div class={[
      "relative rounded-2xl border p-5 transition-all duration-300",
      if(@achievement.unlocked,
        do: "bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700",
        else:
          "bg-slate-50 dark:bg-slate-800/50 border-slate-200/50 dark:border-slate-700/50 opacity-60"
      )
    ]}>
      <!-- Unlocked badge -->
      <div
        :if={@achievement.unlocked}
        class="absolute -top-2 -right-2 w-8 h-8 bg-emerald-500 rounded-full flex items-center justify-center shadow-lg"
      >
        <.icon name="hero-check" class="h-5 w-5 text-white" />
      </div>

      <div class="flex items-start gap-4">
        <!-- Icon -->
        <div class={[
          "w-14 h-14 rounded-xl flex items-center justify-center flex-shrink-0",
          achievement_bg(@achievement.definition.color),
          if(!@achievement.unlocked, do: "grayscale")
        ]}>
          <.icon
            name={@achievement.definition.icon}
            class={"h-7 w-7 #{achievement_text(@achievement.definition.color)}"}
          />
        </div>

        <div class="flex-1 min-w-0">
          <h3 class={[
            "font-semibold mb-1",
            if(@achievement.unlocked,
              do: "text-slate-900 dark:text-white",
              else: "text-slate-500 dark:text-slate-400"
            )
          ]}>
            <%= @achievement.definition.name %>
          </h3>
          <p class="text-sm text-slate-500 dark:text-slate-400 mb-2">
            <%= @achievement.definition.description %>
          </p>
          <!-- Progress bar for locked achievements -->
          <div :if={!@achievement.unlocked and @achievement.progress > 0} class="mt-3">
            <div class="flex items-center justify-between mb-1 text-xs text-slate-500 dark:text-slate-400">
              <span>Progresso</span>
              <span><%= @achievement.progress %>%</span>
            </div>
            <div class="h-1.5 bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden">
              <div
                class="h-full bg-gradient-to-r from-teal-500 to-emerald-500 rounded-full"
                style={"width: #{@achievement.progress}%"}
              >
              </div>
            </div>
          </div>
          <!-- XP reward -->
          <div class="flex items-center gap-1 mt-2 text-xs">
            <.icon name="hero-bolt" class="h-4 w-4 text-amber-500" />
            <span class="text-slate-500 dark:text-slate-400">
              +<%= @achievement.definition.xp %> XP
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp level_title(level) when level <= 2, do: "Iniciante"
  defp level_title(level) when level <= 5, do: "Professor Dedicado"
  defp level_title(level) when level <= 10, do: "Expert Pedagogico"
  defp level_title(level) when level <= 15, do: "Mestre Educador"
  defp level_title(_level), do: "Lenda da Educacao"

  defp achievement_bg("teal"), do: "bg-teal-100 dark:bg-teal-900/30"
  defp achievement_bg("emerald"), do: "bg-emerald-100 dark:bg-emerald-900/30"
  defp achievement_bg("amber"), do: "bg-amber-100 dark:bg-amber-900/30"
  defp achievement_bg("violet"), do: "bg-violet-100 dark:bg-violet-900/30"
  defp achievement_bg("purple"), do: "bg-purple-100 dark:bg-purple-900/30"
  defp achievement_bg("cyan"), do: "bg-cyan-100 dark:bg-cyan-900/30"
  defp achievement_bg("blue"), do: "bg-blue-100 dark:bg-blue-900/30"
  defp achievement_bg("orange"), do: "bg-orange-100 dark:bg-orange-900/30"
  defp achievement_bg("red"), do: "bg-red-100 dark:bg-red-900/30"
  defp achievement_bg(_), do: "bg-slate-100 dark:bg-slate-700"

  defp achievement_text("teal"), do: "text-teal-600 dark:text-teal-400"
  defp achievement_text("emerald"), do: "text-emerald-600 dark:text-emerald-400"
  defp achievement_text("amber"), do: "text-amber-600 dark:text-amber-400"
  defp achievement_text("violet"), do: "text-violet-600 dark:text-violet-400"
  defp achievement_text("purple"), do: "text-purple-600 dark:text-purple-400"
  defp achievement_text("cyan"), do: "text-cyan-600 dark:text-cyan-400"
  defp achievement_text("blue"), do: "text-blue-600 dark:text-blue-400"
  defp achievement_text("orange"), do: "text-orange-600 dark:text-orange-400"
  defp achievement_text("red"), do: "text-red-600 dark:text-red-400"
  defp achievement_text(_), do: "text-slate-600 dark:text-slate-400"
end
