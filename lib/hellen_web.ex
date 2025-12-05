defmodule HellenWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.
  """

  def static_paths,
    do: ~w(assets fonts images favicon.ico robots.txt manifest.json sw.js offline.html)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: HellenWeb.Layouts]

      import Plug.Conn
      import HellenWeb.Gettext

      unquote(verified_routes())
    end
  end

  def api_controller do
    quote do
      use Phoenix.Controller,
        formats: [:json]

      import Plug.Conn
      import HellenWeb.Gettext

      unquote(verified_routes())

      # Handle Ecto.NoResultsError gracefully
      def action(conn, _opts) do
        try do
          apply(__MODULE__, action_name(conn), [conn, conn.params])
        rescue
          Ecto.NoResultsError ->
            conn
            |> put_status(:not_found)
            |> put_view(json: HellenWeb.ErrorJSON)
            |> Phoenix.Controller.render(:"404")
            |> halt()
        end
      end
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {HellenWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import HellenWeb.CoreComponents
      import HellenWeb.UIComponents
      import HellenWeb.Gettext

      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: HellenWeb.Endpoint,
        router: HellenWeb.Router,
        statics: HellenWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
