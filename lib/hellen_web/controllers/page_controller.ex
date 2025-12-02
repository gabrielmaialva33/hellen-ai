defmodule HellenWeb.PageController do
  use HellenWeb, :controller

  def home(conn, _params) do
    json(conn, %{
      name: "Hellen AI",
      version: "0.1.0",
      description: "AI-powered lesson analysis platform",
      status: "ok"
    })
  end
end
