defmodule Hellen.Repo.Migrations.AddFirebaseFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :firebase_uid, :string
      add :email_verified, :boolean, default: false
    end

    create unique_index(:users, [:firebase_uid])
  end
end
