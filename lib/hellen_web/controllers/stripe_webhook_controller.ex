defmodule HellenWeb.StripeWebhookController do
  @moduledoc """
  Controller for handling Stripe webhook events.
  """
  use HellenWeb, :controller

  alias Hellen.Billing.StripeService

  require Logger

  @doc """
  Handles incoming Stripe webhooks.
  Verifies the webhook signature and processes supported events.
  """
  def webhook(conn, _params) do
    payload = conn.assigns[:raw_body]
    signature = get_stripe_signature(conn)

    case verify_webhook(payload, signature) do
      {:ok, %Stripe.Event{} = event} ->
        handle_event(conn, event)

      {:error, reason} ->
        Logger.warning("Stripe webhook verification failed: #{inspect(reason)}")
        send_resp(conn, 400, "Webhook verification failed")
    end
  end

  defp get_stripe_signature(conn) do
    case get_req_header(conn, "stripe-signature") do
      [signature | _] -> signature
      _ -> ""
    end
  end

  defp verify_webhook(payload, signature) do
    webhook_secret = Application.get_env(:stripity_stripe, :webhook_secret)

    if webhook_secret do
      Stripe.Webhook.construct_event(payload, signature, webhook_secret)
    else
      # In development without webhook secret, just parse the payload
      case Jason.decode(payload) do
        {:ok, decoded} -> {:ok, struct(Stripe.Event, atomize_keys(decoded))}
        error -> error
      end
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), atomize_keys(v)} end)
  end

  defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  defp atomize_keys(value), do: value

  defp handle_event(conn, %Stripe.Event{type: type, data: %{object: object}}) do
    Logger.info("Processing Stripe event: #{type}")

    case type do
      "checkout.session.completed" ->
        handle_checkout_completed(conn, object)

      "payment_intent.payment_failed" ->
        handle_payment_failed(conn, object)

      _ ->
        Logger.debug("Unhandled Stripe event type: #{type}")
        send_resp(conn, 200, "Event ignored")
    end
  end

  defp handle_checkout_completed(conn, session) do
    session_map = if is_struct(session), do: Map.from_struct(session), else: session

    case StripeService.handle_checkout_completed(session_map) do
      {:ok, _user} ->
        send_resp(conn, 200, "Credits added")

      {:error, reason} ->
        Logger.error("Failed to process checkout: #{inspect(reason)}")
        send_resp(conn, 200, "Processed with errors")
    end
  end

  defp handle_payment_failed(conn, payment_intent) do
    payment_map =
      if is_struct(payment_intent), do: Map.from_struct(payment_intent), else: payment_intent

    StripeService.handle_payment_failed(payment_map)
    send_resp(conn, 200, "Payment failure recorded")
  end
end
