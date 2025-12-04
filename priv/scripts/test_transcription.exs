import Ecto.Query

# Reset the lesson to pending and enqueue new job
# Using the second lesson which has a valid audio file
lesson = Hellen.Repo.get!(Hellen.Lessons.Lesson, "4df838df-812a-4648-8f5c-51f88291eb17")
IO.puts("Found lesson: #{lesson.title}")
IO.puts("Audio URL: #{lesson.audio_url}")

# Update status to pending
{:ok, lesson} = Hellen.Lessons.update_lesson_status(lesson, "pending")
IO.puts("✅ Status reset to: #{lesson.status}")

# Cancel any existing transcription jobs for this lesson
{deleted, _} = Hellen.Repo.delete_all(
  from j in Oban.Job,
  where: j.state in ["available", "executing", "scheduled", "retryable"],
  where: j.worker == "Hellen.Workers.TranscriptionJob"
)
IO.puts("Cleaned up #{deleted} old jobs")

# Enqueue new transcription job
{:ok, job} = %{lesson_id: lesson.id}
|> Hellen.Workers.TranscriptionJob.new()
|> Oban.insert()

IO.puts("✅ Transcription job enqueued with ID: #{job.id}")
IO.puts("Check server logs for transcription progress...")
