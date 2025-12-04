import Config

# Configure your database
config :hellen, Hellen.Repo,
  username: "hellen",
  password: "hellen_dev",
  hostname: "localhost",
  database: "hellen_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
config :hellen, HellenWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    "dev_secret_key_base_hellen_ai_2024_change_in_production_and_make_it_very_long_indeed_to_satisfy_the_requirement",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:hellen, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:hellen, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :hellen, HellenWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/hellen_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :hellen, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true

# Configure Redis
config :hellen, :redis_url, "redis://localhost:6379"

# Configure Qdrant
config :hellen, :qdrant_url, "http://localhost:6333"

# NVIDIA NIM API (use env var in production)
config :hellen, :nvidia_api_key, System.get_env("NVIDIA_API_KEY")

# R2 Storage configuration for development
config :ex_aws,
  access_key_id: "63e9ee4705f4950ec1d7d6784c7ab66c",
  secret_access_key: "01d324e74bee9d43004f72be3c481586c880b948d4c9bb2b7f045ca0dc88a572",
  region: "auto"

config :ex_aws, :s3,
  scheme: "https://",
  host: "5e169ace5c37c07688d84589e2ee87b0.r2.cloudflarestorage.com",
  region: "auto"

config :hellen, :r2,
  bucket: "hellen-r2",
  public_url: "https://pub-0914ea82354f49a6a09816c8d7044329.r2.dev"
