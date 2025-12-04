defmodule HellenWeb.AlertsLive.Index do
  @moduledoc """
  Centralized alerts panel for bullying and legislation compliance monitoring.
  Shows alerts by severity with filtering and review capabilities.
  """
  use HellenWeb, :live_view

  alias Hellen.Analysis

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(page_title: "Alertas")
     |> assign(filter: :all)
     |> load_alerts_async(user)}
  end

  defp load_alerts_async(socket, user) do
    if connected?(socket) and user.institution_id do
      start_async(socket, :load_alerts, fn ->
        alerts = Analysis.list_alerts_by_institution(user.institution_id, limit: 100)
        stats = Analysis.get_alert_stats(user.institution_id)
        %{alerts: alerts, stats: stats}
      end)
    else
      socket
      |> assign(alerts: [])
      |> assign(stats: %{total: 0, unreviewed: 0, reviewed: 0, by_severity: %{}, by_type: %{}})
    end
  end

  @impl true
  def handle_async(:load_alerts, {:ok, data}, socket) do
    {:noreply,
     socket
     |> assign(alerts: data.alerts)
     |> assign(stats: data.stats)}
  end

  def handle_async(:load_alerts, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(alerts: [])
     |> assign(stats: %{total: 0, unreviewed: 0, reviewed: 0, by_severity: %{}, by_type: %{}})
     |> put_flash(:error, "Erro ao carregar alertas")}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    filter =
      case status do
        "all" -> :all
        "unreviewed" -> :unreviewed
        "reviewed" -> :reviewed
        _ -> :all
      end

    {:noreply, assign(socket, filter: filter)}
  end

  def handle_event("review", %{"id" => alert_id}, socket) do
    user = socket.assigns.current_user

    case Analysis.review_bullying_alert(alert_id, user.id) do
      {:ok, _alert} ->
        {:noreply,
         socket
         |> load_alerts_async(user)
         |> put_flash(:info, "Alerta marcado como revisado")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao revisar alerta")}
    end
  end

  defp filtered_alerts(alerts, :all), do: alerts
  defp filtered_alerts(alerts, :unreviewed), do: Enum.filter(alerts, &(!&1.reviewed))
  defp filtered_alerts(alerts, :reviewed), do: Enum.filter(alerts, & &1.reviewed)

  @impl true
  def render(assigns) do
    filtered = filtered_alerts(assigns[:alerts] || [], assigns.filter)
    assigns = assign(assigns, :filtered_alerts, filtered)

    ~H"""
    <div class="space-y-6">
      <.page_header title="Alertas" description="Monitoramento de bullying e conformidade legal">
        <:actions>
          <div class="flex items-center gap-2">
            <.badge :if={@stats.unreviewed > 0} variant="error">
              <%= @stats.unreviewed %> não revisados
            </.badge>
          </div>
        </:actions>
      </.page_header>
      <!-- Stats Cards -->
      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <.stat_card
          title="Total de Alertas"
          value={@stats.total}
          icon="hero-bell-alert"
          variant="default"
        />
        <.stat_card
          title="Não Revisados"
          value={@stats.unreviewed}
          icon="hero-exclamation-circle"
          variant="pending"
        />
        <.stat_card
          title="Revisados"
          value={@stats.reviewed}
          icon="hero-check-circle"
          variant="success"
        />
        <.stat_card
          title="Alta Severidade"
          value={(@stats.by_severity["high"] || 0) + (@stats.by_severity["critical"] || 0)}
          icon="hero-fire"
          variant="error"
        />
      </div>
      <!-- Charts Row -->
      <div :if={@stats.total > 0} class="grid gap-6 lg:grid-cols-2">
        <.card>
          <:header>
            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Por Severidade</h2>
          </:header>
          <div
            id="severity-chart"
            phx-hook="AlertsChart"
            phx-update="ignore"
            data-chart-data={Jason.encode!(@stats)}
            data-chart-type="severity"
          >
          </div>
        </.card>

        <.card>
          <:header>
            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Por Tipo</h2>
          </:header>
          <div
            id="type-chart"
            phx-hook="AlertsChart"
            phx-update="ignore"
            data-chart-data={Jason.encode!(@stats)}
            data-chart-type="type"
          >
          </div>
        </.card>
      </div>
      <!-- Filters -->
      <div class="flex items-center gap-2">
        <span class="text-sm text-gray-500 dark:text-gray-400">Filtrar:</span>
        <button
          :for={
            {value, label} <- [
              {"all", "Todos"},
              {"unreviewed", "Não revisados"},
              {"reviewed", "Revisados"}
            ]
          }
          type="button"
          phx-click="filter"
          phx-value-status={value}
          class={[
            "px-3 py-1.5 text-sm rounded-lg transition-colors",
            @filter == String.to_atom(value) &&
              "bg-indigo-100 dark:bg-indigo-900/50 text-indigo-700 dark:text-indigo-300 font-medium",
            @filter != String.to_atom(value) &&
              "bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-slate-600"
          ]}
        >
          <%= label %>
        </button>
      </div>
      <!-- Alerts List -->
      <div class="space-y-4">
        <.alert_card :for={alert <- @filtered_alerts} alert={alert} />

        <.empty_state
          :if={length(@filtered_alerts) == 0}
          icon="hero-bell-slash"
          title="Nenhum alerta encontrado"
          description={
            if @filter == :all,
              do: "Nenhum alerta de bullying foi detectado ainda.",
              else: "Nenhum alerta corresponde ao filtro selecionado."
          }
        />
      </div>
      <!-- Legal References -->
      <.card>
        <:header>
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
            Referências Legais
          </h2>
        </:header>
        <div class="grid gap-4 sm:grid-cols-2">
          <div class="p-4 rounded-lg bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800">
            <h3 class="font-semibold text-blue-900 dark:text-blue-300">Lei 13.185/2015</h3>
            <p class="mt-1 text-sm text-blue-700 dark:text-blue-400">
              Programa de Combate à Intimidação Sistemática (Bullying)
            </p>
          </div>
          <div class="p-4 rounded-lg bg-purple-50 dark:bg-purple-900/20 border border-purple-200 dark:border-purple-800">
            <h3 class="font-semibold text-purple-900 dark:text-purple-300">Lei 14.811/2024</h3>
            <p class="mt-1 text-sm text-purple-700 dark:text-purple-400">
              Tipificação do crime de bullying e cyberbullying
            </p>
          </div>
        </div>
      </.card>
    </div>
    """
  end

  defp alert_card(assigns) do
    ~H"""
    <div class={[
      "p-4 rounded-xl border",
      !@alert.reviewed && "bg-white dark:bg-slate-800 border-gray-200 dark:border-slate-700",
      @alert.reviewed &&
        "bg-gray-50 dark:bg-slate-800/50 border-gray-200 dark:border-slate-700 opacity-75"
    ]}>
      <div class="flex items-start justify-between gap-4">
        <div class="flex items-start gap-3">
          <div class={[
            "flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center",
            @alert.severity == "critical" && "bg-red-100 dark:bg-red-900/30",
            @alert.severity == "high" && "bg-orange-100 dark:bg-orange-900/30",
            @alert.severity == "medium" && "bg-yellow-100 dark:bg-yellow-900/30",
            @alert.severity == "low" && "bg-green-100 dark:bg-green-900/30"
          ]}>
            <.icon
              name={severity_icon(@alert.severity)}
              class={"h-5 w-5 #{severity_icon_color(@alert.severity)}"}
            />
          </div>
          <div class="flex-1">
            <div class="flex items-center gap-2 mb-1">
              <span class={[
                "px-2 py-0.5 text-xs font-medium rounded-full",
                @alert.severity == "critical" &&
                  "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400",
                @alert.severity == "high" &&
                  "bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-400",
                @alert.severity == "medium" &&
                  "bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400",
                @alert.severity == "low" &&
                  "bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400"
              ]}>
                <%= severity_label(@alert.severity) %>
              </span>
              <span class="px-2 py-0.5 text-xs font-medium rounded-full bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-400">
                <%= type_label(@alert.alert_type) %>
              </span>
              <span :if={@alert.reviewed} class="text-xs text-green-600 dark:text-green-400">
                ✓ Revisado
              </span>
            </div>
            <p class="text-sm text-gray-900 dark:text-white font-medium">
              <%= @alert.description || "Alerta de comportamento detectado" %>
            </p>
            <p :if={@alert.evidence_text} class="mt-1 text-sm text-gray-500 dark:text-gray-400 italic">
              "<%= String.slice(@alert.evidence_text, 0, 200) %><%= if String.length(
                                                                         @alert.evidence_text || ""
                                                                       ) > 200, do: "..." %>"
            </p>
            <div class="mt-2 flex items-center gap-4 text-xs text-gray-500 dark:text-gray-400">
              <span :if={@alert.analysis && @alert.analysis.lesson}>
                <.icon name="hero-academic-cap" class="h-3 w-3 inline mr-1" />
                <%= @alert.analysis.lesson.title || "Aula sem título" %>
              </span>
              <span>
                <.icon name="hero-calendar" class="h-3 w-3 inline mr-1" />
                <%= format_datetime(@alert.inserted_at) %>
              </span>
            </div>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <.link
            :if={@alert.analysis && @alert.analysis.lesson}
            navigate={~p"/lessons/#{@alert.analysis.lesson.id}"}
            class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-slate-700 text-gray-500 dark:text-gray-400"
            title="Ver aula"
          >
            <.icon name="hero-eye" class="h-5 w-5" />
          </.link>
          <button
            :if={!@alert.reviewed}
            type="button"
            phx-click="review"
            phx-value-id={@alert.id}
            class="p-2 rounded-lg hover:bg-green-100 dark:hover:bg-green-900/30 text-gray-500 hover:text-green-600 dark:text-gray-400 dark:hover:text-green-400"
            title="Marcar como revisado"
          >
            <.icon name="hero-check" class="h-5 w-5" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp severity_icon("critical"), do: "hero-fire"
  defp severity_icon("high"), do: "hero-exclamation-triangle"
  defp severity_icon("medium"), do: "hero-exclamation-circle"
  defp severity_icon(_), do: "hero-information-circle"

  defp severity_icon_color("critical"), do: "text-red-600 dark:text-red-400"
  defp severity_icon_color("high"), do: "text-orange-600 dark:text-orange-400"
  defp severity_icon_color("medium"), do: "text-yellow-600 dark:text-yellow-400"
  defp severity_icon_color("low"), do: "text-green-600 dark:text-green-400"
  defp severity_icon_color(_), do: "text-gray-600 dark:text-gray-400"

  defp severity_label("critical"), do: "Crítico"
  defp severity_label("high"), do: "Alto"
  defp severity_label("medium"), do: "Médio"
  defp severity_label("low"), do: "Baixo"
  defp severity_label(_), do: "Indefinido"

  defp type_label("verbal_aggression"), do: "Agressão Verbal"
  defp type_label("exclusion"), do: "Exclusão"
  defp type_label("intimidation"), do: "Intimidação"
  defp type_label("mockery"), do: "Zombaria"
  defp type_label("discrimination"), do: "Discriminação"
  defp type_label("threat"), do: "Ameaça"
  defp type_label("inappropriate_language"), do: "Linguagem Imprópria"
  defp type_label("other"), do: "Outros"
  defp type_label(_), do: "Indefinido"
end
