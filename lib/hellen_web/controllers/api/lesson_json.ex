defmodule HellenWeb.API.LessonJSON do
  alias Hellen.Lessons.Lesson

  def index(%{lessons: lessons}) do
    %{data: for(lesson <- lessons, do: data(lesson))}
  end

  def show(%{lesson: lesson}) do
    %{data: data(lesson)}
  end

  defp data(%Lesson{} = lesson) do
    %{
      id: lesson.id,
      title: lesson.title,
      description: lesson.description,
      video_url: lesson.video_url,
      audio_url: lesson.audio_url,
      duration_seconds: lesson.duration_seconds,
      grade_level: lesson.grade_level,
      subject: lesson.subject,
      status: lesson.status,
      inserted_at: lesson.inserted_at,
      updated_at: lesson.updated_at,
      transcription: transcription_data(lesson)
    }
  end

  defp transcription_data(%{transcription: nil}), do: nil

  defp transcription_data(%{transcription: %Ecto.Association.NotLoaded{}}), do: nil

  defp transcription_data(%{transcription: transcription}) do
    %{
      id: transcription.id,
      full_text: transcription.full_text,
      language: transcription.language,
      word_count: transcription.word_count,
      inserted_at: transcription.inserted_at
    }
  end
end
