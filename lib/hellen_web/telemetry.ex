defmodule HellenWeb.Telemetry do
  @moduledoc """
  Telemetry supervisor for application metrics.
  Includes Phoenix, Ecto, Oban, and custom business metrics.
  """
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("hellen.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("hellen.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("hellen.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("hellen.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("hellen.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # Oban Metrics
      counter("oban.job.start.count", tags: [:queue, :worker]),
      counter("oban.job.stop.count", tags: [:queue, :worker]),
      counter("oban.job.exception.count", tags: [:queue, :worker]),
      summary("oban.job.stop.duration", tags: [:queue, :worker], unit: {:native, :millisecond}),

      # Business Metrics - Analysis
      summary("hellen.analysis.duration.milliseconds",
        tags: [:type],
        unit: :millisecond,
        description: "Time taken to complete an analysis"
      ),
      counter("hellen.analysis.completed.total",
        tags: [:type],
        description: "Total number of completed analyses"
      ),
      counter("hellen.analysis.failed.total",
        tags: [:type, :reason],
        description: "Total number of failed analyses"
      ),

      # Business Metrics - Transcription
      summary("hellen.transcription.duration.milliseconds",
        unit: :millisecond,
        description: "Time taken to complete a transcription"
      ),
      counter("hellen.transcription.completed.total",
        description: "Total number of completed transcriptions"
      ),

      # Business Metrics - Credits
      counter("hellen.credits.consumed.total",
        tags: [:reason],
        description: "Total credits consumed by operation type"
      ),
      counter("hellen.credits.refunded.total",
        description: "Total credits refunded"
      ),

      # VM Metrics
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.memory.processes", unit: :byte),
      last_value("vm.memory.binary", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # Dispatch VM memory stats periodically
      {__MODULE__, :dispatch_vm_stats, []}
    ]
  end

  @doc """
  Dispatches VM memory statistics to telemetry.
  Called periodically by telemetry_poller.
  """
  def dispatch_vm_stats do
    memory = :erlang.memory()

    :telemetry.execute(
      [:vm, :memory],
      %{
        total: memory[:total],
        processes: memory[:processes],
        binary: memory[:binary]
      },
      %{}
    )
  end
end
