defmodule Hellen.Repo.Migrations.AddPlannedFileUrlToLessons do
  use Ecto.Migration

  def change do
    alter table(:lessons) do
      add :planned_file_url, :string
      add :planned_file_name, :string
    end
  end
end
