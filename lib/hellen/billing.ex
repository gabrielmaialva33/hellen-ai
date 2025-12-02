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
  """
  def add_credits(%User{} = user, amount, reason, lesson_id \\ nil) when amount > 0 do
    new_balance = user.credits + amount

    Repo.transaction(fn ->
      {:ok, updated_user} =
        user
        |> User.changeset(%{credits: new_balance})
        |> Repo.update()

      {:ok, _transaction} =
        %CreditTransaction{}
        |> CreditTransaction.changeset(%{
          user_id: user.id,
          amount: amount,
          balance_after: new_balance,
          reason: reason,
          lesson_id: lesson_id
        })
        |> Repo.insert()

      updated_user
    end)
  end

  @doc """
  Deducts credits from user account.
  """
  def deduct_credits(%User{} = user, amount, reason, lesson_id \\ nil) when amount > 0 do
    new_balance = user.credits - amount

    if new_balance >= 0 do
      Repo.transaction(fn ->
        {:ok, updated_user} =
          user
          |> User.changeset(%{credits: new_balance})
          |> Repo.update()

        {:ok, _transaction} =
          %CreditTransaction{}
          |> CreditTransaction.changeset(%{
            user_id: user.id,
            amount: -amount,
            balance_after: new_balance,
            reason: reason,
            lesson_id: lesson_id
          })
          |> Repo.insert()

        updated_user
      end)
    else
      {:error, :insufficient_credits}
    end
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
