defmodule Hellen.Billing do
  @moduledoc """
  The Billing context - manages credits and transactions.
  """

  import Ecto.Query, warn: false

  alias Hellen.Accounts.User
  alias Hellen.Billing.CreditTransaction
  alias Hellen.Repo

  @signup_bonus 2

  @doc """
  Grants signup bonus credits to a new user.
  """
  def grant_signup_bonus(%User{} = user) do
    add_credits(user, @signup_bonus, "signup_bonus")
  end

  @doc """
  Checks if user has enough credits.
  """
  def check_credits(%User{credits: credits}) when credits >= 1, do: :ok
  def check_credits(_user), do: {:error, :insufficient_credits}

  @doc """
  Uses one credit for lesson analysis.
  """
  def use_credit(%User{} = user, lesson_id) do
    if user.credits >= 1 do
      deduct_credits(user, 1, "lesson_analysis", lesson_id)
    else
      {:error, :insufficient_credits}
    end
  end

  @doc """
  Adds credits to user account.
  Uses Ecto.Multi for transactional consistency.
  """
  @spec add_credits(User.t(), pos_integer(), String.t(), binary() | nil) ::
          {:ok, User.t()} | {:error, term()}
  def add_credits(%User{} = user, amount, reason, lesson_id \\ nil) when amount > 0 do
    add_credits_internal(user, amount, reason, lesson_id, nil)
  end

  @doc """
  Adds credits with Stripe payment tracking.
  """
  @spec add_credits_with_stripe(User.t(), pos_integer(), String.t(), String.t()) ::
          {:ok, User.t()} | {:error, term()}
  def add_credits_with_stripe(%User{} = user, amount, package_id, payment_intent_id)
      when amount > 0 do
    add_credits_internal(user, amount, "purchase", nil, payment_intent_id, %{
      package_id: package_id
    })
  end

  defp add_credits_internal(
         user,
         amount,
         reason,
         lesson_id,
         stripe_payment_intent_id,
         metadata \\ %{}
       ) do
    new_balance = user.credits + amount

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.changeset(user, %{credits: new_balance}))
    |> Ecto.Multi.insert(
      :transaction,
      build_transaction_changeset(
        user,
        amount,
        new_balance,
        reason,
        lesson_id,
        stripe_payment_intent_id,
        metadata
      )
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{user: updated_user}} -> {:ok, updated_user}
      {:error, _op, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Deducts credits from user account.
  Uses Ecto.Multi for transactional consistency.
  """
  @spec deduct_credits(User.t(), pos_integer(), String.t(), binary() | nil) ::
          {:ok, User.t()} | {:error, :insufficient_credits | term()}
  def deduct_credits(%User{} = user, amount, reason, lesson_id \\ nil) when amount > 0 do
    new_balance = user.credits - amount

    if new_balance >= 0 do
      Ecto.Multi.new()
      |> Ecto.Multi.update(:user, User.changeset(user, %{credits: new_balance}))
      |> Ecto.Multi.insert(
        :transaction,
        build_transaction_changeset(user, -amount, new_balance, reason, lesson_id, nil, %{})
      )
      |> Repo.transaction()
      |> case do
        {:ok, %{user: updated_user}} -> {:ok, updated_user}
        {:error, _op, changeset, _changes} -> {:error, changeset}
      end
    else
      {:error, :insufficient_credits}
    end
  end

  defp build_transaction_changeset(
         user,
         amount,
         balance_after,
         reason,
         lesson_id,
         stripe_payment_intent_id,
         metadata
       ) do
    %CreditTransaction{}
    |> CreditTransaction.changeset(%{
      user_id: user.id,
      amount: amount,
      balance_after: balance_after,
      reason: reason,
      lesson_id: lesson_id,
      stripe_payment_intent_id: stripe_payment_intent_id,
      metadata: metadata
    })
  end

  @doc """
  Gets credit balance for a user.
  """
  def get_balance(%User{credits: credits}), do: credits

  @doc """
  Lists credit transactions for a user.
  """
  def list_transactions(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    CreditTransaction
    |> where([t], t.user_id == ^user_id)
    |> order_by([t], desc: t.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Refunds a credit for a failed analysis.
  """
  def refund_credit(%User{} = user, lesson_id) do
    add_credits(user, 1, "refund", lesson_id)
  end

  @doc """
  Lists credit transactions with filters.
  Supports: reason, start_date, end_date, limit, offset.
  """
  @spec list_transactions_filtered(binary(), keyword()) :: {[CreditTransaction.t()], integer()}
  def list_transactions_filtered(user_id, opts \\ []) do
    reason = Keyword.get(opts, :reason)
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    query =
      CreditTransaction
      |> where([t], t.user_id == ^user_id)
      |> order_by([t], desc: t.inserted_at)

    query =
      if reason && reason != "" do
        where(query, [t], t.reason == ^reason)
      else
        query
      end

    query =
      if start_date do
        where(query, [t], t.inserted_at >= ^start_date)
      else
        query
      end

    query =
      if end_date do
        where(query, [t], t.inserted_at <= ^end_date)
      else
        query
      end

    total = Repo.aggregate(query, :count)

    transactions =
      query
      |> limit(^limit)
      |> offset(^offset)
      |> preload(:lesson)
      |> Repo.all()

    {transactions, total}
  end

  @doc """
  Get usage statistics for a user over a period.
  Returns total used, total added, breakdown by reason, and transaction count.
  """
  @spec get_usage_stats(binary(), integer()) :: map()
  def get_usage_stats(user_id, days \\ 30) do
    start_date = DateTime.utc_now() |> DateTime.add(-days, :day)

    transactions =
      CreditTransaction
      |> where([t], t.user_id == ^user_id and t.inserted_at >= ^start_date)
      |> Repo.all()

    total_used =
      transactions
      |> Enum.filter(&(&1.amount < 0))
      |> Enum.map(& &1.amount)
      |> Enum.sum()
      |> abs()

    total_added =
      transactions
      |> Enum.filter(&(&1.amount > 0))
      |> Enum.map(& &1.amount)
      |> Enum.sum()

    by_reason =
      transactions
      |> Enum.group_by(& &1.reason)
      |> Enum.map(fn {reason, txs} ->
        {reason, %{count: length(txs), amount: Enum.sum(Enum.map(txs, & &1.amount))}}
      end)
      |> Map.new()

    %{
      total_used: total_used,
      total_added: total_added,
      transaction_count: length(transactions),
      by_reason: by_reason,
      period_days: days
    }
  end

  @doc """
  Get daily usage data for charts.
  Returns list of %{date, used, added} for each day.
  """
  @spec get_daily_usage(binary(), integer()) :: [map()]
  def get_daily_usage(user_id, days \\ 30) do
    start_date = Date.utc_today() |> Date.add(-days)

    transactions =
      CreditTransaction
      |> where([t], t.user_id == ^user_id and fragment("?::date", t.inserted_at) >= ^start_date)
      |> Repo.all()

    # Group by date
    by_date =
      transactions
      |> Enum.group_by(fn t -> DateTime.to_date(t.inserted_at) end)

    # Generate all dates in range
    start_date
    |> Date.range(Date.utc_today())
    |> Enum.map(fn date ->
      day_transactions = Map.get(by_date, date, [])

      used =
        day_transactions
        |> Enum.filter(&(&1.amount < 0))
        |> Enum.map(& &1.amount)
        |> Enum.sum()
        |> abs()

      added =
        day_transactions
        |> Enum.filter(&(&1.amount > 0))
        |> Enum.map(& &1.amount)
        |> Enum.sum()

      %{date: date, used: used, added: added}
    end)
  end

  @doc """
  Returns available credit packages for purchase.
  Stripe-ready structure with price in centavos.
  """
  @spec credit_packages() :: [map()]
  def credit_packages do
    [
      %{id: "basic", name: "Basico", credits: 10, price: 2990, price_display: "R$ 29,90"},
      %{
        id: "standard",
        name: "Padrao",
        credits: 30,
        price: 7990,
        price_display: "R$ 79,90",
        popular: true
      },
      %{id: "pro", name: "Profissional", credits: 100, price: 19_990, price_display: "R$ 199,90"}
    ]
  end

  @doc """
  Get count of analyses (lessons analyzed) for a user.
  """
  @spec get_analyses_count(binary()) :: integer()
  def get_analyses_count(user_id) do
    CreditTransaction
    |> where([t], t.user_id == ^user_id and t.reason == "lesson_analysis")
    |> Repo.aggregate(:count)
  end
end
