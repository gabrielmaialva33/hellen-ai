defmodule Hellen.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :title, :string, null: false
      add :message, :text, null: false
      add :data, :map, default: %{}
      add :read_at, :utc_datetime
      add :email_sent_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :institution_id,
          references(:institutions, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id, :read_at])
    create index(:notifications, [:institution_id])
    create index(:notifications, [:type])
    create index(:notifications, [:inserted_at])

    create table(:notification_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email_critical_alerts, :boolean, default: true
      add :email_high_alerts, :boolean, default: true
      add :email_analysis_complete, :boolean, default: false
      add :email_daily_summary, :boolean, default: false
      add :email_weekly_summary, :boolean, default: true
      add :inapp_all_alerts, :boolean, default: true
      add :inapp_analysis_complete, :boolean, default: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:notification_preferences, [:user_id])
  end
end
