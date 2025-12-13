import Config

# Configure your database
config :hellen, Hellen.Repo,
  username: "hellen",
  password: "hellen_dev",
  hostname: "localhost",
  database: "hellen_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test.
config :hellen, HellenWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_hellen_ai_2024",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Disable Oban in tests
config :hellen, Oban, testing: :inline

# Configure mock modules for external services
config :hellen, :ai_client, Hellen.AI.ClientMock
config :hellen, :storage, Hellen.Storage.Mock
