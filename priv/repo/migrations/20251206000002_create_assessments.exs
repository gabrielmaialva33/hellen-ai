defmodule Hellen.Repo.Migrations.CreateAssessments do
  use Ecto.Migration

  def change do
    create table(:assessments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :subject, :string, null: false
      add :grade_level, :string, null: false
      add :assessment_type, :string, default: "prova"
      add :difficulty_level, :string, default: "medio"
      add :duration_minutes, :integer
      add :total_points, :decimal, precision: 10, scale: 2
      add :instructions, :text
      add :bncc_codes, {:array, :string}, default: []
      add :questions, :jsonb, default: fragment("'[]'::jsonb")
      add :answer_key, :jsonb, default: fragment("'{}'::jsonb")
      add :rubrics, :jsonb, default: fragment("'{}'::jsonb")
      add :status, :string, default: "draft"
      add :generated_by_ai, :boolean, default: false
      add :embeddings_indexed, :boolean, default: false
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")

      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :institution_id, references(:institutions, on_delete: :nilify_all, type: :binary_id)
      add :source_planning_id, references(:plannings, on_delete: :nilify_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:assessments, [:user_id])
    create index(:assessments, [:institution_id])
    create index(:assessments, [:source_planning_id])
    create index(:assessments, [:status])
    create index(:assessments, [:subject])
    create index(:assessments, [:grade_level])
    create index(:assessments, [:assessment_type])
    create index(:assessments, [:difficulty_level])
    create index(:assessments, [:inserted_at])
    create index(:assessments, [:bncc_codes], using: :gin)
  end
end
