defmodule Hellen.Workers.NotificationJob do
  @moduledoc """
  Oban worker for sending notification emails.
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3

  alias Hellen.Notifications

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"type" => "send_email", "notification_id" => notification_id}}) do
    notification = Notifications.get_notification!(notification_id)
    user_id = notification.user_id

    if Notifications.should_send_email?(user_id, notification.type) do
      case Notifications.send_notification_email(notification) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :ok
    end
  end

  def perform(%Oban.Job{args: args}) do
    require Logger
    Logger.warning("Unknown notification job args: #{inspect(args)}")
    :ok
  end
end
