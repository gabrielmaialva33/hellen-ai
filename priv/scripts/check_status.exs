lesson = Hellen.Repo.get!(Hellen.Lessons.Lesson, "4df838df-812a-4648-8f5c-51f88291eb17")
|> Hellen.Repo.preload(:transcription)
IO.puts("Lesson status: #{lesson.status}")
if lesson.transcription do
  IO.puts("Transcription: #{lesson.transcription.full_text}")
  IO.puts("Language: #{lesson.transcription.language}")
  IO.puts("Word count: #{lesson.transcription.word_count}")
else
  IO.puts("No transcription yet")
end
