defmodule HellenWeb.BillingLive.Index do
  @moduledoc """
  Billing Dashboard - Credits balance, usage stats, history, and package purchase.
  """
  use HellenWeb, :live_view

  alias Hellen.Billing

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    stats = Billing.get_usage_stats(user.id, 30)
    {transactions, total} = Billing.list_transactions_filtered(user.id, limit: 10)
    daily_usage = Billing.get_daily_usage(user.id, 30)
    analyses_count = Billing.get_analyses_count(user.id)
    packages = Billing.credit_packages()

    {:ok,
     socket
     |> assign(page_title: "Creditos")
     |> assign(stats: stats)
     |> assign(transactions: transactions)
     |> assign(transactions_total: total)
     |> assign(daily_usage: daily_usage)
     |> assign(analyses_count: analyses_count)
     |> assign(packages: packages)
     |> assign(show_purchase_modal: false)
     |> assign(selected_package: nil)
     |> assign(filter_reason: nil)
     |> assign(page: 1)}
  end

  @impl true
  def handle_event("filter_transactions", %{"reason" => reason}, socket) do
    reason = if reason == "", do: nil, else: reason

    {transactions, total} =
      Billing.list_transactions_filtered(socket.assigns.current_user.id,
        limit: 10,
        reason: reason
      )

    {:noreply,
     socket
     |> assign(transactions: transactions)
     |> assign(transactions_total: total)
     |> assign(filter_reason: reason)
     |> assign(page: 1)}
  end

  def handle_event("load_more_transactions", _params, socket) do
    next_page = socket.assigns.page + 1

    {more_transactions, _total} =
      Billing.list_transactions_filtered(socket.assigns.current_user.id,
        limit: 10,
        offset: (next_page - 1) * 10,
        reason: socket.assigns.filter_reason
      )

    {:noreply,
     socket
     |> assign(transactions: socket.assigns.transactions ++ more_transactions)
     |> assign(page: next_page)}
  end

  def handle_event("show_purchase_modal", %{"package" => package_id}, socket) do
    package = Enum.find(socket.assigns.packages, &(&1.id == package_id))
    {:noreply, socket |> assign(show_purchase_modal: true) |> assign(selected_package: package)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_purchase_modal: false, selected_package: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Creditos</h1>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
            Gerencie seus creditos e acompanhe seu uso
          </p>
        </div>
      </div>
      <!-- Stats Cards -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <.billing_stat_card
          label="Saldo Atual"
          value={@current_user.credits}
          icon="hero-currency-dollar"
          color="indigo"
        />
        <.billing_stat_card
          label="Usados (30d)"
          value={@stats.total_used}
          icon="hero-arrow-trending-down"
          color="red"
        />
        <.billing_stat_card
          label="Adicionados (30d)"
          value={@stats.total_added}
          icon="hero-arrow-trending-up"
          color="emerald"
        />
        <.billing_stat_card
          label="Analises Totais"
          value={@analyses_count}
          icon="hero-chart-bar"
          color="purple"
        />
      </div>
      <!-- Usage Chart -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
          Uso de Creditos (30 dias)
        </h3>
        <div
          id="usage-chart"
          phx-hook="BillingUsageChart"
          data-usage={Jason.encode!(@daily_usage)}
          class="h-64"
        >
          <div
            :if={Enum.all?(@daily_usage, fn d -> d.used == 0 and d.added == 0 end)}
            class="flex items-center justify-center h-full text-gray-500 dark:text-gray-400"
          >
            Sem movimentacao no periodo
          </div>
        </div>
      </div>
      <!-- Credit Packages -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Comprar Creditos</h3>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div
            :for={package <- @packages}
            class={[
              "relative rounded-xl border-2 p-6 cursor-pointer transition-all hover:shadow-lg",
              if(package[:popular],
                do: "border-indigo-500 dark:border-indigo-400",
                else:
                  "border-gray-200 dark:border-slate-700 hover:border-indigo-300 dark:hover:border-indigo-600"
              )
            ]}
            phx-click="show_purchase_modal"
            phx-value-package={package.id}
          >
            <div :if={package[:popular]} class="absolute -top-3 left-1/2 -translate-x-1/2">
              <span class="px-3 py-1 text-xs font-medium text-white bg-indigo-500 rounded-full">
                Popular
              </span>
            </div>
            <div class="text-center">
              <p class="text-3xl font-bold text-gray-900 dark:text-white"><%= package.credits %></p>
              <p class="text-sm text-gray-500 dark:text-gray-400">creditos</p>
              <p class="mt-4 text-2xl font-bold text-indigo-600 dark:text-indigo-400">
                <%= package.price_display %>
              </p>
              <p class="text-xs text-gray-500 dark:text-gray-400">
                R$ <%= Float.round(package.price / 100 / package.credits, 2) %>/credito
              </p>
            </div>
          </div>
        </div>
        <p class="mt-4 text-sm text-gray-500 dark:text-gray-400 text-center">
          Pagamento via Stripe (em breve)
        </p>
      </div>
      <!-- Transaction History -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700">
        <div class="p-6 border-b border-gray-200 dark:border-slate-700">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Historico</h3>
            <select
              phx-change="filter_transactions"
              name="reason"
              class="text-sm rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
            >
              <option value="">Todos os tipos</option>
              <option value="lesson_analysis" selected={@filter_reason == "lesson_analysis"}>
                Analise de Aula
              </option>
              <option value="signup_bonus" selected={@filter_reason == "signup_bonus"}>
                Bonus de Cadastro
              </option>
              <option value="refund" selected={@filter_reason == "refund"}>Reembolso</option>
              <option value="admin_grant" selected={@filter_reason == "admin_grant"}>
                Bonus Admin
              </option>
            </select>
          </div>
        </div>

        <div class="divide-y divide-gray-200 dark:divide-slate-700">
          <div
            :for={transaction <- @transactions}
            class="p-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-slate-700/50"
          >
            <div class="flex items-center gap-3">
              <div class={[
                "w-10 h-10 rounded-full flex items-center justify-center",
                if(transaction.amount > 0,
                  do: "bg-emerald-100 dark:bg-emerald-900/30",
                  else: "bg-red-100 dark:bg-red-900/30"
                )
              ]}>
                <.icon
                  name={if transaction.amount > 0, do: "hero-arrow-down", else: "hero-arrow-up"}
                  class={"h-5 w-5 " <> if(transaction.amount > 0, do: "text-emerald-600 dark:text-emerald-400", else: "text-red-600 dark:text-red-400")}
                />
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900 dark:text-white">
                  <%= reason_label(transaction.reason) %>
                </p>
                <p class="text-xs text-gray-500 dark:text-gray-400">
                  <%= Calendar.strftime(transaction.inserted_at, "%d/%m/%Y %H:%M") %>
                  <%= if transaction.lesson, do: "- #{transaction.lesson.title}" %>
                </p>
              </div>
            </div>
            <div class="text-right">
              <p class={[
                "text-sm font-bold",
                if(transaction.amount > 0,
                  do: "text-emerald-600 dark:text-emerald-400",
                  else: "text-red-600 dark:text-red-400"
                )
              ]}>
                <%= if transaction.amount > 0, do: "+", else: "" %><%= transaction.amount %>
              </p>
              <p class="text-xs text-gray-500 dark:text-gray-400">
                Saldo: <%= transaction.balance_after %>
              </p>
            </div>
          </div>
        </div>

        <div :if={Enum.empty?(@transactions)} class="p-8 text-center text-gray-500 dark:text-gray-400">
          Nenhuma transacao encontrada
        </div>

        <div
          :if={length(@transactions) < @transactions_total}
          class="p-4 border-t border-gray-200 dark:border-slate-700"
        >
          <button
            phx-click="load_more_transactions"
            class="w-full py-2 text-sm font-medium text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300"
          >
            Carregar mais (<%= @transactions_total - length(@transactions) %> restantes)
          </button>
        </div>
      </div>
      <!-- Purchase Modal (Stripe-ready placeholder) -->
      <div
        :if={@show_purchase_modal && @selected_package}
        class="fixed inset-0 z-50 overflow-y-auto"
        aria-modal="true"
      >
        <div class="flex min-h-screen items-center justify-center p-4">
          <div class="fixed inset-0 bg-black/50" phx-click="close_modal"></div>
          <div class="relative bg-white dark:bg-slate-800 rounded-xl shadow-xl max-w-md w-full p-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Comprar Creditos</h3>
              <button
                phx-click="close_modal"
                class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>
            </div>

            <div class="text-center py-6">
              <div class="w-16 h-16 mx-auto rounded-full bg-indigo-100 dark:bg-indigo-900/30 flex items-center justify-center mb-4">
                <.icon
                  name="hero-currency-dollar"
                  class="h-8 w-8 text-indigo-600 dark:text-indigo-400"
                />
              </div>
              <p class="text-4xl font-bold text-gray-900 dark:text-white">
                <%= @selected_package.credits %>
              </p>
              <p class="text-gray-500 dark:text-gray-400">creditos</p>
              <p class="mt-4 text-3xl font-bold text-indigo-600 dark:text-indigo-400">
                <%= @selected_package.price_display %>
              </p>
            </div>

            <div class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg p-4 mb-6">
              <div class="flex items-start gap-3">
                <.icon
                  name="hero-information-circle"
                  class="h-5 w-5 text-amber-600 dark:text-amber-400 flex-shrink-0 mt-0.5"
                />
                <p class="text-sm text-amber-800 dark:text-amber-200">
                  Integracao com Stripe em desenvolvimento. Por enquanto, entre em contato para adquirir creditos.
                </p>
              </div>
            </div>

            <div class="flex justify-end gap-3">
              <button
                type="button"
                phx-click="close_modal"
                class="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-200 bg-gray-100 dark:bg-slate-700 rounded-lg hover:bg-gray-200 dark:hover:bg-slate-600"
              >
                Fechar
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp billing_stat_card(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-4">
      <div class="flex items-center gap-3">
        <div class={[
          "w-10 h-10 rounded-lg flex items-center justify-center",
          billing_stat_bg(@color)
        ]}>
          <.icon name={@icon} class={"h-5 w-5 " <> billing_stat_icon_color(@color)} />
        </div>
        <div>
          <p class="text-2xl font-bold text-gray-900 dark:text-white"><%= @value %></p>
          <p class="text-xs text-gray-500 dark:text-gray-400"><%= @label %></p>
        </div>
      </div>
    </div>
    """
  end

  defp billing_stat_bg("indigo"), do: "bg-indigo-100 dark:bg-indigo-900/30"
  defp billing_stat_bg("red"), do: "bg-red-100 dark:bg-red-900/30"
  defp billing_stat_bg("emerald"), do: "bg-emerald-100 dark:bg-emerald-900/30"
  defp billing_stat_bg("purple"), do: "bg-purple-100 dark:bg-purple-900/30"
  defp billing_stat_bg(_), do: "bg-gray-100 dark:bg-gray-900/30"

  defp billing_stat_icon_color("indigo"), do: "text-indigo-600 dark:text-indigo-400"
  defp billing_stat_icon_color("red"), do: "text-red-600 dark:text-red-400"
  defp billing_stat_icon_color("emerald"), do: "text-emerald-600 dark:text-emerald-400"
  defp billing_stat_icon_color("purple"), do: "text-purple-600 dark:text-purple-400"
  defp billing_stat_icon_color(_), do: "text-gray-600 dark:text-gray-400"

  defp reason_label("lesson_analysis"), do: "Analise de Aula"
  defp reason_label("signup_bonus"), do: "Bonus de Cadastro"
  defp reason_label("refund"), do: "Reembolso"
  defp reason_label("admin_grant"), do: "Bonus Administrativo"
  defp reason_label(reason), do: reason
end
