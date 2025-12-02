defmodule Hellen.Repo.Migrations.CreateInstitutions do
  use Ecto.Migration

  def change do
    create table(:institutions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :plan, :string, default: "free"
      add :settings, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:institutions, [:plan])
  end
end
