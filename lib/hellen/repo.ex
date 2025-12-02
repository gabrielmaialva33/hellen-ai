defmodule Hellen.Repo do
  use Ecto.Repo,
    otp_app: :hellen,
    adapter: Ecto.Adapters.Postgres
end
