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
     |> assign(payment_method: "card")
     |> assign(flash_success: nil)
     |> assign(flash_canceled: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      case params do
        %{"success" => "true", "session_id" => session_id} ->
          # Verify and process payment if webhook hasn't done it yet
          socket = maybe_process_checkout_session(socket, session_id)

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

        %{"success" => "true"} ->
          # Fallback without session_id
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

  # Fallback: Process checkout session if webhook hasn't processed it yet
  defp maybe_process_checkout_session(socket, session_id) do
    case StripeService.get_session(session_id) do
      {:ok, %{payment_status: "paid", metadata: metadata} = session} ->
        user_id = metadata["user_id"]
        credits = String.to_integer(metadata["credits"] || "0")
        package_id = metadata["package_id"]
        payment_intent = session.payment_intent

        # Only process if this is for the current user
        if user_id == socket.assigns.current_user.id do
          # Check if already processed by looking for this payment_intent
          case Billing.get_transaction_by_payment_intent(payment_intent) do
            nil ->
              # Not yet processed, add credits
              case Billing.add_credits_with_stripe(
                     socket.assigns.current_user,
                     credits,
                     package_id,
                     payment_intent
                   ) do
                {:ok, _user} ->
                  require Logger
                  Logger.info("Credits added via fallback for session: #{session_id}")
                  socket

                {:error, _reason} ->
                  socket
              end

            _transaction ->
              # Already processed via webhook
              socket
          end
        else
          socket
        end

      _ ->
        socket
    end
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
     assign(socket,
       show_purchase_modal: false,
       selected_package: nil,
       purchasing: false,
       payment_method: "card"
     )}
  end

  def handle_event("select_payment_method", %{"method" => method}, socket) do
    {:noreply, assign(socket, payment_method: method)}
  end

  def handle_event("purchase", %{"package" => package_id}, socket) do
    socket = assign(socket, purchasing: true)
    user = socket.assigns.current_user
    base_url = HellenWeb.Endpoint.url()
    payment_method = socket.assigns.payment_method

    case StripeService.create_checkout_session(user, package_id, base_url, payment_method) do
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

            <!-- Payment Method Selection -->
            <div class="mb-6">
              <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-3">
                Forma de pagamento
              </p>
              <div class="grid grid-cols-2 gap-3">
                <button
                  type="button"
                  phx-click="select_payment_method"
                  phx-value-method="card"
                  class={[
                    "p-4 rounded-xl border-2 transition-all duration-200 flex flex-col items-center gap-2",
                    if(@payment_method == "card",
                      do: "border-teal-500 bg-teal-50 dark:bg-teal-900/20",
                      else: "border-slate-200 dark:border-slate-600 hover:border-teal-300"
                    )
                  ]}
                >
                  <.icon
                    name="hero-credit-card"
                    class={"h-8 w-8 " <> if(@payment_method == "card", do: "text-teal-600 dark:text-teal-400", else: "text-slate-400")}
                  />
                  <span class={[
                    "text-sm font-medium",
                    if(@payment_method == "card",
                      do: "text-teal-700 dark:text-teal-300",
                      else: "text-slate-600 dark:text-slate-300"
                    )
                  ]}>
                    Cartao
                  </span>
                </button>
                <button
                  type="button"
                  phx-click="select_payment_method"
                  phx-value-method="pix"
                  class={[
                    "p-4 rounded-xl border-2 transition-all duration-200 flex flex-col items-center gap-2",
                    if(@payment_method == "pix",
                      do: "border-teal-500 bg-teal-50 dark:bg-teal-900/20",
                      else: "border-slate-200 dark:border-slate-600 hover:border-teal-300"
                    )
                  ]}
                >
                  <svg
                    class={[
                      "h-8 w-8",
                      if(@payment_method == "pix",
                        do: "text-teal-600 dark:text-teal-400",
                        else: "text-slate-400"
                      )
                    ]}
                    viewBox="0 0 512 512"
                    fill="currentColor"
                  >
                    <path d="M242.4 292.5C247.8 287.1 257.1 287.1 262.5 292.5L339.5 369.5C344.9 374.9 344.9 384.1 339.5 389.5C334.1 394.9 324.9 394.9 319.5 389.5L262.5 332.5V480C262.5 487.2 256.7 493 249.5 493C242.3 493 236.5 487.2 236.5 480V332.5L179.5 389.5C174.1 394.9 164.9 394.9 159.5 389.5C154.1 384.1 154.1 374.9 159.5 369.5L236.5 292.5C241.9 287.1 251.1 287.1 256.5 292.5H242.4zM377.9 169.9L294.1 253.8C283.7 264.2 267.3 264.2 256.9 253.8L173.1 169.9C162.7 159.5 162.7 143.1 173.1 132.7L256.9 48.9C267.3 38.5 283.7 38.5 294.1 48.9L377.9 132.7C388.3 143.1 388.3 159.5 377.9 169.9zM275.5 71.1L191.6 155C186.2 160.4 186.2 169.6 191.6 175L275.5 258.9C280.9 264.3 290.1 264.3 295.5 258.9L379.4 175C384.8 169.6 384.8 160.4 379.4 155L295.5 71.1C290.1 65.7 280.9 65.7 275.5 71.1zM425.6 219.6L341.7 303.5C336.3 308.9 336.3 318.1 341.7 323.5L425.6 407.4C431 412.8 440.2 412.8 445.6 407.4L529.5 323.5C534.9 318.1 534.9 308.9 529.5 303.5L445.6 219.6C440.2 214.2 431 214.2 425.6 219.6zM65.4 219.6L-18.5 303.5C-23.9 308.9 -23.9 318.1 -18.5 323.5L65.4 407.4C70.8 412.8 80 412.8 85.4 407.4L169.3 323.5C174.7 318.1 174.7 308.9 169.3 303.5L85.4 219.6C80 214.2 70.8 214.2 65.4 219.6z" />
                  </svg>
                  <span class={[
                    "text-sm font-medium",
                    if(@payment_method == "pix",
                      do: "text-teal-700 dark:text-teal-300",
                      else: "text-slate-600 dark:text-slate-300"
                    )
                  ]}>
                    PIX
                  </span>
                </button>
              </div>
              <p :if={@payment_method == "pix"} class="mt-2 text-xs text-slate-500 dark:text-slate-400 text-center">
                QR Code expira em 30 minutos
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
                  Pagar com <%= if @payment_method == "pix", do: "PIX", else: "Cartao" %>
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
