# Test reprocessing a lesson with existing transcription
lesson = Hellen.Repo.get(Hellen.Lessons.Lesson, "4df838df-812a-4648-8f5c-51f88291eb17")

if lesson do
  IO.puts("Lesson found: #{lesson.id}")
  IO.puts("Current status: #{lesson.status}")

  # Check if transcription exists
  transcription = Hellen.Lessons.get_transcription_by_lesson(lesson.id)
  has_transcription = transcription != nil
  IO.puts("Has transcription: #{has_transcription}")

  if transcription do
    IO.puts("Transcription text: #{String.slice(transcription.full_text || "", 0..100)}...")
  end

  # Reset to pending
  {:ok, lesson} = Hellen.Lessons.update_lesson_status(lesson, "pending")
  IO.puts("Reset to pending")

  # Enqueue transcription job
  {:ok, job} = %{lesson_id: lesson.id}
  |> Hellen.Workers.TranscriptionJob.new()
  |> Oban.insert()

  IO.puts("Job enqueued: #{job.id}")
else
  IO.puts("Lesson not found")
end
