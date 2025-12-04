defmodule Hellen.Notifications.Preference do
  @moduledoc """
  Schema for user notification preferences.
  Controls which notifications users receive via email and in-app.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notification_preferences" do
    # Email preferences
    field :email_critical_alerts, :boolean, default: true
    field :email_high_alerts, :boolean, default: true
    field :email_analysis_complete, :boolean, default: false
    field :email_daily_summary, :boolean, default: false
    field :email_weekly_summary, :boolean, default: true

    # In-app preferences
    field :inapp_all_alerts, :boolean, default: true
    field :inapp_analysis_complete, :boolean, default: true

    belongs_to :user, Hellen.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [
      :email_critical_alerts,
      :email_high_alerts,
      :email_analysis_complete,
      :email_daily_summary,
      :email_weekly_summary,
      :inapp_all_alerts,
      :inapp_analysis_complete,
      :user_id
    ])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc "Check if user should receive email for notification type"
  def should_email?(%__MODULE__{} = pref, "alert_critical"), do: pref.email_critical_alerts
  def should_email?(%__MODULE__{} = pref, "alert_high"), do: pref.email_high_alerts
  def should_email?(%__MODULE__{} = pref, "analysis_complete"), do: pref.email_analysis_complete
  def should_email?(%__MODULE__{} = pref, "daily_summary"), do: pref.email_daily_summary
  def should_email?(%__MODULE__{} = pref, "weekly_summary"), do: pref.email_weekly_summary
  def should_email?(_pref, _type), do: false

  @doc "Check if user should receive in-app notification for type"
  def should_inapp?(%__MODULE__{} = pref, type)
      when type in ~w(alert_critical alert_high alert_medium alert_low) do
    pref.inapp_all_alerts
  end

  def should_inapp?(%__MODULE__{} = pref, "analysis_complete"), do: pref.inapp_analysis_complete
  def should_inapp?(_pref, _type), do: true
end
