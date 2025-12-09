defmodule Hellen.Repo.Migrations.CreatePlannings do
  use Ecto.Migration

  def change do
    create table(:plannings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :subject, :string, null: false
      add :grade_level, :string, null: false
      add :duration_minutes, :integer
      add :objectives, {:array, :string}, default: []
      add :bncc_codes, {:array, :string}, default: []
      add :content, :jsonb, default: fragment("'{}'::jsonb")
      add :materials, {:array, :string}, default: []
      add :methodology, :text
      add :assessment_criteria, :text
      add :status, :string, default: "draft"
      add :generated_by_ai, :boolean, default: false
      add :embeddings_indexed, :boolean, default: false
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")

      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :institution_id, references(:institutions, on_delete: :nilify_all, type: :binary_id)
      add :source_lesson_id, references(:lessons, on_delete: :nilify_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:plannings, [:user_id])
    create index(:plannings, [:institution_id])
    create index(:plannings, [:source_lesson_id])
    create index(:plannings, [:status])
    create index(:plannings, [:subject])
    create index(:plannings, [:grade_level])
    create index(:plannings, [:inserted_at])
    create index(:plannings, [:bncc_codes], using: :gin)
  end
end
