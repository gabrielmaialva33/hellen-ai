defmodule HellenWeb.Plugs.Authorize do
  @moduledoc """
  Authorization plugs for role-based access control.
  """
  import Plug.Conn
  import Phoenix.Controller

  @doc """
  Requires the current user to have coordinator or admin role.
  Returns 403 Forbidden if not authorized.
  """
  def require_coordinator(conn, _opts) do
    case conn.assigns[:current_user] do
      %{role: role} when role in ["coordinator", "admin"] ->
        conn

      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Forbidden", message: "Coordinator access required"})
        |> halt()
    end
  end

  @doc """
  Requires the current user to have admin role.
  Returns 403 Forbidden if not authorized.
  """
  def require_admin(conn, _opts) do
    case conn.assigns[:current_user] do
      %{role: "admin"} ->
        conn

      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Forbidden", message: "Admin access required"})
        |> halt()
    end
  end

  @doc """
  Verifies that the current user belongs to the specified institution.
  Expects :institution_id to be in conn.params or conn.path_params.
  """
  def verify_institution(conn, _opts) do
    user = conn.assigns[:current_user]
    institution_id = conn.params["institution_id"] || conn.path_params["institution_id"]

    cond do
      is_nil(user) ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
        |> halt()

      is_nil(institution_id) ->
        conn

      user.institution_id == institution_id ->
        conn

      user.role == "admin" ->
        # Admins can access any institution
        conn

      true ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Forbidden", message: "Access denied to this institution"})
        |> halt()
    end
  end
end
