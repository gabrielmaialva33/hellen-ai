defmodule HellenWeb.SessionController do
  use HellenWeb, :controller

  alias Hellen.Accounts
  alias Hellen.Auth.Firebase
  alias Hellen.Auth.Guardian

  require Logger

  @doc """
  Handles login form submission.
  Sets the session token and redirects to dashboard.
  """
  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        case Guardian.generate_tokens(user) do
          {:ok, %{access_token: token}} ->
            conn
            |> put_session(:user_token, token)
            |> put_flash(:info, "Bem-vindo de volta, #{user.name || user.email}!")
            |> redirect(to: ~p"/dashboard")

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Erro ao criar sessão. Tente novamente.")
            |> redirect(to: ~p"/login")
        end

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Email ou senha inválidos")
        |> redirect(to: ~p"/login")
    end
  end

  @doc """
  Handles registration form submission.
  Creates a new user, sets the session token and redirects to dashboard.
  """
  def register(conn, %{"name" => name, "email" => email, "password" => password}) do
    case Accounts.register_user(%{name: name, email: email, password: password}) do
      {:ok, user} ->
        case Guardian.generate_tokens(user) do
          {:ok, %{access_token: token}} ->
            conn
            |> put_session(:user_token, token)
            |> put_flash(
              :info,
              "Conta criada com sucesso! Bem-vindo, #{user.name || user.email}!"
            )
            |> redirect(to: ~p"/dashboard")

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Conta criada, mas houve erro ao iniciar sessão. Faça login.")
            |> redirect(to: ~p"/login")
        end

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_flash(:error, "Erro ao criar conta: #{errors}")
        |> redirect(to: ~p"/register")
    end
  end

  @doc """
  Handles Firebase login (Google Sign-In).
  Receives Firebase ID token, verifies it, and creates session.
  """
  def firebase_login(conn, %{"id_token" => id_token}) do
    with {:ok, claims} <- Firebase.verify_id_token(id_token),
         user_info <- Firebase.extract_user_info(claims),
         {:ok, user} <- Accounts.find_or_create_from_firebase(user_info),
         {:ok, %{access_token: token}} <- Guardian.generate_tokens(user) do
      Logger.info("Firebase login successful for user: #{user.email}")

      conn
      |> put_session(:user_token, token)
      |> put_status(:ok)
      |> json(%{redirect: ~p"/dashboard"})
    else
      {:error, :invalid_token_format} ->
        json_error(conn, "Token invalido")

      {:error, :token_expired} ->
        json_error(conn, "Token expirado. Tente novamente.")

      {:error, :invalid_signature} ->
        json_error(conn, "Assinatura do token invalida")

      {:error, reason} ->
        Logger.warning("Firebase login failed: #{inspect(reason)}")
        json_error(conn, "Erro ao autenticar com Google")
    end
  end

  def firebase_login(conn, _params) do
    json_error(conn, "Token nao fornecido")
  end

  defp json_error(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: message})
  end

  @doc """
  Logs the user out by clearing the session.
  """
  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Logout realizado com sucesso")
    |> redirect(to: ~p"/login")
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end
end
