defmodule Hellen.Repo.Migrations.CreateLessons do
  use Ecto.Migration

  def change do
    create table(:lessons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :video_url, :string
      add :audio_url, :string
      add :duration_seconds, :integer
      add :grade_level, :string
      add :subject, :string
      add :status, :string, default: "pending"
      add :metadata, :map, default: %{}
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:lessons, [:user_id])
    create index(:lessons, [:status])
    create index(:lessons, [:subject])
    create index(:lessons, [:inserted_at])
  end
end
