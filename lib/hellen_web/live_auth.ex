defmodule HellenWeb.LiveAuth do
  @moduledoc """
  LiveView authentication hook.

  Handles user authentication for LiveView routes via on_mount callbacks.

  ## Usage

  In your router:

      live_session :public, on_mount: [{HellenWeb.LiveAuth, :none}] do
        live "/login", AuthLive.Login
      end

      live_session :authenticated, on_mount: [{HellenWeb.LiveAuth, :require_auth}] do
        live "/", DashboardLive.Index
      end

      live_session :coordinator, on_mount: [{HellenWeb.LiveAuth, :require_coordinator}] do
        live "/institution", InstitutionLive.Index
      end
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias Hellen.Accounts
  alias Hellen.Auth.Guardian

  @doc """
  Called when the LiveView is mounted.

  Supports three modes:
  - `:none` - No authentication required, but loads user if present
  - `:require_auth` - Requires authentication, redirects to login if not authenticated
  - `:require_coordinator` - Requires coordinator role
  """
  def on_mount(:none, _params, session, socket) do
    socket =
      socket
      |> assign_current_user(session)
      |> assign_current_path()

    {:cont, socket}
  end

  def on_mount(:require_auth, _params, session, socket) do
    socket =
      socket
      |> assign_current_user(session)
      |> assign_current_path()

    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/login")}
    end
  end

  def on_mount(:require_coordinator, _params, session, socket) do
    socket =
      socket
      |> assign_current_user(session)
      |> assign_current_path()

    cond do
      is_nil(socket.assigns.current_user) ->
        {:halt, redirect(socket, to: "/login")}

      not coordinator?(socket.assigns.current_user) ->
        {:halt,
         socket
         |> put_flash(:error, "Acesso restrito a coordenadores")
         |> redirect(to: "/dashboard")}

      true ->
        {:cont, socket}
    end
  end

  defp coordinator?(user) do
    user.role in ["coordinator", "admin", :coordinator, :admin]
  end

  defp assign_current_user(socket, session) do
    case session["user_token"] do
      nil ->
        assign(socket, :current_user, nil)

      token ->
        case Guardian.resource_from_token(token) do
          {:ok, user, _claims} ->
            # Reload user to get fresh data
            user = Accounts.get_user(user.id) || user
            assign(socket, :current_user, user)

          {:error, _reason} ->
            assign(socket, :current_user, nil)
        end
    end
  end

  defp assign_current_path(socket) do
    path =
      case socket.private[:live_view_module] do
        nil -> "/"
        _module -> socket.private[:connect_info][:request_path] || "/"
      end

    assign(socket, :current_path, path)
  end
end
