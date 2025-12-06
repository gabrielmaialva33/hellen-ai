defmodule HellenWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.
  """
  use HellenWeb, :controller

  # Handle Ecto.NoResultsError (raised by get! functions)
  def call(conn, {:error, :user_not_found}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: HellenWeb.ErrorJSON)
    |> render(:"401")
  end

  def call(conn, {:error, :invalid_password}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: HellenWeb.ErrorJSON)
    |> render(:"401")
  end

  def call(conn, {:error, status, message}) when is_atom(status) and is_binary(message) do
    conn
    |> put_status(status)
    |> json(%{error: message})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: HellenWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: HellenWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: HellenWeb.ErrorJSON)
    |> render(:"401")
  end

  def call(conn, {:error, :insufficient_credits}) do
    conn
    |> put_status(:payment_required)
    |> put_view(json: HellenWeb.ErrorJSON)
    |> render(:insufficient_credits)
  end
end
