defmodule Hellen.Billing.CreditTransaction do
  @moduledoc """
  Schema for credit transactions tracking usage and purchases.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "credit_transactions" do
    field :amount, :integer
    field :balance_after, :integer
    field :reason, :string
    field :metadata, :map, default: %{}
    field :stripe_payment_intent_id, :string

    belongs_to :user, Hellen.Accounts.User
    belongs_to :lesson, Hellen.Lessons.Lesson

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @reasons ["signup_bonus", "lesson_analysis", "purchase", "refund", "gift", "promo"]

  @doc false
  def changeset(credit_transaction, attrs) do
    credit_transaction
    |> cast(attrs, [
      :amount,
      :balance_after,
      :reason,
      :metadata,
      :user_id,
      :lesson_id,
      :stripe_payment_intent_id
    ])
    |> validate_required([:amount, :balance_after, :reason, :user_id])
    |> validate_inclusion(:reason, @reasons)
    |> validate_number(:balance_after, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:lesson_id)
  end
end
