defmodule Hellen.Repo.Migrations.CreateInvitations do
  use Ecto.Migration

  def change do
    create table(:invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string
      add :token, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :accepted_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :role, :string, default: "teacher"
      add :invited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :institution_id, references(:institutions, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invitations, [:token])
    create index(:invitations, [:institution_id, :email])
    create index(:invitations, [:invited_by_id])
  end
end
