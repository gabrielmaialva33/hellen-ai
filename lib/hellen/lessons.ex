defmodule Hellen.Lessons do
  @moduledoc """
  The Lessons context - manages lessons and transcriptions.
  """

  import Ecto.Query, warn: false

  alias Hellen.Billing
  alias Hellen.Lessons.{Lesson, Transcription}
  alias Hellen.Repo
  alias Hellen.Workers.{AnalysisJob, TranscriptionJob}

  ## Lesson

  def get_lesson!(id), do: Repo.get!(Lesson, id)

  @doc """
  Gets a lesson and verifies it belongs to the given institution.
  Raises if not found or institution doesn't match.
  """
  def get_lesson!(id, institution_id) do
    Lesson
    |> where([l], l.id == ^id and l.institution_id == ^institution_id)
    |> Repo.one!()
  end

  def get_lesson_with_transcription!(id) do
    Lesson
    |> Repo.get!(id)
    |> Repo.preload(:transcription)
  end

  @doc """
  Gets a lesson with transcription, scoped to institution.
  When institution_id is nil, fetches lesson without institution scope.
  """
  def get_lesson_with_transcription!(id, nil) do
    Lesson
    |> where([l], l.id == ^id)
    |> Repo.one!()
    |> Repo.preload(:transcription)
  end

  def get_lesson_with_transcription!(id, institution_id) do
    Lesson
    |> where([l], l.id == ^id and l.institution_id == ^institution_id)
    |> Repo.one!()
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

  @doc """
  Counts total lessons for a user.
  """
  def count_lessons_by_user(user_id) do
    Lesson
    |> where([l], l.user_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Lists all lessons for an institution with optional filters.
  """
  def list_lessons_by_institution(institution_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    status = Keyword.get(opts, :status)
    subject = Keyword.get(opts, :subject)
    user_id = Keyword.get(opts, :user_id)

    Lesson
    |> where([l], l.institution_id == ^institution_id)
    |> maybe_filter_by_status(status)
    |> maybe_filter_by_subject(subject)
    |> maybe_filter_by_user(user_id)
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, status), do: where(query, [l], l.status == ^status)

  defp maybe_filter_by_subject(query, nil), do: query
  defp maybe_filter_by_subject(query, subject), do: where(query, [l], l.subject == ^subject)

  defp maybe_filter_by_user(query, nil), do: query
  defp maybe_filter_by_user(query, user_id), do: where(query, [l], l.user_id == ^user_id)

  @doc """
  Checks if a lesson status is consistent with its latest analysis.
  If status is 'analyzing' but a complete analysis exists, updates status to 'completed'.
  Returns the (potentially updated) lesson.
  """
  def ensure_lesson_status(lesson, nil), do: lesson

  def ensure_lesson_status(%{status: "analyzing"} = lesson, analysis) do
    if analysis.result && (analysis.overall_score || analysis.result["overall_score"]) do
      {:ok, updated_lesson} = update_lesson(lesson, %{status: "completed"})
      updated_lesson
    else
      lesson
    end
  end

  def ensure_lesson_status(lesson, _analysis), do: lesson

  def create_lesson(user, attrs \\ %{}) do
    # Check credits first
    case Billing.check_credits(user) do
      :ok ->
        attrs_with_ids =
          attrs
          |> Map.put("user_id", user.id)
          |> Map.put("institution_id", user.institution_id)

        %Lesson{}
        |> Lesson.changeset(attrs_with_ids)
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

  @doc """
  Updates the planned content for a lesson.
  """
  def update_planned_content(%Lesson{} = lesson, planned_content) do
    lesson
    |> Lesson.planned_content_changeset(%{planned_content: planned_content})
    |> Repo.update()
  end

  @doc """
  Updates the planned file for a lesson.
  """
  def update_planned_file(%Lesson{} = lesson, file_url, file_name) do
    lesson
    |> Lesson.planned_content_changeset(%{
      planned_file_url: file_url,
      planned_file_name: file_name
    })
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

  def reanalyze_lesson(%Lesson{} = lesson, _user) do
    # For re-analysis, we don't charge credit again for now (as per plan)
    # Just update status and enqueue analysis job
    with {:ok, lesson} <- update_lesson_status(lesson, "analyzing"),
         {:ok, _job} <- enqueue_analysis(lesson) do
      {:ok, lesson}
    end
  end

  defp enqueue_analysis(lesson) do
    %{lesson_id: lesson.id}
    |> AnalysisJob.new()
    |> Oban.insert()
  end

  ## Transcription

  def get_transcription_by_lesson(lesson_id) do
    Repo.get_by(Transcription, lesson_id: lesson_id)
  end

  def create_transcription(lesson_id, attrs) do
    %Transcription{}
    |> Transcription.changeset(Map.put(attrs, :lesson_id, lesson_id))
    |> Repo.insert()
  end

  ## Statistics

  @doc """
  Gets lesson statistics for an institution.
  """
  def get_institution_stats(institution_id) do
    total =
      Lesson
      |> where([l], l.institution_id == ^institution_id)
      |> Repo.aggregate(:count)

    by_status =
      Lesson
      |> where([l], l.institution_id == ^institution_id)
      |> group_by([l], l.status)
      |> select([l], {l.status, count(l.id)})
      |> Repo.all()
      |> Map.new()

    by_subject =
      Lesson
      |> where([l], l.institution_id == ^institution_id and not is_nil(l.subject))
      |> group_by([l], l.subject)
      |> select([l], {l.subject, count(l.id)})
      |> Repo.all()
      |> Map.new()

    %{
      total: total,
      by_status: by_status,
      by_subject: by_subject,
      pending: Map.get(by_status, "pending", 0),
      completed: Map.get(by_status, "completed", 0),
      analyzing: Map.get(by_status, "analyzing", 0) + Map.get(by_status, "transcribing", 0)
    }
  end

  @doc """
  Gets distinct subjects used by an institution.
  """
  def list_subjects(institution_id) do
    Lesson
    |> where([l], l.institution_id == ^institution_id and not is_nil(l.subject))
    |> distinct([l], l.subject)
    |> select([l], l.subject)
    |> order_by([l], l.subject)
    |> Repo.all()
  end

  alias Hellen.Lessons.TranscriptionAnnotation

  @doc """
  Returns the list of transcription_annotations.

  ## Examples

      iex> list_transcription_annotations()
      [%TranscriptionAnnotation{}, ...]

  """
  def list_transcription_annotations do
    Repo.all(TranscriptionAnnotation)
  end

  @doc """
  Returns annotations for a specific lesson, ordered by selection position.

  ## Examples

      iex> list_annotations_by_lesson("lesson-uuid")
      [%TranscriptionAnnotation{}, ...]

  """
  def list_annotations_by_lesson(lesson_id) do
    TranscriptionAnnotation
    |> where([a], a.lesson_id == ^lesson_id)
    |> order_by([a], asc: a.selection_start)
    |> Repo.all()
  end

  @doc """
  Gets a single transcription_annotation.

  Raises `Ecto.NoResultsError` if the Transcription annotation does not exist.

  ## Examples

      iex> get_transcription_annotation!(123)
      %TranscriptionAnnotation{}

      iex> get_transcription_annotation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_transcription_annotation!(id), do: Repo.get!(TranscriptionAnnotation, id)

  @doc """
  Creates a transcription_annotation.

  ## Examples

      iex> create_transcription_annotation(%{field: value})
      {:ok, %TranscriptionAnnotation{}}

      iex> create_transcription_annotation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_transcription_annotation(attrs \\ %{}) do
    %TranscriptionAnnotation{}
    |> TranscriptionAnnotation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a transcription_annotation.

  ## Examples

      iex> update_transcription_annotation(transcription_annotation, %{field: new_value})
      {:ok, %TranscriptionAnnotation{}}

      iex> update_transcription_annotation(transcription_annotation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_transcription_annotation(
        %TranscriptionAnnotation{} = transcription_annotation,
        attrs
      ) do
    transcription_annotation
    |> TranscriptionAnnotation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a transcription_annotation.

  ## Examples

      iex> delete_transcription_annotation(transcription_annotation)
      {:ok, %TranscriptionAnnotation{}}

      iex> delete_transcription_annotation(transcription_annotation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_transcription_annotation(%TranscriptionAnnotation{} = transcription_annotation) do
    Repo.delete(transcription_annotation)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking transcription_annotation changes.

  ## Examples

      iex> change_transcription_annotation(transcription_annotation)
      %Ecto.Changeset{data: %TranscriptionAnnotation{}}

  """
  def change_transcription_annotation(
        %TranscriptionAnnotation{} = transcription_annotation,
        attrs \\ %{}
      ) do
    TranscriptionAnnotation.changeset(transcription_annotation, attrs)
  end
end
