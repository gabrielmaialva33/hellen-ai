defmodule Hellen.Repo.Migrations.CreateLessonCharacters do
  use Ecto.Migration

  def change do
    create table(:lesson_characters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :identifier, :string, null: false
      add :role, :string, null: false
      add :speech_count, :integer
      add :word_count, :integer
      add :characteristics, {:array, :string}, default: []
      add :speech_patterns, :text
      add :key_quotes, {:array, :string}, default: []
      add :sentiment, :string
      add :engagement_level, :string

      add :analysis_id, references(:analyses, on_delete: :delete_all, type: :binary_id),
        null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:lesson_characters, [:analysis_id])
    create index(:lesson_characters, [:role])
  end
end
