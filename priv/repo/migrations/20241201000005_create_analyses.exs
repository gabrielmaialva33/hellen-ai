defmodule Hellen.Repo.Migrations.CreateAnalyses do
  use Ecto.Migration

  def change do
    create table(:analyses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :analysis_type, :string, null: false
      add :model_used, :string
      add :raw_response, :map
      add :result, :map
      add :overall_score, :float
      add :processing_time_ms, :integer
      add :tokens_used, :integer
      add :lesson_id, references(:lessons, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:analyses, [:lesson_id])
    create index(:analyses, [:analysis_type])
    create index(:analyses, [:inserted_at])
  end
end
