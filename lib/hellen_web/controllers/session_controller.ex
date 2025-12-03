defmodule HellenWeb.SessionController do
  use HellenWeb, :controller

  alias Hellen.Accounts
  alias Hellen.Auth.Guardian

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
            |> redirect(to: ~p"/")

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
            |> redirect(to: ~p"/")

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
