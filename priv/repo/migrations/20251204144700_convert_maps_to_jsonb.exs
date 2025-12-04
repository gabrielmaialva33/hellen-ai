defmodule Hellen.Repo.Migrations.ConvertMapsToJsonb do
  @moduledoc """
  Converts :map columns to :jsonb for better performance and querying.
  Adds GIN indexes for efficient JSON path queries.

  Note: segments column is {:array, :map} which is already jsonb[] and doesn't need conversion.
  """
  use Ecto.Migration

  def up do
    # Analysis - raw_response and result (large JSON objects)
    execute "ALTER TABLE analyses ALTER COLUMN raw_response TYPE jsonb USING raw_response::jsonb"
    execute "ALTER TABLE analyses ALTER COLUMN result TYPE jsonb USING result::jsonb"
    execute "CREATE INDEX IF NOT EXISTS analyses_result_gin ON analyses USING GIN (result)"

    # Transcription - segments is already jsonb[] (array), add GIN index for array containment
    execute "CREATE INDEX IF NOT EXISTS transcriptions_segments_gin ON transcriptions USING GIN (segments)"

    # Lesson - metadata
    execute "ALTER TABLE lessons ALTER COLUMN metadata TYPE jsonb USING metadata::jsonb"

    # Institution - settings
    execute "ALTER TABLE institutions ALTER COLUMN settings TYPE jsonb USING settings::jsonb"

    # Credit transaction - metadata
    execute "ALTER TABLE credit_transactions ALTER COLUMN metadata TYPE jsonb USING metadata::jsonb"
  end

  def down do
    # Revert to json type (not :map, as PostgreSQL doesn't have a map type)
    execute "DROP INDEX IF EXISTS analyses_result_gin"
    execute "ALTER TABLE analyses ALTER COLUMN raw_response TYPE json USING raw_response::json"
    execute "ALTER TABLE analyses ALTER COLUMN result TYPE json USING result::json"

    execute "DROP INDEX IF EXISTS transcriptions_segments_gin"

    execute "ALTER TABLE lessons ALTER COLUMN metadata TYPE json USING metadata::json"
    execute "ALTER TABLE institutions ALTER COLUMN settings TYPE json USING settings::json"
    execute "ALTER TABLE credit_transactions ALTER COLUMN metadata TYPE json USING metadata::json"
  end
end
