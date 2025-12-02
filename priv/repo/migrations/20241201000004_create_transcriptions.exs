defmodule Hellen.Repo.Migrations.CreateTranscriptions do
  use Ecto.Migration

  def change do
    create table(:transcriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :full_text, :text
      add :language, :string, default: "pt-BR"
      add :confidence_score, :float
      add :word_count, :integer
      add :segments, {:array, :map}, default: []
      add :lesson_id, references(:lessons, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:transcriptions, [:lesson_id])
  end
end
