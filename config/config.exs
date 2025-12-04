# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :hellen,
  ecto_repos: [Hellen.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :hellen, HellenWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HellenWeb.ErrorHTML, json: HellenWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Hellen.PubSub,
  live_view: [signing_salt: "hellen_salt"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  hellen: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  hellen: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Oban with optimized queue sizes
config :hellen, Oban,
  repo: Hellen.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       # Cleanup old job records daily at 2 AM
       {"0 2 * * *", Hellen.Workers.CleanupJob}
     ]}
  ],
  queues: [
    # Increased for better throughput
    transcription: 3,
    # Increased for parallel analysis
    analysis: 5,
    reports: 2,
    notifications: 5,
    default: 10
  ]

# Configure Guardian for JWT
config :hellen, Hellen.Auth.Guardian,
  issuer: "hellen",
  secret_key: System.get_env("GUARDIAN_SECRET_KEY") || "dev_secret_key_change_in_production"

# Configure Firebase
config :hellen, :firebase, project_id: "hellen-ai"

# Configure ChromicPDF for PDF generation
config :hellen, :chromic_pdf,
  session_pool: [size: 2],
  no_sandbox: true,
  offline: true

# Configure Swoosh for email
config :hellen, Hellen.Notifications.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client (uses Finch)
config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

config :mime, :types, %{
  "audio/mp4" => ["m4a"],
  "audio/ogg" => ["ogg"],
  "audio/flac" => ["flac"],
  "video/x-matroska" => ["mkv"],
  "video/x-msvideo" => ["avi"],
  "video/quicktime" => ["mov"]
}
