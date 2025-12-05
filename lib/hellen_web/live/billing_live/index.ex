defmodule HellenWeb.BillingLive.Index do
  @moduledoc """
  Billing Dashboard - Credits balance, usage stats, history, and package purchase.
  """
  use HellenWeb, :live_view

  alias Hellen.Billing
  alias Hellen.Billing.StripeService

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    stats = Billing.get_usage_stats(user.id, 30)
    {transactions, total} = Billing.list_transactions_filtered(user.id, limit: 10)
    daily_usage = Billing.get_daily_usage(user.id, 30)
    analyses_count = Billing.get_analyses_count(user.id)
    packages = Billing.credit_packages()

    # Subscribe to credits updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Hellen.PubSub, "user:#{user.id}")
    end

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
     |> assign(page: 1)
     |> assign(purchasing: false)
     |> assign(flash_success: nil)
     |> assign(flash_canceled: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      case params do
        %{"success" => "true"} ->
          # Reload user data after successful purchase
          user = Hellen.Accounts.get_user(socket.assigns.current_user.id)
          stats = Billing.get_usage_stats(user.id, 30)
          {transactions, total} = Billing.list_transactions_filtered(user.id, limit: 10)

          socket
          |> assign(current_user: user)
          |> assign(stats: stats)
          |> assign(transactions: transactions)
          |> assign(transactions_total: total)
          |> put_flash(:info, "Pagamento confirmado! Creditos adicionados com sucesso.")

        %{"canceled" => "true"} ->
          socket
          |> put_flash(:error, "Pagamento cancelado.")

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:credits_updated, new_balance}, socket) do
    user = %{socket.assigns.current_user | credits: new_balance}
    stats = Billing.get_usage_stats(user.id, 30)
    {transactions, total} = Billing.list_transactions_filtered(user.id, limit: 10)

    {:noreply,
     socket
     |> assign(current_user: user)
     |> assign(stats: stats)
     |> assign(transactions: transactions)
     |> assign(transactions_total: total)}
  end

  # PWA OfflineIndicator hook events - ignore silently
  @impl true
  def handle_event("online", _params, socket), do: {:noreply, socket}
  def handle_event("offline", _params, socket), do: {:noreply, socket}

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
    {:noreply,
     assign(socket, show_purchase_modal: false, selected_package: nil, purchasing: false)}
  end

  def handle_event("purchase", %{"package" => package_id}, socket) do
    socket = assign(socket, purchasing: true)
    user = socket.assigns.current_user
    base_url = HellenWeb.Endpoint.url()

    case StripeService.create_checkout_session(user, package_id, base_url) do
      {:ok, checkout_url} ->
        {:noreply, redirect(socket, external: checkout_url)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(purchasing: false)
         |> put_flash(:error, "Erro ao criar sessao de pagamento. Tente novamente.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6 animate-fade-in">
      <!-- Header -->
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900 dark:text-white tracking-tight">
            Creditos
          </h1>
          <p class="mt-1 text-slate-500 dark:text-slate-400">
            Gerencie seus creditos e acompanhe seu uso
          </p>
        </div>
      </div>

      <!-- Stats Cards -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <.billing_stat_card
          label="Saldo Atual"
          value={@current_user.credits}
          icon="hero-bolt"
          color="teal"
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
          color="violet"
        />
      </div>

      <!-- Usage Chart -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-card border border-slate-200/50 dark:border-slate-700/50 p-6">
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-chart-bar-square" class="h-5 w-5 text-teal-600 dark:text-teal-400" />
          <h3 class="text-lg font-semibold text-slate-900 dark:text-white">
            Uso de Creditos (30 dias)
          </h3>
        </div>
        <div
          id="usage-chart"
          phx-hook="BillingUsageChart"
          data-usage={Jason.encode!(@daily_usage)}
          class="h-64"
        >
          <div
            :if={Enum.all?(@daily_usage, fn d -> d.used == 0 and d.added == 0 end)}
            class="flex items-center justify-center h-full text-slate-500 dark:text-slate-400"
          >
            <div class="text-center">
              <.icon name="hero-chart-bar" class="h-12 w-12 mx-auto text-slate-300 dark:text-slate-600 mb-2" />
              <p>Sem movimentacao no periodo</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Credit Packages -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-card border border-slate-200/50 dark:border-slate-700/50 p-6">
        <div class="flex items-center gap-2 mb-6">
          <.icon name="hero-shopping-cart" class="h-5 w-5 text-sage-600 dark:text-sage-400" />
          <h3 class="text-lg font-semibold text-slate-900 dark:text-white">Comprar Creditos</h3>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div
            :for={package <- @packages}
            class={[
              "relative rounded-xl border-2 p-6 cursor-pointer transition-all duration-300 hover:shadow-lg group",
              if(package[:popular],
                do: "border-teal-500 dark:border-teal-400 bg-teal-50/50 dark:bg-teal-900/10",
                else:
                  "border-slate-200 dark:border-slate-700 hover:border-teal-300 dark:hover:border-teal-600"
              )
            ]}
            phx-click="show_purchase_modal"
            phx-value-package={package.id}
          >
            <div :if={package[:popular]} class="absolute -top-3 left-1/2 -translate-x-1/2">
              <span class="px-3 py-1 text-xs font-medium text-white bg-gradient-to-r from-teal-500 to-sage-500 rounded-full shadow-sm">
                Popular
              </span>
            </div>
            <div class="text-center">
              <div class="w-14 h-14 mx-auto mb-4 rounded-xl bg-teal-100 dark:bg-teal-900/30 flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                <.icon name="hero-bolt" class="h-7 w-7 text-teal-600 dark:text-teal-400" />
              </div>
              <p class="text-3xl font-bold text-slate-900 dark:text-white"><%= package.credits %></p>
              <p class="text-sm text-slate-500 dark:text-slate-400">creditos</p>
              <p class="mt-4 text-2xl font-bold text-teal-600 dark:text-teal-400">
                <%= package.price_display %>
              </p>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                R$ <%= Float.round(package.price / 100 / package.credits, 2) %>/credito
              </p>
            </div>
          </div>
        </div>
        <div class="mt-6 flex items-center justify-center gap-2 text-sm text-slate-500 dark:text-slate-400">
          <.icon name="hero-lock-closed" class="h-4 w-4" />
          <span>Pagamento seguro via Stripe</span>
        </div>
      </div>

      <!-- Transaction History -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-card border border-slate-200/50 dark:border-slate-700/50 overflow-hidden">
        <div class="p-6 border-b border-slate-200 dark:border-slate-700">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <.icon name="hero-clock" class="h-5 w-5 text-ochre-600 dark:text-ochre-400" />
              <h3 class="text-lg font-semibold text-slate-900 dark:text-white">Historico</h3>
            </div>
            <select
              phx-change="filter_transactions"
              name="reason"
              class="text-sm rounded-xl border-slate-200 dark:border-slate-600 dark:bg-slate-700/50 dark:text-white focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-all duration-200"
            >
              <option value="">Todos os tipos</option>
              <option value="lesson_analysis" selected={@filter_reason == "lesson_analysis"}>
                Analise de Aula
              </option>
              <option value="purchase" selected={@filter_reason == "purchase"}>Compra</option>
              <option value="signup_bonus" selected={@filter_reason == "signup_bonus"}>
                Bonus de Cadastro
              </option>
              <option value="refund" selected={@filter_reason == "refund"}>Reembolso</option>
            </select>
          </div>
        </div>

        <div class="divide-y divide-slate-200 dark:divide-slate-700">
          <div
            :for={transaction <- @transactions}
            class="p-4 flex items-center justify-between hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors"
          >
            <div class="flex items-center gap-3">
              <div class={[
                "w-10 h-10 rounded-xl flex items-center justify-center",
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
                <p class="text-sm font-medium text-slate-900 dark:text-white">
                  <%= reason_label(transaction.reason) %>
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">
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
              <p class="text-xs text-slate-500 dark:text-slate-400">
                Saldo: <%= transaction.balance_after %>
              </p>
            </div>
          </div>
        </div>

        <div :if={Enum.empty?(@transactions)} class="p-8 text-center">
          <.icon name="hero-inbox" class="h-12 w-12 mx-auto text-slate-300 dark:text-slate-600 mb-2" />
          <p class="text-slate-500 dark:text-slate-400">Nenhuma transacao encontrada</p>
        </div>

        <div
          :if={length(@transactions) < @transactions_total}
          class="p-4 border-t border-slate-200 dark:border-slate-700"
        >
          <button
            phx-click="load_more_transactions"
            class="w-full py-2.5 text-sm font-medium text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300 transition-colors"
          >
            Carregar mais (<%= @transactions_total - length(@transactions) %> restantes)
          </button>
        </div>
      </div>

      <!-- Purchase Modal -->
      <div
        :if={@show_purchase_modal && @selected_package}
        class="fixed inset-0 z-50 overflow-y-auto"
        aria-modal="true"
      >
        <div class="flex min-h-screen items-center justify-center p-4">
          <div class="fixed inset-0 bg-black/60 backdrop-blur-sm" phx-click="close_modal"></div>
          <div class="relative bg-white dark:bg-slate-800 rounded-2xl shadow-xl max-w-md w-full p-6 animate-fade-in-up">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-slate-900 dark:text-white">Comprar Creditos</h3>
              <button
                phx-click="close_modal"
                class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 transition-colors"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>
            </div>

            <div class="text-center py-6">
              <div class="w-20 h-20 mx-auto rounded-2xl bg-gradient-to-br from-teal-100 to-sage-100 dark:from-teal-900/30 dark:to-sage-900/30 flex items-center justify-center mb-4">
                <.icon
                  name="hero-bolt"
                  class="h-10 w-10 text-teal-600 dark:text-teal-400"
                />
              </div>
              <p class="text-4xl font-bold text-slate-900 dark:text-white">
                <%= @selected_package.credits %>
              </p>
              <p class="text-slate-500 dark:text-slate-400">creditos</p>
              <p class="mt-4 text-3xl font-bold text-teal-600 dark:text-teal-400">
                <%= @selected_package.price_display %>
              </p>
            </div>

            <div class="bg-slate-50 dark:bg-slate-900/50 rounded-xl p-4 mb-6">
              <div class="flex items-center gap-3 text-sm text-slate-600 dark:text-slate-300">
                <.icon name="hero-shield-check" class="h-5 w-5 text-emerald-500" />
                <span>Pagamento seguro processado pelo Stripe</span>
              </div>
            </div>

            <div class="flex justify-end gap-3">
              <button
                type="button"
                phx-click="close_modal"
                class="px-4 py-2.5 text-sm font-medium text-slate-700 dark:text-slate-200 bg-slate-100 dark:bg-slate-700 rounded-xl hover:bg-slate-200 dark:hover:bg-slate-600 transition-colors"
              >
                Cancelar
              </button>
              <button
                type="button"
                phx-click="purchase"
                phx-value-package={@selected_package.id}
                disabled={@purchasing}
                class={[
                  "px-6 py-2.5 text-sm font-medium text-white rounded-xl transition-all duration-200",
                  if(@purchasing,
                    do: "bg-teal-400 cursor-not-allowed",
                    else: "bg-teal-600 hover:bg-teal-700 hover:shadow-lg hover:shadow-teal-500/25"
                  )
                ]}
              >
                <%= if @purchasing do %>
                  <span class="flex items-center gap-2">
                    <svg class="animate-spin h-4 w-4" viewBox="0 0 24 24">
                      <circle
                        class="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="4"
                        fill="none"
                      />
                      <path
                        class="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      />
                    </svg>
                    Redirecionando...
                  </span>
                <% else %>
                  Pagar com Stripe
                <% end %>
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
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-card border border-slate-200/50 dark:border-slate-700/50 p-4 group hover:shadow-elevated transition-all duration-300">
      <div class="flex items-center gap-3">
        <div class={[
          "w-11 h-11 rounded-xl flex items-center justify-center transition-transform duration-300 group-hover:scale-110",
          billing_stat_bg(@color)
        ]}>
          <.icon name={@icon} class={"h-5 w-5 " <> billing_stat_icon_color(@color)} />
        </div>
        <div>
          <p class="text-2xl font-bold text-slate-900 dark:text-white tracking-tight"><%= @value %></p>
          <p class="text-xs text-slate-500 dark:text-slate-400"><%= @label %></p>
        </div>
      </div>
    </div>
    """
  end

  defp billing_stat_bg("teal"), do: "bg-teal-100 dark:bg-teal-900/30"
  defp billing_stat_bg("red"), do: "bg-red-100 dark:bg-red-900/30"
  defp billing_stat_bg("emerald"), do: "bg-emerald-100 dark:bg-emerald-900/30"
  defp billing_stat_bg("violet"), do: "bg-violet-100 dark:bg-violet-900/30"
  defp billing_stat_bg(_), do: "bg-slate-100 dark:bg-slate-900/30"

  defp billing_stat_icon_color("teal"), do: "text-teal-600 dark:text-teal-400"
  defp billing_stat_icon_color("red"), do: "text-red-600 dark:text-red-400"
  defp billing_stat_icon_color("emerald"), do: "text-emerald-600 dark:text-emerald-400"
  defp billing_stat_icon_color("violet"), do: "text-violet-600 dark:text-violet-400"
  defp billing_stat_icon_color(_), do: "text-slate-600 dark:text-slate-400"

  defp reason_label("lesson_analysis"), do: "Analise de Aula"
  defp reason_label("signup_bonus"), do: "Bonus de Cadastro"
  defp reason_label("purchase"), do: "Compra de Creditos"
  defp reason_label("refund"), do: "Reembolso"
  defp reason_label(reason), do: reason
end
