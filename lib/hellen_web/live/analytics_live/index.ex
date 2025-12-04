defmodule HellenWeb.AnalyticsLive.Index do
  @moduledoc """
  Advanced analytics page with trend comparisons, BNCC coverage, and data exports.
  """
  use HellenWeb, :live_view

  alias Hellen.Analysis
  alias Hellen.Exports

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(page_title: "Analytics")
     |> assign(period: 30)
     |> assign(active_tab: :overview)
     |> load_analytics_data(user)}
  end

  defp load_analytics_data(socket, user) do
    period = socket.assigns.period

    socket
    |> assign(score_comparison: Analysis.get_score_comparison(user.id, days: period))
    |> assign(daily_scores: Analysis.get_daily_scores(user.id, days: period))
    |> assign(bncc_coverage: Analysis.get_bncc_coverage_detailed(user.id, days: period * 3))
    |> assign(score_history: Analysis.get_user_score_history(user.id, limit: 20))
    |> maybe_load_institution_data(user)
  end

  defp maybe_load_institution_data(socket, user) do
    if user.institution_id do
      socket
      |> assign(
        institution_comparison:
          Analysis.get_institution_comparison(user.institution_id, days: socket.assigns.period)
      )
      |> assign(
        alert_timeline:
          Analysis.get_alert_timeline(user.institution_id, days: socket.assigns.period)
      )
    else
      socket
      |> assign(institution_comparison: nil)
      |> assign(alert_timeline: [])
    end
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) do
    period = String.to_integer(period)

    {:noreply,
     socket
     |> assign(period: period)
     |> load_analytics_data(socket.assigns.current_user)}
  end

  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: String.to_existing_atom(tab))}
  end

  def handle_event("export_csv", %{"type" => type}, socket) do
    user = socket.assigns.current_user
    period = socket.assigns.period

    {filename, csv_content} =
      case type do
        "scores" ->
          {"scores_#{Date.to_string(Date.utc_today())}.csv",
           Exports.generate_csv(:score_history, user.id, days: period * 3)}

        "bncc" ->
          {"bncc_coverage_#{Date.to_string(Date.utc_today())}.csv",
           Exports.generate_csv(:bncc_coverage, user.id, days: period * 3)}

        "daily" ->
          {"daily_scores_#{Date.to_string(Date.utc_today())}.csv",
           Exports.generate_csv(:daily_scores, user.id, days: period)}

        _ ->
          {"export.csv", ""}
      end

    {:noreply,
     socket
     |> push_event("download_csv", %{filename: filename, content: csv_content})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Analytics</h1>
          <p class="text-sm text-gray-500 dark:text-gray-400">
            Tendencias, comparativos e insights detalhados
          </p>
        </div>

        <div class="flex items-center gap-4">
          <!-- Period Selector -->
          <div class="flex items-center gap-2">
            <span class="text-sm text-gray-500 dark:text-gray-400">Periodo:</span>
            <select
              phx-change="change_period"
              name="period"
              class="rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 text-sm"
            >
              <option value="7" selected={@period == 7}>7 dias</option>
              <option value="30" selected={@period == 30}>30 dias</option>
              <option value="90" selected={@period == 90}>90 dias</option>
              <option value="365" selected={@period == 365}>12 meses</option>
            </select>
          </div>
          <!-- Export Dropdown -->
          <div class="relative" phx-click-away="close_export_menu">
            <button
              type="button"
              phx-click={JS.toggle(to: "#export-menu")}
              class="inline-flex items-center px-4 py-2 bg-white dark:bg-slate-700 border border-gray-300 dark:border-slate-600 rounded-lg text-sm font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-slate-600"
            >
              <.icon name="hero-arrow-down-tray" class="h-4 w-4 mr-2" /> Exportar
            </button>
            <div
              id="export-menu"
              class="hidden absolute right-0 mt-2 w-48 bg-white dark:bg-slate-800 rounded-lg shadow-lg border border-gray-200 dark:border-slate-700 py-1 z-10"
            >
              <button
                phx-click="export_csv"
                phx-value-type="scores"
                class="w-full text-left px-4 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-slate-700"
              >
                Historico de Scores (CSV)
              </button>
              <button
                phx-click="export_csv"
                phx-value-type="bncc"
                class="w-full text-left px-4 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-slate-700"
              >
                Cobertura BNCC (CSV)
              </button>
              <button
                phx-click="export_csv"
                phx-value-type="daily"
                class="w-full text-left px-4 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-slate-700"
              >
                Scores Diarios (CSV)
              </button>
            </div>
          </div>
        </div>
      </div>
      <!-- Tabs -->
      <div class="border-b border-gray-200 dark:border-slate-700">
        <nav class="-mb-px flex space-x-8">
          <.tab_button active={@active_tab == :overview} tab="overview" label="Visao Geral" />
          <.tab_button active={@active_tab == :bncc} tab="bncc" label="Cobertura BNCC" />
          <.tab_button active={@active_tab == :trends} tab="trends" label="Tendencias" />
          <.tab_button
            :if={@institution_comparison}
            active={@active_tab == :comparison}
            tab="comparison"
            label="Comparativo"
          />
        </nav>
      </div>
      <!-- Tab Content -->
      <div class="space-y-6">
        <!-- Overview Tab -->
        <div :if={@active_tab == :overview}>
          <!-- Score Comparison Cards -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <.comparison_card
              title="Score Atual"
              value={Float.round(@score_comparison.current_avg, 1)}
              previous={Float.round(@score_comparison.previous_avg, 1)}
              change={@score_comparison.change_percent}
              trend={@score_comparison.trend}
              suffix="/100"
            />
            <.comparison_card
              :if={@institution_comparison}
              title="vs. Instituicao"
              value={@institution_comparison.institution_avg}
              suffix="/100"
              subtext={"Media plataforma: #{@institution_comparison.platform_avg}"}
            />
            <.comparison_card
              :if={@institution_comparison}
              title="Ranking"
              value={@institution_comparison.rank}
              suffix={"/ #{@institution_comparison.total_institutions}"}
              subtext={"Percentil #{@institution_comparison.percentile}%"}
            />
          </div>
          <!-- Score History Chart -->
          <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              Evolucao de Scores
            </h3>
            <div
              id="score-chart"
              phx-hook="AnalyticsChart"
              data-type="line"
              data-chart={Jason.encode!(build_score_chart_data(@daily_scores))}
              class="h-64"
            >
              <div class="flex items-center justify-center h-full text-gray-500">
                <.icon name="hero-chart-bar" class="h-8 w-8 mr-2" /> Carregando grafico...
              </div>
            </div>
          </div>
          <!-- Recent Analyses -->
          <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              Analises Recentes
            </h3>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200 dark:divide-slate-700">
                <thead>
                  <tr>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                      Data
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                      Aula
                    </th>
                    <th class="px-4 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                      Score
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 dark:divide-slate-700">
                  <tr
                    :for={item <- @score_history}
                    class="hover:bg-gray-50 dark:hover:bg-slate-700/50"
                  >
                    <td class="px-4 py-3 text-sm text-gray-500 dark:text-gray-400">
                      <%= Calendar.strftime(item.date, "%d/%m/%Y") %>
                    </td>
                    <td class="px-4 py-3">
                      <.link
                        navigate={~p"/lessons/#{item.lesson_id}"}
                        class="text-sm font-medium text-indigo-600 dark:text-indigo-400 hover:underline"
                      >
                        <%= item.lesson_title %>
                      </.link>
                    </td>
                    <td class="px-4 py-3 text-right">
                      <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{score_color(item.score)}"}>
                        <%= Float.round(item.score, 1) %>
                      </span>
                    </td>
                  </tr>
                  <tr :if={@score_history == []}>
                    <td colspan="3" class="px-4 py-8 text-center text-gray-500 dark:text-gray-400">
                      Nenhuma analise encontrada no periodo.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
        <!-- BNCC Tab -->
        <div :if={@active_tab == :bncc}>
          <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              Competencias BNCC Trabalhadas
            </h3>
            <!-- Category Summary -->
            <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4 mb-6">
              <.bncc_category_card
                :for={{category, items} <- group_by_category(@bncc_coverage)}
                category={category}
                count={length(items)}
              />
            </div>
            <!-- Detailed Table -->
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200 dark:divide-slate-700">
                <thead>
                  <tr>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                      Codigo
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                      Competencia
                    </th>
                    <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                      Categoria
                    </th>
                    <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                      Vezes
                    </th>
                    <th class="px-4 py-3 text-center text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">
                      Score Medio
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 dark:divide-slate-700">
                  <tr
                    :for={item <- @bncc_coverage}
                    class="hover:bg-gray-50 dark:hover:bg-slate-700/50"
                  >
                    <td class="px-4 py-3 text-sm font-mono text-gray-900 dark:text-white">
                      <%= item.code || "N/A" %>
                    </td>
                    <td class="px-4 py-3 text-sm text-gray-700 dark:text-gray-300 max-w-md truncate">
                      <%= item.name || "Sem descricao" %>
                    </td>
                    <td class="px-4 py-3 text-center">
                      <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{category_color(item.category)}"}>
                        <%= item.category %>
                      </span>
                    </td>
                    <td class="px-4 py-3 text-center text-sm text-gray-900 dark:text-white">
                      <%= item.count %>
                    </td>
                    <td class="px-4 py-3 text-center">
                      <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{score_color(item.avg_score)}"}>
                        <%= format_decimal(item.avg_score) %>
                      </span>
                    </td>
                  </tr>
                  <tr :if={@bncc_coverage == []}>
                    <td colspan="5" class="px-4 py-8 text-center text-gray-500 dark:text-gray-400">
                      Nenhuma competencia BNCC registrada no periodo.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
        <!-- Trends Tab -->
        <div :if={@active_tab == :trends}>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Trend Indicator -->
            <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
                Tendencia de Performance
              </h3>
              <div class="flex items-center justify-center py-8">
                <div class="text-center">
                  <div class={"w-24 h-24 mx-auto rounded-full flex items-center justify-center #{trend_bg(@score_comparison.trend)}"}>
                    <.icon
                      name={trend_icon(@score_comparison.trend)}
                      class={"h-12 w-12 #{trend_color(@score_comparison.trend)}"}
                    />
                  </div>
                  <p class={"mt-4 text-2xl font-bold #{trend_color(@score_comparison.trend)}"}>
                    <%= trend_label(@score_comparison.trend) %>
                  </p>
                  <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
                    <%= if @score_comparison.change_percent != 0 do %>
                      <%= if @score_comparison.change_percent > 0, do: "+", else: "" %><%= @score_comparison.change_percent %>% vs. periodo anterior
                    <% else %>
                      Sem variacao significativa
                    <% end %>
                  </p>
                </div>
              </div>
            </div>
            <!-- Period Comparison -->
            <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
                Comparativo de Periodos
              </h3>
              <div class="space-y-6 py-4">
                <div>
                  <div class="flex justify-between text-sm mb-2">
                    <span class="text-gray-600 dark:text-gray-400">
                      Periodo Atual (<%= @period %> dias)
                    </span>
                    <span class="font-medium text-gray-900 dark:text-white">
                      <%= Float.round(@score_comparison.current_avg, 1) %>
                    </span>
                  </div>
                  <div class="h-3 bg-gray-200 dark:bg-slate-700 rounded-full overflow-hidden">
                    <div
                      class="h-full bg-indigo-600 rounded-full transition-all duration-500"
                      style={"width: #{@score_comparison.current_avg}%"}
                    />
                  </div>
                </div>
                <div>
                  <div class="flex justify-between text-sm mb-2">
                    <span class="text-gray-600 dark:text-gray-400">Periodo Anterior</span>
                    <span class="font-medium text-gray-900 dark:text-white">
                      <%= Float.round(@score_comparison.previous_avg, 1) %>
                    </span>
                  </div>
                  <div class="h-3 bg-gray-200 dark:bg-slate-700 rounded-full overflow-hidden">
                    <div
                      class="h-full bg-gray-400 dark:bg-slate-500 rounded-full transition-all duration-500"
                      style={"width: #{@score_comparison.previous_avg}%"}
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>
          <!-- Alert Timeline (Coordinators only) -->
          <div
            :if={@alert_timeline != []}
            class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6 mt-6"
          >
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              Timeline de Alertas
            </h3>
            <div
              id="alert-chart"
              phx-hook="AnalyticsChart"
              data-type="bar"
              data-chart={Jason.encode!(build_alert_chart_data(@alert_timeline))}
              class="h-64"
            >
              <div class="flex items-center justify-center h-full text-gray-500">
                <.icon name="hero-chart-bar" class="h-8 w-8 mr-2" /> Carregando grafico...
              </div>
            </div>
          </div>
        </div>
        <!-- Comparison Tab -->
        <div :if={@active_tab == :comparison && @institution_comparison}>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Institution vs Platform -->
            <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
                Sua Instituicao vs. Plataforma
              </h3>
              <div class="space-y-6 py-4">
                <div>
                  <div class="flex justify-between text-sm mb-2">
                    <span class="text-gray-600 dark:text-gray-400">Sua Instituicao</span>
                    <span class="font-medium text-indigo-600 dark:text-indigo-400">
                      <%= @institution_comparison.institution_avg %>
                    </span>
                  </div>
                  <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded-full overflow-hidden">
                    <div
                      class="h-full bg-indigo-600 rounded-full transition-all duration-500"
                      style={"width: #{@institution_comparison.institution_avg}%"}
                    />
                  </div>
                </div>
                <div>
                  <div class="flex justify-between text-sm mb-2">
                    <span class="text-gray-600 dark:text-gray-400">Media da Plataforma</span>
                    <span class="font-medium text-gray-600 dark:text-gray-400">
                      <%= @institution_comparison.platform_avg %>
                    </span>
                  </div>
                  <div class="h-4 bg-gray-200 dark:bg-slate-700 rounded-full overflow-hidden">
                    <div
                      class="h-full bg-gray-400 dark:bg-slate-500 rounded-full transition-all duration-500"
                      style={"width: #{@institution_comparison.platform_avg}%"}
                    />
                  </div>
                </div>
              </div>
            </div>
            <!-- Ranking Card -->
            <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
                Posicao no Ranking
              </h3>
              <div class="flex items-center justify-center py-8">
                <div class="text-center">
                  <div class="w-32 h-32 mx-auto rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center">
                    <div class="text-white">
                      <span class="text-4xl font-bold"><%= @institution_comparison.rank %></span>
                      <span class="text-lg">/ <%= @institution_comparison.total_institutions %></span>
                    </div>
                  </div>
                  <p class="mt-4 text-lg font-medium text-gray-900 dark:text-white">
                    Top <%= 100 - @institution_comparison.percentile %>%
                  </p>
                  <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                    Percentil <%= @institution_comparison.percentile %>
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <script>
      window.addEventListener("phx:download_csv", (e) => {
        const { filename, content } = e.detail;
        const blob = new Blob([content], { type: "text/csv;charset=utf-8;" });
        const link = document.createElement("a");
        link.href = URL.createObjectURL(blob);
        link.download = filename;
        link.click();
        URL.revokeObjectURL(link.href);
      });
    </script>
    """
  end

  # Components

  defp tab_button(assigns) do
    ~H"""
    <button
      phx-click="change_tab"
      phx-value-tab={@tab}
      class={"py-4 px-1 border-b-2 font-medium text-sm transition-colors " <>
        if @active do
          "border-indigo-500 text-indigo-600 dark:text-indigo-400"
        else
          "border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-gray-300"
        end}
    >
      <%= @label %>
    </button>
    """
  end

  defp comparison_card(assigns) do
    assigns =
      assigns
      |> assign_new(:previous, fn -> nil end)
      |> assign_new(:change, fn -> nil end)
      |> assign_new(:trend, fn -> nil end)
      |> assign_new(:suffix, fn -> "" end)
      |> assign_new(:subtext, fn -> nil end)

    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
      <p class="text-sm font-medium text-gray-500 dark:text-gray-400"><%= @title %></p>
      <div class="mt-2 flex items-baseline">
        <p class="text-3xl font-bold text-gray-900 dark:text-white">
          <%= @value %>
        </p>
        <span :if={@suffix} class="ml-1 text-lg text-gray-500 dark:text-gray-400">
          <%= @suffix %>
        </span>
      </div>
      <div :if={@previous} class="mt-2 flex items-center text-sm">
        <span :if={@trend} class={"flex items-center " <> trend_color(@trend)}>
          <.icon name={trend_icon(@trend)} class="h-4 w-4 mr-1" />
          <%= if @change && @change != 0, do: "#{if @change > 0, do: "+", else: ""}#{@change}%" %>
        </span>
        <span class="ml-2 text-gray-500 dark:text-gray-400">vs. <%= @previous %></span>
      </div>
      <p :if={@subtext} class="mt-2 text-sm text-gray-500 dark:text-gray-400"><%= @subtext %></p>
    </div>
    """
  end

  defp bncc_category_card(assigns) do
    ~H"""
    <div class={"rounded-lg p-4 text-center " <> category_bg(@category)}>
      <p class="text-2xl font-bold text-gray-900 dark:text-white"><%= @count %></p>
      <p class="text-sm font-medium text-gray-600 dark:text-gray-400">
        <%= category_label(@category) %>
      </p>
    </div>
    """
  end

  # Helper functions

  defp build_score_chart_data(daily_scores) do
    %{
      labels: Enum.map(daily_scores, fn d -> Date.to_string(d.date) end),
      datasets: [
        %{
          label: "Score Medio",
          data: Enum.map(daily_scores, fn d -> format_decimal(d.avg_score) end),
          borderColor: "#6366f1",
          backgroundColor: "rgba(99, 102, 241, 0.1)",
          fill: true,
          tension: 0.3
        }
      ]
    }
  end

  defp build_alert_chart_data(alert_timeline) do
    %{
      labels: Enum.map(alert_timeline, fn d -> format_period(d.period) end),
      datasets: [
        %{
          label: "Alta",
          data: Enum.map(alert_timeline, & &1.high),
          backgroundColor: "#ef4444"
        },
        %{
          label: "Media",
          data: Enum.map(alert_timeline, & &1.medium),
          backgroundColor: "#f59e0b"
        },
        %{
          label: "Baixa",
          data: Enum.map(alert_timeline, & &1.low),
          backgroundColor: "#10b981"
        }
      ]
    }
  end

  defp format_period(%Date{} = date), do: Calendar.strftime(date, "%d/%m")
  defp format_period(%DateTime{} = dt), do: Calendar.strftime(dt, "%d/%m")
  defp format_period(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d/%m")
  defp format_period(other), do: to_string(other)

  defp format_decimal(nil), do: 0
  defp format_decimal(%Decimal{} = d), do: Decimal.to_float(d) |> Float.round(1)
  defp format_decimal(f) when is_float(f), do: Float.round(f, 1)
  defp format_decimal(n), do: n

  defp group_by_category(coverage) do
    coverage
    |> Enum.group_by(& &1.category)
    |> Enum.sort_by(fn {_k, v} -> -length(v) end)
  end

  defp score_color(score) when is_nil(score),
    do: "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"

  defp score_color(%Decimal{} = score), do: score |> Decimal.to_float() |> score_color()

  defp score_color(score) when is_number(score) do
    cond do
      score >= 80 ->
        "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400"

      score >= 60 ->
        "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400"

      true ->
        "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400"
    end
  end

  defp category_color("LP"),
    do: "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400"

  defp category_color("MA"),
    do: "bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-400"

  defp category_color("CN"),
    do: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400"

  defp category_color("CH"),
    do: "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400"

  defp category_color("AR"),
    do: "bg-pink-100 text-pink-800 dark:bg-pink-900/30 dark:text-pink-400"

  defp category_color("EF"),
    do: "bg-cyan-100 text-cyan-800 dark:bg-cyan-900/30 dark:text-cyan-400"

  defp category_color("ER"),
    do: "bg-indigo-100 text-indigo-800 dark:bg-indigo-900/30 dark:text-indigo-400"

  defp category_color(_), do: "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"

  defp category_bg("LP"), do: "bg-blue-50 dark:bg-blue-900/20"
  defp category_bg("MA"), do: "bg-purple-50 dark:bg-purple-900/20"
  defp category_bg("CN"), do: "bg-emerald-50 dark:bg-emerald-900/20"
  defp category_bg("CH"), do: "bg-amber-50 dark:bg-amber-900/20"
  defp category_bg("AR"), do: "bg-pink-50 dark:bg-pink-900/20"
  defp category_bg("EF"), do: "bg-cyan-50 dark:bg-cyan-900/20"
  defp category_bg("ER"), do: "bg-indigo-50 dark:bg-indigo-900/20"
  defp category_bg(_), do: "bg-gray-50 dark:bg-gray-900/20"

  defp category_label("LP"), do: "Lingua Portuguesa"
  defp category_label("MA"), do: "Matematica"
  defp category_label("CN"), do: "Ciencias"
  defp category_label("CH"), do: "Ciencias Humanas"
  defp category_label("AR"), do: "Arte"
  defp category_label("EF"), do: "Ed. Fisica"
  defp category_label("ER"), do: "Ensino Religioso"
  defp category_label(cat), do: cat

  defp trend_icon(:improving), do: "hero-arrow-trending-up"
  defp trend_icon(:declining), do: "hero-arrow-trending-down"
  defp trend_icon(:stable), do: "hero-minus"

  defp trend_color(:improving), do: "text-emerald-600 dark:text-emerald-400"
  defp trend_color(:declining), do: "text-red-600 dark:text-red-400"
  defp trend_color(:stable), do: "text-gray-600 dark:text-gray-400"

  defp trend_bg(:improving), do: "bg-emerald-100 dark:bg-emerald-900/30"
  defp trend_bg(:declining), do: "bg-red-100 dark:bg-red-900/30"
  defp trend_bg(:stable), do: "bg-gray-100 dark:bg-gray-900/30"

  defp trend_label(:improving), do: "Em Alta"
  defp trend_label(:declining), do: "Em Baixa"
  defp trend_label(:stable), do: "Estavel"
end
