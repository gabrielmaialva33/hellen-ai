defmodule HellenWeb.Plugs.Auth do
  @moduledoc """
  Authentication plugs for the API.

  Supports two authentication methods:
  1. Firebase ID Token - For initial login from frontend
  2. Guardian JWT - For subsequent API calls
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Hellen.Auth.Guardian

  @doc """
  Plug to require authentication via Guardian JWT.
  Expects Authorization header: "Bearer <token>"
  """
  def require_auth(conn, _opts) do
    with token when not is_nil(token) <- get_token_from_header(conn),
         {:ok, claims} <- Guardian.decode_and_verify(token),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      conn
      |> assign(:current_user, user)
      |> assign(:claims, claims)
    else
      nil ->
        unauthorized(conn, "Missing authorization header")

      {:error, :user_not_found} ->
        unauthorized(conn, "User not found")

      {:error, reason} ->
        unauthorized(conn, "Invalid token: #{inspect(reason)}")
    end
  end

  @doc """
  Plug to optionally load user if token is present.
  Does not halt if no token is provided.
  """
  def load_user(conn, _opts) do
    with token when not is_nil(token) <- get_token_from_header(conn),
         {:ok, claims} <- Guardian.decode_and_verify(token),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      conn
      |> assign(:current_user, user)
      |> assign(:claims, claims)
    else
      _ -> conn
    end
  end

  defp get_token_from_header(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end

  defp unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: message})
    |> halt()
  end

  @doc """
  Plug to fetch current user from session for browser routes.
  Uses the same session token as LiveAuth.
  """
  def fetch_current_user(conn, _opts) do
    token = get_session(conn, "user_token")

    case token do
      nil ->
        assign(conn, :current_user, nil)

      token ->
        case Guardian.resource_from_token(token) do
          {:ok, user, _claims} ->
            user = Hellen.Accounts.get_user(user.id) || user
            assign(conn, :current_user, user)

          {:error, _reason} ->
            assign(conn, :current_user, nil)
        end
    end
  end
end
