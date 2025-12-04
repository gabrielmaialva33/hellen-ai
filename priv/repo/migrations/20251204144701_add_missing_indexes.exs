defmodule Hellen.Repo.Migrations.AddMissingIndexes do
  @moduledoc """
  Adds missing indexes for common query patterns.
  Improves performance for multi-tenant queries and reporting.
  """
  use Ecto.Migration

  def change do
    # Credit transactions - composite index for user history queries
    create_if_not_exists index(:credit_transactions, [:user_id, :inserted_at])

    # Note: credit_transactions doesn't have institution_id column
    # Multi-tenancy is achieved through user_id -> user.institution_id join

    # Bullying alerts - institution + reviewed for coordinator filtering
    create_if_not_exists index(:bullying_alerts, [:severity])

    # Analyses - institution + inserted_at for time-based queries
    create_if_not_exists index(:analyses, [:institution_id, :inserted_at])

    # Analyses - overall_score for performance rankings
    create_if_not_exists index(:analyses, [:overall_score])
  end
end
