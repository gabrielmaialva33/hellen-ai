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

  pipeline :stripe_webhook do
    plug :accepts, ["json"]
  end

  # Stripe webhook (needs raw body for signature verification)
  scope "/webhooks", HellenWeb do
    pipe_through :stripe_webhook

    post "/stripe", StripeWebhookController, :webhook
  end

  # Health check endpoint (no auth)
  scope "/health", HellenWeb do
    pipe_through :api
    get "/", HealthController, :index
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

  # Public landing page (no auth required)
  scope "/", HellenWeb do
    pipe_through :browser

    live_session :landing,
      on_mount: [{HellenWeb.LiveAuth, :none}] do
      live "/", LandingLive, :index
      live "/terms", LegalLive.TermsLive, :index
      live "/privacy", LegalLive.PrivacyLive, :index
      live "/support", LegalLive.SupportLive, :index
    end
  end

  # Public auth routes (no auth required)
  scope "/", HellenWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [{HellenWeb.LiveAuth, :none}],
      layout: {HellenWeb.Layouts, :auth} do
      live "/login", AuthLive.Login, :index
      live "/register", AuthLive.Register, :index
      live "/invite/:token", AuthLive.Invite, :index
    end
  end

  # Onboarding (separate session to avoid redirect loop)
  scope "/", HellenWeb do
    pipe_through :browser

    live_session :onboarding, on_mount: [{HellenWeb.LiveAuth, :require_auth_no_onboarding}] do
      live "/onboarding", OnboardingLive, :index
    end
  end

  # Authenticated LiveView routes
  scope "/", HellenWeb do
    pipe_through :browser

    live_session :authenticated, on_mount: [{HellenWeb.LiveAuth, :require_auth}] do
      live "/dashboard", DashboardLive.Index, :index
      live "/aulas", LessonsLive.Index, :index
      live "/lessons/new", LessonLive.New, :new
      live "/lessons/:id", LessonLive.Show, :show
      live "/lessons/:id/analysis", LessonLive.Show, :analysis

      # Plannings
      live "/plannings", PlanningsLive.Index, :index
      live "/plannings/new", PlanningsLive.New, :new
      live "/plannings/:id", PlanningsLive.Show, :show
      live "/plannings/:id/edit", PlanningsLive.Edit, :edit

      # Assessments
      live "/assessments", AssessmentsLive.Index, :index
      live "/assessments/new", AssessmentsLive.New, :new
      live "/assessments/:id", AssessmentsLive.Show, :show
      live "/assessments/:id/edit", AssessmentsLive.Edit, :edit

      live "/analytics", AnalyticsLive.Index, :index
      live "/reports", ReportsLive.Index, :index
      live "/settings", SettingsLive.Index, :index
      live "/billing", BillingLive.Index, :index
      live "/achievements", AchievementsLive, :index
    end
  end

  # Coordinator LiveView routes
  scope "/", HellenWeb do
    pipe_through :browser

    live_session :coordinator, on_mount: [{HellenWeb.LiveAuth, :require_coordinator}] do
      live "/institution", InstitutionLive.Index, :index
      live "/institution/teachers", InstitutionLive.Teachers, :index
      live "/institution/reports", InstitutionLive.Reports, :index
      live "/alerts", AlertsLive.Index, :index
    end
  end

  # Admin LiveView routes
  scope "/", HellenWeb do
    pipe_through :browser

    live_session :admin, on_mount: [{HellenWeb.LiveAuth, :require_admin}] do
      live "/admin", AdminLive.Index, :index
      live "/admin/institutions", AdminLive.Institutions, :index
      live "/admin/users", AdminLive.Users, :index
      live "/admin/health", AdminLive.Health, :index
    end
  end

  # Session routes (regular controller for session handling)
  scope "/", HellenWeb do
    pipe_through :browser

    post "/session/login", SessionController, :create
    post "/session/register", SessionController, :register
    post "/session/firebase", SessionController, :firebase_login
    get "/logout", SessionController, :logout
  end

  # Report download routes (coordinator only, requires session)
  scope "/reports", HellenWeb do
    pipe_through [:browser, :fetch_current_user]

    get "/download/monthly", ReportController, :monthly
    get "/download/teacher/:id", ReportController, :teacher
    get "/download/analysis/:id", ReportController, :analysis
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
