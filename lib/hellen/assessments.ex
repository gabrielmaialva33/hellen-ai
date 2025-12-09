defmodule Hellen.Assessments do
  @moduledoc """
  Context for managing assessments (provas, atividades, avaliações).

  Features:
  - CRUD operations for assessments
  - Question management
  - AI-powered generation from plannings
  - Semantic search via Qdrant
  - Statistics and analytics
  """

  import Ecto.Query, warn: false

  alias Hellen.AI.Embeddings
  alias Hellen.Assessments.Assessment
  alias Hellen.Repo

  # ============================================================================
  # CRUD OPERATIONS
  # ============================================================================

  @doc """
  Returns the list of assessments for a user.

  ## Options
    * `:status` - Filter by status
    * `:subject` - Filter by subject
    * `:grade_level` - Filter by grade level
    * `:assessment_type` - Filter by type
    * `:difficulty_level` - Filter by difficulty
    * `:search` - Search in title and description
    * `:limit` - Limit results
    * `:offset` - Offset results
  """
  def list_assessments(user_id, opts \\ []) do
    base_query(user_id)
    |> apply_filters(opts)
    |> order_by([a], desc: a.inserted_at)
    |> maybe_limit(opts)
    |> Repo.all()
  end

  @doc """
  Gets a single assessment.

  Raises `Ecto.NoResultsError` if not found.
  """
  def get_assessment!(id), do: Repo.get!(Assessment, id)

  @doc """
  Gets a single assessment for a specific user.
  """
  def get_user_assessment(user_id, assessment_id) do
    Assessment
    |> where([a], a.id == ^assessment_id and a.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Gets assessment with all associations preloaded.
  """
  def get_assessment_with_preloads!(id) do
    Assessment
    |> Repo.get!(id)
    |> Repo.preload([:user, :institution, :source_planning])
  end

  @doc """
  Creates an assessment.
  """
  def create_assessment(attrs \\ %{}) do
    %Assessment{}
    |> Assessment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates an assessment from AI generation.
  """
  def create_ai_assessment(attrs \\ %{}) do
    %Assessment{}
    |> Assessment.ai_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an assessment.
  """
  def update_assessment(%Assessment{} = assessment, attrs) do
    assessment
    |> Assessment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an assessment.
  """
  def delete_assessment(%Assessment{} = assessment) do
    Repo.delete(assessment)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking assessment changes.
  """
  def change_assessment(%Assessment{} = assessment, attrs \\ %{}) do
    Assessment.changeset(assessment, attrs)
  end

  # ============================================================================
  # STATUS MANAGEMENT
  # ============================================================================

  @doc """
  Publishes an assessment (makes it active).
  """
  def publish_assessment(%Assessment{} = assessment) do
    assessment
    |> Assessment.publish_changeset()
    |> Repo.update()
  end

  @doc """
  Archives an assessment.
  """
  def archive_assessment(%Assessment{} = assessment) do
    assessment
    |> Assessment.archive_changeset()
    |> Repo.update()
  end

  @doc """
  Duplicates an assessment with a new title.
  """
  def duplicate_assessment(%Assessment{} = assessment, user_id) do
    attrs =
      assessment
      |> Map.from_struct()
      |> Map.drop([
        :id,
        :__meta__,
        :user,
        :institution,
        :source_planning,
        :inserted_at,
        :updated_at
      ])
      |> Map.put(:title, "#{assessment.title} (cópia)")
      |> Map.put(:status, "draft")
      |> Map.put(:user_id, user_id)

    create_assessment(attrs)
  end

  # ============================================================================
  # QUESTION MANAGEMENT
  # ============================================================================

  @doc """
  Adds a question to an assessment.
  """
  def add_question(%Assessment{} = assessment, question) do
    questions = (assessment.questions || []) ++ [question]

    update_assessment(assessment, %{
      questions: questions,
      total_points: calculate_total_points(questions)
    })
  end

  @doc """
  Updates a question in an assessment by index.
  """
  def update_question(%Assessment{} = assessment, index, question) do
    questions = List.replace_at(assessment.questions || [], index, question)

    update_assessment(assessment, %{
      questions: questions,
      total_points: calculate_total_points(questions)
    })
  end

  @doc """
  Removes a question from an assessment by index.
  """
  def remove_question(%Assessment{} = assessment, index) do
    questions = List.delete_at(assessment.questions || [], index)

    update_assessment(assessment, %{
      questions: questions,
      total_points: calculate_total_points(questions)
    })
  end

  @doc """
  Reorders questions in an assessment.
  """
  def reorder_questions(%Assessment{} = assessment, new_order) do
    questions = assessment.questions || []

    reordered =
      new_order
      |> Enum.map(fn index -> Enum.at(questions, index) end)
      |> Enum.reject(&is_nil/1)

    update_assessment(assessment, %{questions: reordered})
  end

  defp calculate_total_points(questions) do
    questions
    |> Enum.map(fn q -> Decimal.new(to_string(q["points"] || "1")) end)
    |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
  end

  # ============================================================================
  # STATISTICS
  # ============================================================================

  @doc """
  Returns assessment counts by status for a user.
  """
  def count_by_status(user_id) do
    Assessment
    |> where([a], a.user_id == ^user_id)
    |> group_by([a], a.status)
    |> select([a], {a.status, count(a.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns assessment counts by type for a user.
  """
  def count_by_type(user_id) do
    Assessment
    |> where([a], a.user_id == ^user_id)
    |> group_by([a], a.assessment_type)
    |> select([a], {a.assessment_type, count(a.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns total assessments and questions count for a user.
  """
  def get_stats(user_id) do
    assessments = list_assessments(user_id)

    total_assessments = length(assessments)

    total_questions =
      assessments
      |> Enum.map(fn a -> length(a.questions || []) end)
      |> Enum.sum()

    %{
      total: total_assessments,
      total_questions: total_questions,
      by_status: count_by_status(user_id),
      by_type: count_by_type(user_id)
    }
  end

  # ============================================================================
  # SEMANTIC SEARCH (QDRANT)
  # ============================================================================

  @doc """
  Searches for similar assessments using semantic search.
  """
  def search_similar(query, user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    case Embeddings.search("assessments", query, limit: limit) do
      {:ok, results} ->
        # Filter by user and fetch full records
        ids =
          results
          |> Enum.filter(fn r -> r.payload["user_id"] == user_id end)
          |> Enum.map(& &1.payload["assessment_id"])

        assessments =
          Assessment
          |> where([a], a.id in ^ids)
          |> Repo.all()

        {:ok, assessments}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Indexes an assessment in Qdrant for semantic search.
  """
  def index_assessment(%Assessment{} = assessment) do
    text = build_index_text(assessment)

    payload = %{
      "assessment_id" => assessment.id,
      "user_id" => assessment.user_id,
      "title" => assessment.title,
      "subject" => assessment.subject,
      "grade_level" => assessment.grade_level,
      "assessment_type" => assessment.assessment_type
    }

    case Embeddings.index("assessments", assessment.id, text, payload) do
      :ok ->
        update_assessment(assessment, %{embeddings_indexed: true})

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_index_text(assessment) do
    questions_text =
      (assessment.questions || [])
      |> Enum.map_join(" ", fn q -> q["text"] || "" end)

    """
    #{assessment.title}
    #{assessment.description || ""}
    #{Assessment.subject_label(assessment.subject)}
    #{Assessment.grade_level_label(assessment.grade_level)}
    #{Assessment.assessment_type_label(assessment.assessment_type)}
    #{questions_text}
    """
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp base_query(user_id) do
    from(a in Assessment, where: a.user_id == ^user_id)
  end

  defp apply_filters(query, opts) do
    query
    |> filter_by_status(opts[:status])
    |> filter_by_subject(opts[:subject])
    |> filter_by_grade_level(opts[:grade_level])
    |> filter_by_type(opts[:assessment_type])
    |> filter_by_difficulty(opts[:difficulty_level])
    |> filter_by_search(opts[:search])
  end

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status), do: where(query, [a], a.status == ^status)

  defp filter_by_subject(query, nil), do: query
  defp filter_by_subject(query, subject), do: where(query, [a], a.subject == ^subject)

  defp filter_by_grade_level(query, nil), do: query
  defp filter_by_grade_level(query, level), do: where(query, [a], a.grade_level == ^level)

  defp filter_by_type(query, nil), do: query
  defp filter_by_type(query, type), do: where(query, [a], a.assessment_type == ^type)

  defp filter_by_difficulty(query, nil), do: query
  defp filter_by_difficulty(query, level), do: where(query, [a], a.difficulty_level == ^level)

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    search_term = "%#{search}%"
    where(query, [a], ilike(a.title, ^search_term) or ilike(a.description, ^search_term))
  end

  defp maybe_limit(query, opts) do
    case opts[:limit] do
      nil -> query
      limit -> limit(query, ^limit)
    end
  end
end
