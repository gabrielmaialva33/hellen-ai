defmodule Hellen.Repo.Migrations.AddPlannedContentToLessons do
  use Ecto.Migration

  def change do
    alter table(:lessons) do
      add :planned_content, :text
      add :ai_suggestions, :map
    end
  end
end
