defmodule Hellen.Repo.Migrations.AddOnboardingToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :onboarding_completed, :boolean, default: false, null: false
      add :onboarding_step, :integer, default: 0, null: false
      add :subject, :string
      add :grade_level, :string
    end
  end
end
