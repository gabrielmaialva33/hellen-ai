defmodule HellenWeb.API.AuthController do
  @moduledoc """
  Authentication controller for Firebase and local auth.

  ## Endpoints

  * `POST /api/auth/firebase` - Login with Firebase ID token
  * `POST /api/auth/login` - Login with email/password
  * `POST /api/auth/register` - Register new user
  * `POST /api/auth/refresh` - Refresh access token
  * `GET /api/auth/me` - Get current user info
  """

  use HellenWeb, :api_controller

  alias Hellen.Accounts
  alias Hellen.Auth.Firebase
  alias Hellen.Auth.Guardian

  action_fallback HellenWeb.FallbackController

  @doc """
  Authenticate with Firebase ID token.

  ## Request body
  ```json
  {
    "id_token": "firebase_id_token_from_frontend"
  }
  ```

  ## Response
  ```json
  {
    "data": {
      "user": { ... },
      "access_token": "jwt_token",
      "refresh_token": "jwt_refresh_token"
    }
  }
  ```
  """
  def firebase(conn, %{"id_token" => id_token}) do
    with {:ok, claims} <- Firebase.verify_id_token(id_token),
         user_info <- Firebase.extract_user_info(claims),
         {:ok, user} <- Accounts.find_or_create_from_firebase(user_info),
         {:ok, tokens} <- Guardian.generate_tokens(user) do
      conn
      |> put_status(:ok)
      |> json(%{
        data: %{
          user: user_json(user),
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token
        }
      })
    else
      {:error, :invalid_token_format} ->
        {:error, :bad_request, "Invalid token format"}

      {:error, :certs_fetch_failed} ->
        {:error, :service_unavailable, "Failed to verify token"}

      {:error, :unknown_key_id} ->
        {:error, :unauthorized, "Unknown signing key"}

      {:error, :invalid_signature} ->
        {:error, :unauthorized, "Invalid token signature"}

      {:error, :token_expired} ->
        {:error, :unauthorized, "Token expired"}

      {:error, :invalid_issuer} ->
        {:error, :unauthorized, "Invalid token issuer"}

      {:error, :invalid_audience} ->
        {:error, :unauthorized, "Invalid token audience"}

      {:error, reason} ->
        {:error, :unauthorized, "Authentication failed: #{inspect(reason)}"}
    end
  end

  def firebase(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing id_token parameter"})
  end

  @doc """
  Traditional login with email and password.
  """
  def login(conn, %{"email" => email, "password" => password}) do
    with {:ok, user} <- Accounts.authenticate_user(email, password),
         {:ok, tokens} <- Guardian.generate_tokens(user) do
      conn
      |> put_status(:ok)
      |> json(%{
        data: %{
          user: user_json(user),
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token
        }
      })
    else
      {:error, :user_not_found} ->
        {:error, :unauthorized, "Invalid email or password"}

      {:error, :invalid_password} ->
        {:error, :unauthorized, "Invalid email or password"}

      {:error, reason} ->
        {:error, :unauthorized, "Authentication failed: #{inspect(reason)}"}
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing email or password"})
  end

  @doc """
  Register a new user with email and password.
  """
  def register(conn, %{"email" => email, "password" => password, "name" => name} = params) do
    attrs = %{
      email: email,
      password: password,
      name: name,
      role: "teacher",
      plan: "free",
      institution_id: params["institution_id"]
    }

    with {:ok, user} <- Accounts.register_user(attrs),
         {:ok, tokens} <- Guardian.generate_tokens(user) do
      conn
      |> put_status(:created)
      |> json(%{
        data: %{
          user: user_json(user),
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token
        }
      })
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, reason} ->
        {:error, :unprocessable_entity, "Registration failed: #{inspect(reason)}"}
    end
  end

  def register(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required fields: email, password, name"})
  end

  @doc """
  Refresh access token using refresh token.
  """
  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Guardian.refresh_access_token(refresh_token) do
      {:ok, new_access_token, _claims} ->
        conn
        |> put_status(:ok)
        |> json(%{data: %{access_token: new_access_token}})

      {:error, reason} ->
        {:error, :unauthorized, "Failed to refresh token: #{inspect(reason)}"}
    end
  end

  def refresh(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing refresh_token parameter"})
  end

  @doc """
  Get current authenticated user info.
  Requires Authorization header with Bearer token.
  """
  def me(conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})

      user ->
        conn
        |> put_status(:ok)
        |> json(%{data: %{user: user_json(user)}})
    end
  end

  # Private helpers

  defp user_json(user) do
    %{
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      credits: user.credits,
      plan: user.plan,
      email_verified: user.email_verified,
      institution_id: user.institution_id,
      inserted_at: user.inserted_at
    }
  end
end
