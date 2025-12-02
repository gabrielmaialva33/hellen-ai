# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Hellen.Repo.insert!(%Hellen.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Hellen.Accounts

# Create a demo institution
{:ok, institution} =
  Accounts.create_institution(%{
    name: "Escola Demo",
    plan: "pro"
  })

# Create a demo user
{:ok, _user} =
  Accounts.register_user(%{
    email: "demo@hellen.ai",
    name: "Professor Demo",
    password: "demo123456",
    role: "teacher",
    institution_id: institution.id
  })

IO.puts("Seeds completed!")
IO.puts("Demo user: demo@hellen.ai / demo123456")
