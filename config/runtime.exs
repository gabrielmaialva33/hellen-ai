import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# temporary config.exs is removed.

if System.get_env("PHX_SERVER") do
  config :hellen, HellenWeb.Endpoint, server: true
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

  # NVIDIA NIM API
  config :hellen,
         :nvidia_api_key,
         System.get_env("NVIDIA_API_KEY") ||
           raise("environment variable NVIDIA_API_KEY is missing.")

  # Cloudflare R2
  config :ex_aws,
    access_key_id: System.get_env("R2_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("R2_SECRET_ACCESS_KEY"),
    region: "auto"

  config :ex_aws, :s3,
    scheme: "https://",
    host: System.get_env("R2_ENDPOINT"),
    region: "auto"
end
