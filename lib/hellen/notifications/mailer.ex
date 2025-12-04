defmodule Hellen.Notifications.Mailer do
  @moduledoc """
  Mailer for sending notification emails using Swoosh.
  """
  use Swoosh.Mailer, otp_app: :hellen
end
