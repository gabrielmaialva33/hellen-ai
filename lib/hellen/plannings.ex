defmodule Hellen.Plannings do
  @moduledoc """
  Context for managing lesson plannings.

  Provides CRUD operations, AI-powered generation, and semantic search capabilities.
  """

  import Ecto.Query, warn: false

  alias Hellen.AI.{Embeddings, QdrantClient}
  alias Hellen.Plannings.Planning
  alias Hellen.Repo

  @plannings_collection "plannings"

  # ============================================================================
  # CRUD OPERATIONS
  # ============================================================================

  @doc """
  Lists plannings for a user with optional filters.

  ## Options
  - :status - Filter by status
  - :subject - Filter by subject
  - :grade_level - Filter by grade level
  - :search - Search in title/description
  - :limit - Limit results
  - :offset - Offset for pagination
  """
  def list_plannings(user_id, opts \\ []) do
    base_query()
    |> where([p], p.user_id == ^user_id)
    |> apply_filters(opts)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists plannings for an institution (coordinator view).
  """
  def list_institution_plannings(institution_id, opts \\ []) do
    base_query()
    |> where([p], p.institution_id == ^institution_id)
    |> apply_filters(opts)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single planning by ID.
  """
  def get_planning(id) do
    Repo.get(Planning, id)
    |> Repo.preload([:user, :institution, :source_lesson])
  end

  @doc """
  Gets a planning and raises if not found.
  """
  def get_planning!(id) do
    Repo.get!(Planning, id)
    |> Repo.preload([:user, :institution, :source_lesson])
  end

  @doc """
  Creates a new planning.
  """
  def create_planning(attrs) do
    %Planning{}
    |> Planning.create_changeset(attrs)
    |> Repo.insert()
    |> maybe_index_embeddings()
  end

  @doc """
  Updates a planning.
  """
  def update_planning(%Planning{} = planning, attrs) do
    planning
    |> Planning.changeset(attrs)
    |> Repo.update()
    |> maybe_reindex_embeddings(planning)
  end

  @doc """
  Deletes a planning.
  """
  def delete_planning(%Planning{} = planning) do
    # Remove from vector index
    remove_from_index(planning.id)

    Repo.delete(planning)
  end

  @doc """
  Publishes a planning (changes status to published).
  """
  def publish_planning(%Planning{} = planning) do
    planning
    |> Planning.publish_changeset()
    |> Repo.update()
  end

  @doc """
  Archives a planning.
  """
  def archive_planning(%Planning{} = planning) do
    planning
    |> Planning.archive_changeset()
    |> Repo.update()
  end

  @doc """
  Duplicates a planning for the same or different user.
  """
  def duplicate_planning(%Planning{} = planning, new_attrs \\ %{}) do
    attrs =
      planning
      |> Map.from_struct()
      |> Map.drop([
        :__meta__,
        :id,
        :inserted_at,
        :updated_at,
        :user,
        :institution,
        :source_lesson
      ])
      |> Map.put(:status, "draft")
      |> Map.put(:title, "#{planning.title} (Cópia)")
      |> Map.put(:embeddings_indexed, false)
      |> Map.merge(new_attrs)

    create_planning(attrs)
  end

  @doc """
  Returns a changeset for tracking planning changes.
  """
  def change_planning(%Planning{} = planning, attrs \\ %{}) do
    Planning.changeset(planning, attrs)
  end

  # ============================================================================
  # STATISTICS
  # ============================================================================

  @doc """
  Counts plannings by status for a user.
  """
  def count_by_status(user_id) do
    Planning
    |> where([p], p.user_id == ^user_id)
    |> group_by([p], p.status)
    |> select([p], {p.status, count(p.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Counts plannings by subject for a user.
  """
  def count_by_subject(user_id) do
    Planning
    |> where([p], p.user_id == ^user_id)
    |> group_by([p], p.subject)
    |> select([p], {p.subject, count(p.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Gets total planning count for a user.
  """
  def count_total(user_id) do
    Planning
    |> where([p], p.user_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets recent plannings for a user.
  """
  def recent_plannings(user_id, limit \\ 5) do
    Planning
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], desc: p.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  # ============================================================================
  # SEMANTIC SEARCH
  # ============================================================================

  @doc """
  Searches plannings using semantic similarity.

  Returns plannings similar to the query text based on vector embeddings.
  """
  def search_similar(query_text, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)
    limit = Keyword.get(opts, :limit, 10)
    score_threshold = Keyword.get(opts, :score_threshold, 0.7)

    with {:ok, %{embedding: vector}} <- Embeddings.generate(query_text, input_type: "query") do
      filter =
        if user_id do
          %{must: [%{key: "user_id", match: %{value: user_id}}]}
        else
          nil
        end

      case QdrantClient.search(@plannings_collection, vector,
             limit: limit,
             filter: filter,
             score_threshold: score_threshold
           ) do
        {:ok, results} ->
          planning_ids = Enum.map(results, & &1.payload["planning_id"])

          plannings =
            Planning
            |> where([p], p.id in ^planning_ids)
            |> Repo.all()
            |> Map.new(&{&1.id, &1})

          enriched =
            Enum.map(results, fn result ->
              planning = Map.get(plannings, result.payload["planning_id"])
              %{planning: planning, score: result.score, payload: result.payload}
            end)
            |> Enum.filter(& &1.planning)

          {:ok, enriched}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Finds plannings similar to an existing planning.
  """
  def find_similar(%Planning{} = planning, opts \\ []) do
    text = build_searchable_text(planning)
    search_similar(text, opts)
  end

  # ============================================================================
  # EMBEDDINGS INDEXING
  # ============================================================================

  @doc """
  Indexes a planning into Qdrant for semantic search.
  """
  def index_planning(%Planning{} = planning) do
    # Ensure collection exists
    :ok = QdrantClient.ensure_collection(@plannings_collection, :nv_embed)

    # Build searchable text
    text = build_searchable_text(planning)

    # Generate embedding
    case Embeddings.generate(text, input_type: "passage") do
      {:ok, %{embedding: vector}} ->
        point = %{
          id: planning.id,
          vector: vector,
          payload: %{
            planning_id: planning.id,
            user_id: planning.user_id,
            title: planning.title,
            subject: planning.subject,
            grade_level: planning.grade_level,
            bncc_codes: planning.bncc_codes,
            status: planning.status,
            indexed_at: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        }

        case QdrantClient.upsert_points(@plannings_collection, [point]) do
          {:ok, _} ->
            # Mark as indexed
            planning
            |> Planning.mark_indexed_changeset()
            |> Repo.update()

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Removes a planning from the vector index.
  """
  def remove_from_index(planning_id) do
    QdrantClient.delete_points(@plannings_collection, [planning_id])
  end

  @doc """
  Re-indexes all plannings for a user.
  """
  def reindex_all(user_id) do
    plannings = list_plannings(user_id, status: "published")

    results =
      Enum.map(plannings, fn planning ->
        case index_planning(planning) do
          {:ok, _} -> {:ok, planning.id}
          {:error, reason} -> {:error, {planning.id, reason}}
        end
      end)

    successes = Enum.count(results, &match?({:ok, _}, &1))
    failures = Enum.filter(results, &match?({:error, _}, &1))

    {:ok, %{indexed: successes, failed: length(failures), failures: failures}}
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp base_query do
    from(p in Planning, preload: [:user, :institution])
  end

  defp apply_filters(query, opts) do
    query
    |> filter_by_status(opts[:status])
    |> filter_by_subject(opts[:subject])
    |> filter_by_grade_level(opts[:grade_level])
    |> filter_by_search(opts[:search])
    |> apply_limit(opts[:limit])
    |> apply_offset(opts[:offset])
  end

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status), do: where(query, [p], p.status == ^status)

  defp filter_by_subject(query, nil), do: query
  defp filter_by_subject(query, subject), do: where(query, [p], p.subject == ^subject)

  defp filter_by_grade_level(query, nil), do: query
  defp filter_by_grade_level(query, level), do: where(query, [p], p.grade_level == ^level)

  defp filter_by_search(query, nil), do: query

  defp filter_by_search(query, search) do
    search_term = "%#{search}%"
    where(query, [p], ilike(p.title, ^search_term) or ilike(p.description, ^search_term))
  end

  defp apply_limit(query, nil), do: query
  defp apply_limit(query, limit), do: limit(query, ^limit)

  defp apply_offset(query, nil), do: query
  defp apply_offset(query, offset), do: offset(query, ^offset)

  defp build_searchable_text(%Planning{} = planning) do
    [
      planning.title,
      planning.description,
      Planning.subject_label(planning.subject),
      Planning.grade_level_label(planning.grade_level),
      Enum.join(planning.objectives || [], " "),
      Enum.join(planning.bncc_codes || [], " "),
      planning.methodology
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end

  defp maybe_index_embeddings({:ok, planning} = result) do
    # Index asynchronously for published plannings
    if planning.status == "published" do
      Task.start(fn -> index_planning(planning) end)
    end

    result
  end

  defp maybe_index_embeddings(error), do: error

  defp maybe_reindex_embeddings({:ok, updated_planning} = result, old_planning) do
    # Reindex if content changed significantly
    if content_changed?(old_planning, updated_planning) do
      Task.start(fn -> index_planning(updated_planning) end)
    end

    result
  end

  defp maybe_reindex_embeddings(error, _), do: error

  defp content_changed?(old, new) do
    old.title != new.title ||
      old.description != new.description ||
      old.objectives != new.objectives ||
      old.methodology != new.methodology
  end
end
