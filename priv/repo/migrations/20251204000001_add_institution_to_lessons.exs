defmodule Hellen.Repo.Migrations.AddInstitutionToLessons do
  use Ecto.Migration

  def change do
    alter table(:lessons) do
      add :institution_id, references(:institutions, type: :binary_id, on_delete: :delete_all)
    end

    create index(:lessons, [:institution_id])
    create index(:lessons, [:institution_id, :user_id])
    create index(:lessons, [:institution_id, :status])
    create index(:lessons, [:institution_id, :subject])

    # Backfill existing lessons with institution_id from user
    execute(
      """
      UPDATE lessons l
      SET institution_id = u.institution_id
      FROM users u
      WHERE l.user_id = u.id AND u.institution_id IS NOT NULL
      """,
      # Rollback: no-op
      "SELECT 1"
    )
  end
end
