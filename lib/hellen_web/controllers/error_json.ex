defmodule HellenWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.
  """

  def render("404.json", _assigns) do
    %{errors: %{detail: "Not Found"}}
  end

  def render("401.json", _assigns) do
    %{errors: %{detail: "Unauthorized"}}
  end

  def render("403.json", _assigns) do
    %{errors: %{detail: "Forbidden"}}
  end

  def render("500.json", _assigns) do
    %{errors: %{detail: "Internal Server Error"}}
  end

  def render("insufficient_credits.json", _assigns) do
    %{
      errors: %{
        detail: "Insufficient credits",
        code: "INSUFFICIENT_CREDITS",
        message:
          "You don't have enough credits to perform this action. Please purchase more credits."
      }
    }
  end

  # By default, Phoenix returns the status message from
  # the template name.
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
