defmodule Hellen.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HellenWeb.Telemetry,
      Hellen.Repo,
      {DNSCluster, query: Application.get_env(:hellen, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Hellen.PubSub},
      # Start NVIDIA API key pool (before Oban workers)
      Hellen.AI.NvidiaKeyPool,
      # Start Oban
      {Oban, Application.fetch_env!(:hellen, Oban)},
      # Start Redis connection
      {Redix,
       {Application.get_env(:hellen, :redis_url, "redis://localhost:6379"), [name: :redix]}},
      # Start ChromicPDF for PDF generation
      {ChromicPDF, Application.get_env(:hellen, :chromic_pdf, [])},
      # Start Finch for HTTP client (Swoosh API)
      {Finch, name: Hellen.Finch},
      # Start the Endpoint (http/https)
      HellenWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Hellen.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    HellenWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
