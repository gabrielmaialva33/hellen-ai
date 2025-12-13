defmodule Hellen.Repo.Migrations.CreateTranscriptionAnnotations do
  use Ecto.Migration

  def change do
    create table(:transcription_annotations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text
      add :selection_start, :integer
      add :selection_end, :integer
      add :selection_text, :text
      add :lesson_id, references(:lessons, on_delete: :nothing, type: :binary_id)
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:transcription_annotations, [:lesson_id])
    create index(:transcription_annotations, [:user_id])
  end
end
