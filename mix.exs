defmodule Hellen.MixProject do
  use Mix.Project

  def project do
    [
      app: :hellen,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Hellen.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.14"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.17"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},

      # Jobs
      {:oban, "~> 2.17"},

      # HTTP Client
      {:req, "~> 0.5"},

      # Redis
      {:redix, "~> 1.3"},

      # Storage (R2/S3)
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:sweet_xml, "~> 0.7"},
      {:hackney, "~> 1.20"},

      # PDF
      {:chromic_pdf, "~> 1.15"},

      # Auth
      {:guardian, "~> 2.3"},
      {:bcrypt_elixir, "~> 3.0"},

      # Email
      {:swoosh, "~> 1.14"},
      {:finch, "~> 0.16"},
      {:gen_smtp, "~> 1.0"},

      # Payments
      {:stripity_stripe, "~> 3.2"},

      # Environment
      {:dotenvy, "~> 0.8"},

      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},

      # Testing
      {:mox, "~> 1.1", only: :test},
      {:ex_machina, "~> 2.8", only: :test},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind hellen", "esbuild hellen"],
      "assets.deploy": [
        "tailwind hellen --minify",
        "esbuild hellen --minify",
        "phx.digest"
      ]
    ]
  end
end
