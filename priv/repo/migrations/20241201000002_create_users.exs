defmodule Hellen.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string, null: false
      add :password_hash, :string
      add :role, :string, default: "teacher"
      add :credits, :integer, default: 2
      add :plan, :string, default: "free"
      add :institution_id, references(:institutions, on_delete: :nilify_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:institution_id])
    create index(:users, [:role])
    create index(:users, [:plan])
  end
end
