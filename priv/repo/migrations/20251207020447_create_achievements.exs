defmodule Hellen.Repo.Migrations.CreateAchievements do
  use Ecto.Migration

  def change do
    # User achievements (unlocked badges)
    create table(:user_achievements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :achievement_key, :string, null: false
      add :unlocked_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_achievements, [:user_id])
    create unique_index(:user_achievements, [:user_id, :achievement_key])

    # Add level and experience points to users for gamification
    alter table(:users) do
      add :level, :integer, default: 1, null: false
      add :experience_points, :integer, default: 0, null: false
    end
  end
end
