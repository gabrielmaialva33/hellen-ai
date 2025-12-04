defmodule HellenWeb.Plugs.StripeWebhookPlug do
  @moduledoc """
  Plug to capture raw request body for Stripe webhook signature verification.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case read_body(conn) do
      {:ok, body, conn} ->
        assign(conn, :raw_body, body)

      {:more, _partial, conn} ->
        assign(conn, :raw_body, "")

      {:error, _reason} ->
        assign(conn, :raw_body, "")
    end
  end
end
