defmodule Hellen.Repo.Migrations.SetExistingUsersOnboardingCompleted do
  use Ecto.Migration

  def up do
    # Mark all existing users as having completed onboarding
    # This prevents them from being forced through the wizard
    execute "UPDATE users SET onboarding_completed = true WHERE onboarding_completed = false"
  end

  def down do
    # No-op: we don't want to reset onboarding status
    :ok
  end
end
