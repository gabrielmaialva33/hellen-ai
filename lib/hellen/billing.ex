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
    new_balance = user.credits + amount

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.changeset(user, %{credits: new_balance}))
    |> Ecto.Multi.insert(
      :transaction,
      build_transaction_changeset(user, amount, new_balance, reason, lesson_id)
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
        build_transaction_changeset(user, -amount, new_balance, reason, lesson_id)
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

  defp build_transaction_changeset(user, amount, balance_after, reason, lesson_id) do
    %CreditTransaction{}
    |> CreditTransaction.changeset(%{
      user_id: user.id,
      amount: amount,
      balance_after: balance_after,
      reason: reason,
      lesson_id: lesson_id
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
end
