defmodule HellenWeb.AdminLive.Index do
  @moduledoc """
  Admin Dashboard - System-wide statistics and recent activity.
  """
  use HellenWeb, :live_view

  alias Hellen.Accounts

  @impl true
  def mount(_params, _session, socket) do
    stats = Accounts.get_system_stats()
    activity = Accounts.get_recent_platform_activity(5)
    registrations = Accounts.get_daily_registrations(30)

    {:ok,
     socket
     |> assign(page_title: "Painel Admin")
     |> assign(stats: stats)
     |> assign(activity: activity)
     |> assign(registrations: registrations)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Painel Administrativo</h1>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
            Visao geral do sistema Hellen AI
          </p>
        </div>
        <div class="flex items-center gap-2">
          <.link
            navigate={~p"/admin/institutions"}
            class="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-slate-800 border border-gray-300 dark:border-slate-600 rounded-lg hover:bg-gray-50 dark:hover:bg-slate-700"
          >
            <.icon name="hero-building-office-2" class="h-4 w-4 inline mr-1" /> Instituicoes
          </.link>
          <.link
            navigate={~p"/admin/users"}
            class="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700"
          >
            <.icon name="hero-user-group" class="h-4 w-4 inline mr-1" /> Usuarios
          </.link>
        </div>
      </div>
      <!-- Stats Grid -->
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
        <.admin_stat_card
          label="Instituicoes"
          value={@stats.institutions}
          icon="hero-building-office-2"
          color="indigo"
        />
        <.admin_stat_card label="Usuarios" value={@stats.users} icon="hero-users" color="blue" />
        <.admin_stat_card
          label="Aulas"
          value={@stats.lessons}
          icon="hero-academic-cap"
          color="emerald"
        />
        <.admin_stat_card
          label="Analises"
          value={@stats.analyses}
          icon="hero-chart-bar"
          color="purple"
        />
        <.admin_stat_card
          label="Alertas Pendentes"
          value={@stats.pending_alerts}
          icon="hero-bell-alert"
          color={if @stats.pending_alerts > 0, do: "red", else: "gray"}
        />
      </div>
      <!-- Distribution Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Users by Role -->
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Usuarios por Cargo</h3>
          <div class="space-y-3">
            <.distribution_bar
              label="Professores"
              count={Map.get(@stats.users_by_role, "teacher", 0)}
              total={@stats.users}
              color="bg-blue-500"
            />
            <.distribution_bar
              label="Coordenadores"
              count={Map.get(@stats.users_by_role, "coordinator", 0)}
              total={@stats.users}
              color="bg-amber-500"
            />
            <.distribution_bar
              label="Administradores"
              count={Map.get(@stats.users_by_role, "admin", 0)}
              total={@stats.users}
              color="bg-red-500"
            />
          </div>
        </div>
        <!-- Users by Plan -->
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Usuarios por Plano</h3>
          <div class="space-y-3">
            <.distribution_bar
              label="Free"
              count={Map.get(@stats.users_by_plan, "free", 0)}
              total={@stats.users}
              color="bg-gray-500"
            />
            <.distribution_bar
              label="Pro"
              count={Map.get(@stats.users_by_plan, "pro", 0)}
              total={@stats.users}
              color="bg-indigo-500"
            />
            <.distribution_bar
              label="Enterprise"
              count={Map.get(@stats.users_by_plan, "enterprise", 0)}
              total={@stats.users}
              color="bg-purple-500"
            />
          </div>
        </div>
      </div>
      <!-- Registrations Chart -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
          Novos Usuarios (30 dias)
        </h3>
        <div
          id="registrations-chart"
          phx-hook="AdminRegistrationsChart"
          data-registrations={Jason.encode!(@registrations)}
          class="h-64"
        >
          <!-- Chart placeholder if no data -->
          <div
            :if={Enum.empty?(@registrations)}
            class="flex items-center justify-center h-full text-gray-500 dark:text-gray-400"
          >
            Sem dados de registro no periodo
          </div>
        </div>
      </div>
      <!-- Recent Activity -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Recent Lessons -->
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Aulas Recentes</h3>
          <div class="space-y-3">
            <div
              :for={lesson <- @activity.lessons}
              class="flex items-start gap-3 p-2 rounded-lg hover:bg-gray-50 dark:hover:bg-slate-700/50"
            >
              <div class="w-8 h-8 rounded-full bg-emerald-100 dark:bg-emerald-900/30 flex items-center justify-center">
                <.icon
                  name="hero-academic-cap"
                  class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
                  <%= lesson.title %>
                </p>
                <p class="text-xs text-gray-500 dark:text-gray-400">
                  <%= lesson.user && lesson.user.name %> - <%= format_relative(lesson.inserted_at) %>
                </p>
              </div>
            </div>
            <div
              :if={Enum.empty?(@activity.lessons)}
              class="text-sm text-gray-500 dark:text-gray-400 text-center py-4"
            >
              Nenhuma aula recente
            </div>
          </div>
        </div>
        <!-- Recent Analyses -->
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Analises Recentes</h3>
          <div class="space-y-3">
            <div
              :for={analysis <- @activity.analyses}
              class="flex items-start gap-3 p-2 rounded-lg hover:bg-gray-50 dark:hover:bg-slate-700/50"
            >
              <div class="w-8 h-8 rounded-full bg-purple-100 dark:bg-purple-900/30 flex items-center justify-center">
                <.icon name="hero-chart-bar" class="h-4 w-4 text-purple-600 dark:text-purple-400" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
                  <%= analysis.lesson && analysis.lesson.title %>
                </p>
                <p class="text-xs text-gray-500 dark:text-gray-400">
                  Score: <%= analysis.overall_score || "-" %> - <%= format_relative(
                    analysis.inserted_at
                  ) %>
                </p>
              </div>
            </div>
            <div
              :if={Enum.empty?(@activity.analyses)}
              class="text-sm text-gray-500 dark:text-gray-400 text-center py-4"
            >
              Nenhuma analise recente
            </div>
          </div>
        </div>
        <!-- Pending Alerts -->
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Alertas Pendentes</h3>
          <div class="space-y-3">
            <div
              :for={alert <- @activity.alerts}
              class="flex items-start gap-3 p-2 rounded-lg hover:bg-gray-50 dark:hover:bg-slate-700/50"
            >
              <div class={[
                "w-8 h-8 rounded-full flex items-center justify-center",
                severity_bg(alert.severity)
              ]}>
                <.icon
                  name="hero-exclamation-triangle"
                  class={"h-4 w-4 " <> severity_icon_color(alert.severity)}
                />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
                  <%= String.capitalize(alert.alert_type) %>
                </p>
                <p class="text-xs text-gray-500 dark:text-gray-400">
                  <%= alert.analysis && alert.analysis.lesson && alert.analysis.lesson.user &&
                    alert.analysis.lesson.user.name %>
                </p>
              </div>
              <.badge variant={severity_variant(alert.severity)}>
                <%= String.capitalize(alert.severity) %>
              </.badge>
            </div>
            <div
              :if={Enum.empty?(@activity.alerts)}
              class="text-sm text-gray-500 dark:text-gray-400 text-center py-4"
            >
              Nenhum alerta pendente
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Component helpers

  defp admin_stat_card(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-4">
      <div class="flex items-center gap-3">
        <div class={[
          "w-10 h-10 rounded-lg flex items-center justify-center",
          stat_bg(@color)
        ]}>
          <.icon name={@icon} class={"h-5 w-5 " <> stat_icon_color(@color)} />
        </div>
        <div>
          <p class="text-2xl font-bold text-gray-900 dark:text-white"><%= @value %></p>
          <p class="text-xs text-gray-500 dark:text-gray-400"><%= @label %></p>
        </div>
      </div>
    </div>
    """
  end

  defp distribution_bar(assigns) do
    percentage =
      if assigns.total > 0, do: Float.round(assigns.count / assigns.total * 100, 1), else: 0

    assigns = assign(assigns, :percentage, percentage)

    ~H"""
    <div>
      <div class="flex items-center justify-between mb-1">
        <span class="text-sm text-gray-700 dark:text-gray-300"><%= @label %></span>
        <span class="text-sm font-medium text-gray-900 dark:text-white">
          <%= @count %> (<%= @percentage %>%)
        </span>
      </div>
      <div class="w-full h-2 bg-gray-200 dark:bg-slate-700 rounded-full overflow-hidden">
        <div class={[@color, "h-full rounded-full transition-all"]} style={"width: #{@percentage}%"}>
        </div>
      </div>
    </div>
    """
  end

  defp stat_bg("indigo"), do: "bg-indigo-100 dark:bg-indigo-900/30"
  defp stat_bg("blue"), do: "bg-blue-100 dark:bg-blue-900/30"
  defp stat_bg("emerald"), do: "bg-emerald-100 dark:bg-emerald-900/30"
  defp stat_bg("purple"), do: "bg-purple-100 dark:bg-purple-900/30"
  defp stat_bg("red"), do: "bg-red-100 dark:bg-red-900/30"
  defp stat_bg(_), do: "bg-gray-100 dark:bg-gray-900/30"

  defp stat_icon_color("indigo"), do: "text-indigo-600 dark:text-indigo-400"
  defp stat_icon_color("blue"), do: "text-blue-600 dark:text-blue-400"
  defp stat_icon_color("emerald"), do: "text-emerald-600 dark:text-emerald-400"
  defp stat_icon_color("purple"), do: "text-purple-600 dark:text-purple-400"
  defp stat_icon_color("red"), do: "text-red-600 dark:text-red-400"
  defp stat_icon_color(_), do: "text-gray-600 dark:text-gray-400"

  defp severity_bg("critical"), do: "bg-red-100 dark:bg-red-900/30"
  defp severity_bg("high"), do: "bg-orange-100 dark:bg-orange-900/30"
  defp severity_bg("medium"), do: "bg-yellow-100 dark:bg-yellow-900/30"
  defp severity_bg(_), do: "bg-blue-100 dark:bg-blue-900/30"

  defp severity_icon_color("critical"), do: "text-red-600 dark:text-red-400"
  defp severity_icon_color("high"), do: "text-orange-600 dark:text-orange-400"
  defp severity_icon_color("medium"), do: "text-yellow-600 dark:text-yellow-400"
  defp severity_icon_color(_), do: "text-blue-600 dark:text-blue-400"

  defp severity_variant("critical"), do: "error"
  defp severity_variant("high"), do: "warning"
  defp severity_variant(_), do: "default"

  defp format_relative(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "agora"
      diff < 3600 -> "#{div(diff, 60)}m atras"
      diff < 86_400 -> "#{div(diff, 3600)}h atras"
      true -> "#{div(diff, 86_400)}d atras"
    end
  end
end
