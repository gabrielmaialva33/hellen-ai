defmodule Hellen.Repo.Migrations.CreateCreditTransactions do
  use Ecto.Migration

  def change do
    create table(:credit_transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :amount, :integer, null: false
      add :balance_after, :integer, null: false
      add :reason, :string, null: false
      add :metadata, :map, default: %{}
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :lesson_id, references(:lessons, on_delete: :nilify_all, type: :binary_id)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:credit_transactions, [:user_id])
    create index(:credit_transactions, [:reason])
    create index(:credit_transactions, [:inserted_at])
  end
end
