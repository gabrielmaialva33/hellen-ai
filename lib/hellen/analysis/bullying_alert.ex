defmodule Hellen.Analysis.BullyingAlert do
  @moduledoc """
  Schema for bullying alerts detected during lesson analysis (Lei 13.185/2015).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "bullying_alerts" do
    field :severity, :string
    field :alert_type, :string
    field :description, :string
    field :evidence_text, :string
    field :timestamp_start, :float
    field :timestamp_end, :float
    field :reviewed, :boolean, default: false
    field :reviewed_at, :utc_datetime

    belongs_to :analysis, Hellen.Analysis.Analysis
    belongs_to :reviewed_by, Hellen.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @severities ["low", "medium", "high", "critical"]
  @alert_types [
    "verbal_aggression",
    "exclusion",
    "intimidation",
    "mockery",
    "discrimination",
    "threat",
    "inappropriate_language",
    "other"
  ]

  @doc false
  def changeset(bullying_alert, attrs) do
    bullying_alert
    |> cast(attrs, [
      :severity,
      :alert_type,
      :description,
      :evidence_text,
      :timestamp_start,
      :timestamp_end,
      :reviewed,
      :reviewed_at,
      :analysis_id,
      :reviewed_by_id
    ])
    |> validate_required([:severity, :alert_type, :analysis_id])
    |> validate_inclusion(:severity, @severities)
    |> validate_inclusion(:alert_type, @alert_types)
    |> foreign_key_constraint(:analysis_id)
  end

  def review_changeset(alert, reviewer_id) do
    alert
    |> change(reviewed: true, reviewed_at: DateTime.utc_now(), reviewed_by_id: reviewer_id)
  end
end
