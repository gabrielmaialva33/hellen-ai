defmodule HellenWeb.Plugs.Tenant do
  @moduledoc """
  Plug that extracts and assigns the current institution from the authenticated user.
  This enables multi-tenancy by scoping data access to the user's institution.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %{institution_id: institution_id} when not is_nil(institution_id) ->
        conn
        |> assign(:current_institution_id, institution_id)
        |> put_private(:institution_id, institution_id)

      _ ->
        conn
    end
  end
end
