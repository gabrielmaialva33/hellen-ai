defmodule HellenWeb.Router do
  use HellenWeb, :router

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

  # API routes
  scope "/api", HellenWeb.API do
    pipe_through :api

    # Lessons
    resources "/lessons", LessonController, except: [:new, :edit]
    post "/lessons/:id/analyze", LessonController, :analyze

    # Analyses
    get "/lessons/:lesson_id/analyses", AnalysisController, :index
    get "/analyses/:id", AnalysisController, :show

    # User/Auth
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    get "/auth/me", AuthController, :me

    # Credits
    get "/credits", CreditController, :index
    get "/credits/history", CreditController, :history
  end

  # Browser routes (for LiveView dashboard later)
  scope "/", HellenWeb do
    pipe_through :browser

    get "/", PageController, :home
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
