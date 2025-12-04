defmodule HellenWeb.Router do
  use HellenWeb, :router

  import HellenWeb.Plugs.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HellenWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug :require_auth
  end

  # Public API routes (no auth required)
  scope "/api", HellenWeb.API do
    pipe_through :api

    # Auth endpoints
    post "/auth/firebase", AuthController, :firebase
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
  end

  # Protected API routes (auth required)
  scope "/api", HellenWeb.API do
    pipe_through :api_auth

    # Current user
    get "/auth/me", AuthController, :me

    # Lessons
    resources "/lessons", LessonController, except: [:new, :edit]
    post "/lessons/:id/analyze", LessonController, :analyze

    # Analyses
    get "/lessons/:lesson_id/analyses", AnalysisController, :index
    get "/analyses/:id", AnalysisController, :show

    # Credits
    get "/credits", CreditController, :index
    get "/credits/history", CreditController, :history
  end

  # Public LiveView routes (no auth required)
  scope "/", HellenWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [{HellenWeb.LiveAuth, :none}],
      layout: {HellenWeb.Layouts, :auth} do
      live "/login", AuthLive.Login, :index
      live "/register", AuthLive.Register, :index
    end
  end

  # Authenticated LiveView routes
  scope "/", HellenWeb do
    pipe_through :browser

    live_session :authenticated, on_mount: [{HellenWeb.LiveAuth, :require_auth}] do
      live "/", DashboardLive.Index, :index
      live "/lessons/new", LessonLive.New, :new
      live "/lessons/:id", LessonLive.Show, :show
      live "/lessons/:id/analysis", LessonLive.Show, :analysis
    end
  end

  # Coordinator LiveView routes
  scope "/", HellenWeb do
    pipe_through :browser

    live_session :coordinator, on_mount: [{HellenWeb.LiveAuth, :require_coordinator}] do
      live "/institution", InstitutionLive.Index, :index
      live "/institution/teachers", InstitutionLive.Teachers, :index
    end
  end

  # Session routes (regular controller for session handling)
  scope "/", HellenWeb do
    pipe_through :browser

    post "/session/login", SessionController, :create
    post "/session/register", SessionController, :register
    get "/logout", SessionController, :logout
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:hellen, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HellenWeb.Telemetry
    end
  end
end
