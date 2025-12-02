defmodule Hellen.Lessons do
  @moduledoc """
  The Lessons context - manages lessons and transcriptions.
  """

  import Ecto.Query, warn: false

  alias Hellen.Billing
  alias Hellen.Lessons.{Lesson, Transcription}
  alias Hellen.Repo
  alias Hellen.Workers.TranscriptionJob

  ## Lesson

  def get_lesson!(id), do: Repo.get!(Lesson, id)

  def get_lesson_with_transcription!(id) do
    Lesson
    |> Repo.get!(id)
    |> Repo.preload(:transcription)
  end

  def list_lessons_by_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    Lesson
    |> where([l], l.user_id == ^user_id)
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  def create_lesson(user, attrs \\ %{}) do
    # Check credits first
    case Billing.check_credits(user) do
      :ok ->
        %Lesson{}
        |> Lesson.changeset(Map.put(attrs, "user_id", user.id))
        |> Repo.insert()

      {:error, :insufficient_credits} = error ->
        error
    end
  end

  def update_lesson(%Lesson{} = lesson, attrs) do
    lesson
    |> Lesson.changeset(attrs)
    |> Repo.update()
  end

  def update_lesson_status(%Lesson{} = lesson, status) do
    lesson
    |> Lesson.status_changeset(status)
    |> Repo.update()
  end

  def delete_lesson(%Lesson{} = lesson) do
    Repo.delete(lesson)
  end

  def start_processing(%Lesson{} = lesson, user) do
    # Deduct credit and start processing
    with {:ok, _} <- Billing.use_credit(user, lesson.id),
         {:ok, lesson} <- update_lesson_status(lesson, "transcribing"),
         {:ok, _job} <- enqueue_transcription(lesson) do
      {:ok, lesson}
    end
  end

  defp enqueue_transcription(lesson) do
    %{lesson_id: lesson.id}
    |> TranscriptionJob.new()
    |> Oban.insert()
  end

  ## Transcription

  def get_transcription_by_lesson(lesson_id) do
    Repo.get_by(Transcription, lesson_id: lesson_id)
  end

  def create_transcription(lesson_id, attrs) do
    %Transcription{}
    |> Transcription.changeset(Map.put(attrs, "lesson_id", lesson_id))
    |> Repo.insert()
  end
end
