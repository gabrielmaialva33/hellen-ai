defmodule Hellen.Repo.Migrations.AddStripeFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :stripe_customer_id, :string
    end

    create unique_index(:users, [:stripe_customer_id])

    alter table(:credit_transactions) do
      add :stripe_payment_intent_id, :string
    end
  end
end
