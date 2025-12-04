defmodule Hellen.Workers.CleanupJob do
  @moduledoc """
  Periodic cleanup job that runs daily to maintain database health.
  Handles cleanup of old Oban job records and temporary data.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("[CleanupJob] Starting daily cleanup")

    # Oban.Plugins.Pruner already handles job cleanup
    # Add any additional cleanup tasks here

    # Example: Clean up stale upload records older than 30 days
    cleanup_stale_uploads()

    Logger.info("[CleanupJob] Daily cleanup completed")
    :ok
  end

  defp cleanup_stale_uploads do
    # Placeholder for future cleanup logic
    # Could clean up orphaned files, expired sessions, etc.
    :ok
  end
end
