defmodule HellenWeb.API.CreditController do
  use HellenWeb, :controller

  alias Hellen.Billing

  action_fallback HellenWeb.FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user
    balance = Billing.get_balance(user)

    render(conn, :balance, balance: balance)
  end

  def history(conn, params) do
    user = conn.assigns.current_user
    limit = Map.get(params, "limit", "50") |> String.to_integer()

    transactions = Billing.list_transactions(user.id, limit: limit)
    render(conn, :history, transactions: transactions)
  end
end
