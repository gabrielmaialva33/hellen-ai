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
    case get_token_from_header(conn) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Missing authorization header"})
        |> halt()

      token ->
        case Guardian.decode_and_verify(token) do
          {:ok, claims} ->
            case Guardian.resource_from_claims(claims) do
              {:ok, user} ->
                conn
                |> assign(:current_user, user)
                |> assign(:claims, claims)

              {:error, _reason} ->
                conn
                |> put_status(:unauthorized)
                |> json(%{error: "User not found"})
                |> halt()
            end

          {:error, reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Invalid token: #{inspect(reason)}"})
            |> halt()
        end
    end
  end

  @doc """
  Plug to optionally load user if token is present.
  Does not halt if no token is provided.
  """
  def load_user(conn, _opts) do
    case get_token_from_header(conn) do
      nil ->
        conn

      token ->
        case Guardian.decode_and_verify(token) do
          {:ok, claims} ->
            case Guardian.resource_from_claims(claims) do
              {:ok, user} ->
                conn
                |> assign(:current_user, user)
                |> assign(:claims, claims)

              {:error, _} ->
                conn
            end

          {:error, _} ->
            conn
        end
    end
  end

  defp get_token_from_header(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end
end
