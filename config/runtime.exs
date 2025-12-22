import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# temporary config.exs is removed.

# Load .env files in dev/test using dotenvy 0.6.0+ best practices
# Order: .env files first, then System.get_env() so system vars take precedence
if config_env() in [:dev, :test] do
  {:ok, env_vars} =
    Dotenvy.source([
      # Base config
      ".env",
      # Environment-specific (dev/test)
      ".env.#{config_env()}",
      # Local overrides (gitignored)
      ".env.#{config_env()}.local",
      # System env vars take precedence
      System.get_env()
    ])

  # Actually set the variables in System for runtime access
  System.put_env(env_vars)
end

if System.get_env("PHX_SERVER") do
  config :hellen, HellenWeb.Endpoint, server: true
end

# Database URL override for dev/test (allows .env to override dev.exs defaults)
if config_env() in [:dev, :test] do
  if database_url = System.get_env("DATABASE_URL") do
    config :hellen, Hellen.Repo, url: database_url
  end

  # Redis/Qdrant from .env override dev.exs fallbacks
  if redis_url = System.get_env("REDIS_URL") do
    config :hellen, :redis_url, redis_url
  end

  if qdrant_url = System.get_env("QDRANT_URL") do
    config :hellen, :qdrant_url, qdrant_url
  end
end

# Cloudflare R2 - configured for all environments
# R2 requires specific ex_aws configuration for proper signature
if r2_access_key = System.get_env("R2_ACCESS_KEY_ID") do
  config :ex_aws,
    access_key_id: r2_access_key,
    secret_access_key: System.get_env("R2_SECRET_ACCESS_KEY"),
    region: "auto"

  r2_endpoint = System.get_env("R2_ENDPOINT")

  config :ex_aws, :s3,
    scheme: "https://",
    host: r2_endpoint,
    port: 443,
    region: "auto"

  config :hellen, :r2,
    bucket: System.get_env("R2_BUCKET") || "hellen-r2",
    public_url: System.get_env("R2_PUBLIC_URL"),
    endpoint: r2_endpoint
end

# Guardian secret - can be set in dev via .env
if guardian_secret = System.get_env("GUARDIAN_SECRET_KEY") do
  config :hellen, Hellen.Auth.Guardian, secret_key: guardian_secret
end

# NVIDIA API - for dev/test with .env (used for LLM analysis)
# Support multiple keys (comma-separated) for load distribution
if nvidia_keys = System.get_env("NVIDIA_API_KEYS") do
  keys = String.split(nvidia_keys, ",") |> Enum.map(&String.trim/1) |> Enum.filter(&(&1 != ""))
  config :hellen, :nvidia_api_keys, keys
end

# Fallback to single key (backward compatible)
if nvidia_key = System.get_env("NVIDIA_API_KEY") do
  config :hellen, :nvidia_api_key, nvidia_key
end

# Groq API - for dev/test with .env (used for transcription)
if groq_key = System.get_env("GROQ_API_KEY") do
  config :hellen, :groq_api_key, groq_key
end

# Stripe - configured for all environments
if stripe_key = System.get_env("STRIPE_SECRET_KEY") do
  config :stripity_stripe,
    api_key: stripe_key,
    webhook_secret: System.get_env("STRIPE_WEBHOOK_SECRET")

  config :hellen, :stripe, publishable_key: System.get_env("STRIPE_PUBLISHABLE_KEY")
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :hellen, Hellen.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :hellen, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :hellen, HellenWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # Redis
  config :hellen, :redis_url, System.get_env("REDIS_URL") || "redis://localhost:6379"

  # Qdrant
  config :hellen, :qdrant_url, System.get_env("QDRANT_URL") || "http://localhost:6333"

  # NVIDIA NIM API (required in prod)
  unless System.get_env("NVIDIA_API_KEY") do
    raise "environment variable NVIDIA_API_KEY is missing."
  end

  # R2 is configured at the top for all environments

  # Email configuration (Mailgun in production)
  if mailgun_api_key = System.get_env("MAILGUN_API_KEY") do
    config :hellen, Hellen.Notifications.Mailer,
      adapter: Swoosh.Adapters.Mailgun,
      api_key: mailgun_api_key,
      domain: System.get_env("MAILGUN_DOMAIN") || "hellen.ai"
  end
end
