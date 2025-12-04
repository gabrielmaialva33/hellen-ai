defmodule Hellen.Notifications.Notification do
  @moduledoc """
  Schema for notifications sent to users.

  Types:
  - alert_critical: Critical bullying alert
  - alert_high: High severity alert
  - alert_medium: Medium severity alert
  - alert_low: Low severity alert
  - analysis_complete: Analysis finished
  - daily_summary: Daily summary (coordinators)
  - weekly_summary: Weekly summary
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @notification_types ~w(
    alert_critical
    alert_high
    alert_medium
    alert_low
    analysis_complete
    daily_summary
    weekly_summary
  )

  schema "notifications" do
    field :type, :string
    field :title, :string
    field :message, :string
    field :data, :map, default: %{}
    field :read_at, :utc_datetime
    field :email_sent_at, :utc_datetime

    belongs_to :user, Hellen.Accounts.User
    belongs_to :institution, Hellen.Accounts.Institution

    timestamps()
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :type,
      :title,
      :message,
      :data,
      :read_at,
      :email_sent_at,
      :user_id,
      :institution_id
    ])
    |> validate_required([:type, :title, :message, :user_id])
    |> validate_inclusion(:type, @notification_types)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:institution_id)
  end

  @doc "Mark notification as read"
  def mark_read_changeset(notification) do
    notification
    |> change(read_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc "Mark email as sent"
  def mark_email_sent_changeset(notification) do
    notification
    |> change(email_sent_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def notification_types, do: @notification_types
end
