ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Hellen.Repo, :manual)

# Define mocks for behaviours
Mox.defmock(Hellen.AI.ClientMock, for: Hellen.AI.ClientBehaviour)
Mox.defmock(Hellen.Storage.Mock, for: Hellen.Storage.Behaviour)
