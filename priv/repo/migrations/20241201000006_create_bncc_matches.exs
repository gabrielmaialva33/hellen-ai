defmodule Hellen.Repo.Migrations.CreateBnccMatches do
  use Ecto.Migration

  def change do
    create table(:bncc_matches, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :competencia_code, :string, null: false
      add :competencia_name, :string
      add :match_score, :float
      add :evidence_text, :text
      add :evidence_timestamp_start, :float
      add :evidence_timestamp_end, :float
      add :analysis_id, references(:analyses, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:bncc_matches, [:analysis_id])
    create index(:bncc_matches, [:competencia_code])
  end
end
