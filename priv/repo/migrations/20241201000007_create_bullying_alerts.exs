defmodule Hellen.Repo.Migrations.CreateBullyingAlerts do
  use Ecto.Migration

  def change do
    create table(:bullying_alerts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :severity, :string, null: false
      add :alert_type, :string, null: false
      add :description, :text
      add :evidence_text, :text
      add :timestamp_start, :float
      add :timestamp_end, :float
      add :reviewed, :boolean, default: false
      add :reviewed_at, :utc_datetime
      add :analysis_id, references(:analyses, on_delete: :delete_all, type: :binary_id), null: false
      add :reviewed_by_id, references(:users, on_delete: :nilify_all, type: :binary_id)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:bullying_alerts, [:analysis_id])
    create index(:bullying_alerts, [:severity])
    create index(:bullying_alerts, [:reviewed])
  end
end
