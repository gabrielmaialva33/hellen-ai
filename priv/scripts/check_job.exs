import Ecto.Query

# Check Oban jobs
jobs = Hellen.Repo.all(
  from j in Oban.Job,
  where: j.worker == "Hellen.Workers.TranscriptionJob",
  order_by: [desc: j.id],
  limit: 5
)

for job <- jobs do
  IO.puts("Job #{job.id}: state=#{job.state}, attempt=#{job.attempt}/#{job.max_attempts}")
  if job.errors && length(job.errors) > 0 do
    IO.puts("  Errors:")
    for error <- job.errors do
      IO.puts("    #{inspect(error)}")
    end
  end
end
