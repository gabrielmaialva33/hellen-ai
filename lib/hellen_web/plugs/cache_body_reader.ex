defmodule HellenWeb.Plugs.CacheBodyReader do
  @moduledoc """
  Reads the body and stores it in the connection helper for later access.
  Useful for webhook signature verification.
  """

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = Plug.Conn.assign(conn, :raw_body, body)
    {:ok, body, conn}
  end
end
