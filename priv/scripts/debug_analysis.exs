# Debug script to trace analysis failure
lesson_id = "4df838df-812a-4648-8f5c-51f88291eb17"

IO.puts("=== Debugging Analysis for Lesson #{lesson_id} ===\n")

# 1. Get lesson with transcription
lesson = Hellen.Lessons.get_lesson_with_transcription!(lesson_id)
IO.puts("1. Lesson status: #{lesson.status}")
IO.puts("   Subject: #{lesson.subject || "nil"}")
IO.puts("   Grade level: #{lesson.grade_level || "nil"}")

# 2. Check transcription
IO.puts("\n2. Transcription check:")
if lesson.transcription do
  text = lesson.transcription.full_text
  IO.puts("   Has full_text: #{text != nil}")
  IO.puts("   Text length: #{String.length(text || "")}")
  IO.puts("   First 100 chars: #{String.slice(text || "", 0..99)}")
else
  IO.puts("   NO TRANSCRIPTION!")
end

# 3. Try the analysis call directly
IO.puts("\n3. Testing NvidiaClient.analyze_pedagogy:")
transcription_text = lesson.transcription && lesson.transcription.full_text
context = %{subject: lesson.subject, grade_level: lesson.grade_level}

IO.puts("   Calling NVIDIA API...")
start_time = System.monotonic_time(:millisecond)

result = Hellen.AI.NvidiaClient.analyze_pedagogy(transcription_text, context)

elapsed = System.monotonic_time(:millisecond) - start_time
IO.puts("   API call took: #{elapsed}ms")

case result do
  {:ok, data} ->
    IO.puts("   SUCCESS!")
    IO.puts("   Model: #{data.model}")
    IO.puts("   Tokens: #{data.tokens_used}")
    IO.inspect(data.structured, label: "   Structured result", limit: 5)

    # 4. Try creating analysis
    IO.puts("\n4. Testing Analysis.create_analysis:")

    analysis_attrs = %{
      lesson_id: lesson_id,
      analysis_type: "full",
      model_used: data.model,
      raw_response: %{"content" => data.raw},  # Wrap string in map
      result: data.structured,
      overall_score: nil,
      processing_time_ms: data.processing_time_ms,
      tokens_used: data.tokens_used
    }

    case Hellen.Analysis.create_analysis(analysis_attrs) do
      {:ok, analysis} ->
        IO.puts("   SUCCESS! Analysis ID: #{analysis.id}")
      {:error, changeset} ->
        IO.puts("   FAILED! Changeset errors:")
        IO.inspect(changeset.errors, label: "   Errors")
    end

  {:error, reason} ->
    IO.puts("   FAILED!")
    IO.inspect(reason, label: "   Error")
end

IO.puts("\n=== Debug Complete ===")
