defmodule HellenWeb.HealthController do
  use HellenWeb, :controller

  alias Ecto.Adapters.SQL

  def index(conn, _params) do
    # Check database connection
    db_status =
      try do
        SQL.query!(Hellen.Repo, "SELECT 1")
        :ok
      rescue
        _ -> :error
      end

    status = if db_status == :ok, do: :ok, else: :service_unavailable
    http_status = if db_status == :ok, do: 200, else: 503

    conn
    |> put_status(http_status)
    |> json(%{
      status: status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      services: %{
        database: db_status,
        application: :ok
      }
    })
  end
end
