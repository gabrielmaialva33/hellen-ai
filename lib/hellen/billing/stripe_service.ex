defmodule Hellen.Billing.StripeService do
  @moduledoc """
  Service module for Stripe payment integration.
  Handles checkout sessions, customer management, and webhook processing.
  """

  alias Hellen.Accounts
  alias Hellen.Accounts.User
  alias Hellen.Billing

  require Logger

  @doc """
  Creates or retrieves a Stripe customer for a user.
  """
  @spec get_or_create_customer(User.t()) :: {:ok, String.t()} | {:error, term()}
  def get_or_create_customer(%User{stripe_customer_id: customer_id} = _user)
      when is_binary(customer_id) and customer_id != "" do
    {:ok, customer_id}
  end

  def get_or_create_customer(%User{} = user) do
    case Stripe.Customer.create(%{
           email: user.email,
           name: user.name,
           metadata: %{
             user_id: user.id,
             institution_id: user.institution_id || "none"
           }
         }) do
      {:ok, %Stripe.Customer{id: customer_id}} ->
        Accounts.update_stripe_customer_id(user, customer_id)
        {:ok, customer_id}

      {:error, error} ->
        Logger.error("Failed to create Stripe customer: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Creates a Stripe Checkout session for purchasing credits.
  Supports both card and PIX payment methods.
  """
  @spec create_checkout_session(User.t(), String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def create_checkout_session(%User{} = user, package_id, base_url, payment_method \\ "card") do
    with {:ok, package} <- get_package(package_id),
         {:ok, customer_id} <- get_or_create_customer(user) do
      stripe_config = Application.get_env(:hellen, :stripe)
      success_url = "#{base_url}#{stripe_config[:success_url]}&session_id={CHECKOUT_SESSION_ID}"
      cancel_url = "#{base_url}#{stripe_config[:cancel_url]}"

      # Define payment method types based on selection
      payment_method_types = get_payment_method_types(payment_method)

      params = %{
        customer: customer_id,
        mode: "payment",
        success_url: success_url,
        cancel_url: cancel_url,
        payment_method_types: payment_method_types,
        line_items: [
          %{
            price_data: %{
              currency: "brl",
              product_data: %{
                name: "#{package.name} - #{package.credits} Creditos",
                description: "Pacote de creditos para analise de aulas no Hellen AI"
              },
              unit_amount: package.price
            },
            quantity: 1
          }
        ],
        metadata: %{
          user_id: user.id,
          package_id: package_id,
          credits: package.credits,
          payment_method: payment_method
        },
        payment_intent_data: %{
          metadata: %{
            user_id: user.id,
            package_id: package_id,
            credits: package.credits
          }
        }
      }

      # Add PIX-specific options (expires in 30 minutes)
      params =
        if payment_method == "pix" do
          Map.put(params, :payment_method_options, %{
            pix: %{
              expires_after_seconds: 1800
            }
          })
        else
          params
        end

      case Stripe.Checkout.Session.create(params) do
        {:ok, %Stripe.Checkout.Session{url: url}} ->
          {:ok, url}

        {:error, error} ->
          Logger.error("Failed to create checkout session: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp get_payment_method_types("pix"), do: ["pix"]
  defp get_payment_method_types("card"), do: ["card"]
  defp get_payment_method_types(_), do: ["card", "pix"]

  @doc """
  Handles a completed checkout session webhook.
  Adds credits to the user's account.
  """
  @spec handle_checkout_completed(map()) :: {:ok, User.t()} | {:error, term()}
  def handle_checkout_completed(%{"metadata" => metadata, "payment_intent" => payment_intent_id}) do
    user_id = metadata["user_id"]
    credits = String.to_integer(metadata["credits"])
    package_id = metadata["package_id"]

    Logger.info(
      "Processing checkout completion: user=#{user_id}, credits=#{credits}, package=#{package_id}"
    )

    case Accounts.get_user(user_id) do
      nil ->
        Logger.error("User not found for checkout: #{user_id}")
        {:error, :user_not_found}

      user ->
        case Billing.add_credits_with_stripe(user, credits, package_id, payment_intent_id) do
          {:ok, updated_user} ->
            Logger.info("Credits added successfully: #{credits} credits for user #{user_id}")
            broadcast_credits_updated(user_id, updated_user.credits)
            {:ok, updated_user}

          {:error, reason} ->
            Logger.error("Failed to add credits: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  def handle_checkout_completed(_), do: {:error, :invalid_payload}

  @doc """
  Handles a failed payment webhook.
  """
  @spec handle_payment_failed(map()) :: :ok
  def handle_payment_failed(%{"metadata" => metadata}) do
    user_id = metadata["user_id"]
    Logger.warning("Payment failed for user: #{user_id}")
    # Could notify user here
    :ok
  end

  def handle_payment_failed(_), do: :ok

  @doc """
  Retrieves a checkout session by ID.
  """
  @spec get_session(String.t()) :: {:ok, map()} | {:error, term()}
  def get_session(session_id) do
    Stripe.Checkout.Session.retrieve(session_id)
  end

  @doc """
  Creates a customer portal session for managing payment methods.
  """
  @spec create_portal_session(User.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def create_portal_session(%User{stripe_customer_id: nil}, _base_url) do
    {:error, :no_customer}
  end

  def create_portal_session(%User{stripe_customer_id: customer_id}, base_url) do
    case Stripe.BillingPortal.Session.create(%{
           customer: customer_id,
           return_url: "#{base_url}/billing"
         }) do
      {:ok, %{url: url}} -> {:ok, url}
      {:error, error} -> {:error, error}
    end
  end

  # Private functions

  defp get_package(package_id) do
    case Enum.find(Billing.credit_packages(), &(&1.id == package_id)) do
      nil -> {:error, :package_not_found}
      package -> {:ok, package}
    end
  end

  defp broadcast_credits_updated(user_id, new_balance) do
    Phoenix.PubSub.broadcast(
      Hellen.PubSub,
      "user:#{user_id}",
      {:credits_updated, new_balance}
    )
  end
end
