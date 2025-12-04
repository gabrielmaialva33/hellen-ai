defmodule Hellen.Repo.Migrations.AddInstitutionToAnalyses do
  use Ecto.Migration

  def change do
    alter table(:analyses) do
      add :institution_id, references(:institutions, type: :binary_id, on_delete: :delete_all)
    end

    create index(:analyses, [:institution_id])
    create index(:analyses, [:institution_id, :lesson_id])

    # Backfill existing analyses with institution_id from lesson
    execute(
      """
      UPDATE analyses a
      SET institution_id = l.institution_id
      FROM lessons l
      WHERE a.lesson_id = l.id AND l.institution_id IS NOT NULL
      """,
      # Rollback: no-op
      "SELECT 1"
    )
  end
end
