defmodule Hellen.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Hellen.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox
  alias Hellen.Repo

  using do
    quote do
      alias Hellen.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Hellen.DataCase
      import Hellen.Factory
      import Hellen.MoxHelpers
      import Mox

      setup :verify_on_exit!
    end
  end

  setup tags do
    setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  Creates a full test context with institution, user, and lesson.

  Returns `%{institution: institution, user: user, lesson: lesson}`

  ## Examples

      test "example" do
        %{institution: institution, user: user, lesson: lesson} = create_test_context()
        # ... test code
      end
  """
  def create_test_context do
    institution = Hellen.Factory.insert(:institution)
    user = Hellen.Factory.insert(:user, institution: institution)
    lesson = Hellen.Factory.insert(:lesson, user: user, institution: institution)
    %{institution: institution, user: user, lesson: lesson}
  end

  @doc """
  Creates a test context with completed analysis.

  Returns `%{institution: institution, user: user, lesson: lesson, analysis: analysis}`
  """
  def create_test_context_with_analysis do
    context = create_test_context()

    analysis =
      Hellen.Factory.insert(:analysis, lesson: context.lesson, institution: context.institution)

    Map.put(context, :analysis, analysis)
  end

  @doc """
  Creates timestamps with guaranteed ordering for testing.

  Avoids need for `:timer.sleep` in tests by creating timestamps
  with explicit second offsets.

  ## Examples

      test "orders by timestamp" do
        [ts1, ts2, ts3] = sequential_timestamps(3)
        insert(:analysis, inserted_at: ts1)
        insert(:analysis, inserted_at: ts2)
        insert(:analysis, inserted_at: ts3)
        # ts3 > ts2 > ts1
      end
  """
  def sequential_timestamps(count) do
    now = DateTime.utc_now()

    for i <- 0..(count - 1) do
      DateTime.add(now, i, :second)
    end
  end

  @doc """
  Creates timestamps in reverse order (most recent first).

  Useful for testing DESC ordering.

  ## Examples

      [recent, older, oldest] = sequential_timestamps_desc(3)
  """
  def sequential_timestamps_desc(count) do
    now = DateTime.utc_now()

    for i <- (count - 1)..0 do
      DateTime.add(now, -i, :second)
    end
  end
end
