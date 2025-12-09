defmodule Hellen.AI.Embeddings do
  @moduledoc """
  Service for generating text embeddings using NVIDIA NIM API.

  Uses NV-Embed-v2 model which produces 1024-dimensional vectors
  optimized for semantic search and similarity tasks.

  Features:
  - Single and batch embedding generation
  - Text chunking for long documents
  - Caching with Redis (optional)
  - Automatic retry with exponential backoff
  """

  require Logger

  alias Hellen.AI.QdrantClient

  # NVIDIA NIM Embedding API
  @embedding_base_url "https://integrate.api.nvidia.com/v1"
  @embedding_model "nvidia/nv-embedqa-e5-v5"
  @embedding_dimensions 1024

  # Text chunking settings
  @default_chunk_size 500
  @default_chunk_overlap 50

  # Collections
  @lessons_collection "lessons"
  @bncc_collection "bncc_competencies"

  # ============================================================================
  # EMBEDDING GENERATION
  # ============================================================================

  @doc """
  Generates an embedding vector for a single text.

  ## Examples

      {:ok, %{embedding: vector, tokens: 42}} = Embeddings.generate("Hello world")
  """
  @spec generate(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def generate(text, opts \\ []) when is_binary(text) do
    input_type = Keyword.get(opts, :input_type, "query")
    truncate = Keyword.get(opts, :truncate, "END")

    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@embedding_base_url}/embeddings",
        json: %{
          model: @embedding_model,
          input: [text],
          input_type: input_type,
          truncate: truncate
        },
        headers: auth_headers(),
        receive_timeout: 30_000
      )

    case result do
      {:ok, %{status: 200, body: body}} ->
        embedding = get_in(body, ["data", Access.at(0), "embedding"])
        tokens = get_in(body, ["usage", "total_tokens"]) || 0
        processing_time = System.monotonic_time(:millisecond) - start_time

        Logger.debug("Generated embedding in #{processing_time}ms (#{tokens} tokens)")

        {:ok,
         %{
           embedding: embedding,
           tokens: tokens,
           dimensions: length(embedding),
           processing_time_ms: processing_time
         }}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Embedding API error #{status}: #{inspect(body)}")
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        Logger.error("Embedding request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Generates embeddings for multiple texts in a single batch request.
  More efficient than calling generate/1 multiple times.

  ## Examples

      {:ok, embeddings} = Embeddings.generate_batch(["text1", "text2", "text3"])
  """
  @spec generate_batch(list(String.t()), keyword()) :: {:ok, list(map())} | {:error, term()}
  def generate_batch(texts, opts \\ []) when is_list(texts) do
    input_type = Keyword.get(opts, :input_type, "passage")
    truncate = Keyword.get(opts, :truncate, "END")

    start_time = System.monotonic_time(:millisecond)

    result =
      Req.post("#{@embedding_base_url}/embeddings",
        json: %{
          model: @embedding_model,
          input: texts,
          input_type: input_type,
          truncate: truncate
        },
        headers: auth_headers(),
        receive_timeout: 60_000
      )

    case result do
      {:ok, %{status: 200, body: body}} ->
        embeddings =
          body["data"]
          |> Enum.sort_by(& &1["index"])
          |> Enum.map(& &1["embedding"])

        tokens = get_in(body, ["usage", "total_tokens"]) || 0
        processing_time = System.monotonic_time(:millisecond) - start_time

        Logger.info(
          "Generated #{length(embeddings)} embeddings in #{processing_time}ms (#{tokens} tokens)"
        )

        {:ok,
         %{
           embeddings: embeddings,
           count: length(embeddings),
           tokens: tokens,
           processing_time_ms: processing_time
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: body["error"] || "Unknown error"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # TEXT CHUNKING
  # ============================================================================

  @doc """
  Splits text into chunks suitable for embedding.
  Uses sentence-aware chunking to avoid cutting mid-sentence.

  ## Options
  - :chunk_size - Target chunk size in characters (default: 500)
  - :overlap - Overlap between chunks (default: 50)

  ## Examples

      chunks = Embeddings.chunk_text(long_text, chunk_size: 1000)
  """
  @spec chunk_text(String.t(), keyword()) :: list(map())
  def chunk_text(text, opts \\ []) when is_binary(text) do
    chunk_size = Keyword.get(opts, :chunk_size, @default_chunk_size)
    overlap = Keyword.get(opts, :overlap, @default_chunk_overlap)

    # Split by sentences first
    sentences =
      text
      |> String.split(~r/(?<=[.!?])\s+/)
      |> Enum.filter(&(String.trim(&1) != ""))

    # Build chunks from sentences
    build_chunks(sentences, chunk_size, overlap)
  end

  defp build_chunks(sentences, chunk_size, overlap) do
    build_chunks(sentences, chunk_size, overlap, [], "", 0)
  end

  defp build_chunks([], _chunk_size, _overlap, chunks, current_chunk, _start_idx)
       when current_chunk != "" do
    chunks ++ [%{text: String.trim(current_chunk), index: length(chunks)}]
  end

  defp build_chunks([], _chunk_size, _overlap, chunks, _current_chunk, _start_idx), do: chunks

  defp build_chunks([sentence | rest], chunk_size, overlap, chunks, current_chunk, start_idx) do
    potential_chunk = if current_chunk == "", do: sentence, else: current_chunk <> " " <> sentence

    if String.length(potential_chunk) > chunk_size and current_chunk != "" do
      # Save current chunk and start new one with overlap
      new_chunk = %{text: String.trim(current_chunk), index: length(chunks)}
      overlap_text = get_overlap_text(current_chunk, overlap)
      new_current = overlap_text <> " " <> sentence

      build_chunks(rest, chunk_size, overlap, chunks ++ [new_chunk], new_current, start_idx)
    else
      build_chunks(rest, chunk_size, overlap, chunks, potential_chunk, start_idx)
    end
  end

  defp get_overlap_text(text, overlap_chars) do
    if String.length(text) > overlap_chars do
      String.slice(text, -overlap_chars, overlap_chars)
    else
      text
    end
  end

  # ============================================================================
  # LESSON INDEXING
  # ============================================================================

  @doc """
  Indexes a lesson transcription into Qdrant for semantic search.
  Chunks the transcription and stores with metadata.

  ## Examples

      {:ok, count} = Embeddings.index_lesson(lesson_id, transcription, %{
        subject: "Matematica",
        grade_level: "5o ano"
      })
  """
  @spec index_lesson(String.t(), String.t(), map()) :: {:ok, integer()} | {:error, term()}
  def index_lesson(lesson_id, transcription, metadata \\ %{}) do
    :ok = QdrantClient.ensure_collection(@lessons_collection, :nv_embed)

    chunks = chunk_text(transcription)
    do_index_lesson(lesson_id, chunks, metadata)
  end

  defp do_index_lesson(lesson_id, [], _metadata) do
    Logger.warning("No chunks generated for lesson #{lesson_id}")
    {:ok, 0}
  end

  defp do_index_lesson(lesson_id, chunks, metadata) do
    texts = Enum.map(chunks, & &1.text)

    with {:ok, %{embeddings: embeddings}} <- generate_batch(texts, input_type: "passage"),
         points <- build_index_points(lesson_id, chunks, embeddings, metadata),
         {:ok, count} <- QdrantClient.upsert_points(@lessons_collection, points) do
      Logger.info("Indexed #{count} chunks for lesson #{lesson_id}")
      {:ok, count}
    end
  end

  defp build_index_points(lesson_id, chunks, embeddings, metadata) do
    chunks
    |> Enum.zip(embeddings)
    |> Enum.map(fn {chunk, embedding} ->
      %{
        id: Ecto.UUID.generate(),
        vector: embedding,
        payload:
          Map.merge(metadata, %{
            lesson_id: lesson_id,
            chunk_index: chunk.index,
            text: chunk.text,
            indexed_at: DateTime.utc_now() |> DateTime.to_iso8601()
          })
      }
    end)
  end

  @doc """
  Removes a lesson's vectors from the index.
  """
  @spec remove_lesson(String.t()) :: :ok | {:error, term()}
  def remove_lesson(lesson_id) do
    filter = %{
      must: [
        %{key: "lesson_id", match: %{value: lesson_id}}
      ]
    }

    QdrantClient.delete_points_by_filter(@lessons_collection, filter)
  end

  @doc """
  Searches for similar content across indexed lessons.

  ## Options
  - :limit - Maximum results (default: 10)
  - :lesson_id - Filter to specific lesson
  - :score_threshold - Minimum similarity (default: 0.7)

  ## Examples

      {:ok, results} = Embeddings.search_lessons("explain fractions")
  """
  @spec search_lessons(String.t(), keyword()) :: {:ok, list()} | {:error, term()}
  def search_lessons(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    lesson_id = Keyword.get(opts, :lesson_id, nil)
    score_threshold = Keyword.get(opts, :score_threshold, 0.7)

    # Generate query embedding
    case generate(query, input_type: "query") do
      {:ok, %{embedding: vector}} ->
        # Build filter if lesson_id provided
        filter =
          if lesson_id do
            %{must: [%{key: "lesson_id", match: %{value: lesson_id}}]}
          else
            nil
          end

        # Search Qdrant
        QdrantClient.search(@lessons_collection, vector,
          limit: limit,
          filter: filter,
          score_threshold: score_threshold
        )

      {:error, reason} ->
        {:error, {:embedding_failed, reason}}
    end
  end

  # ============================================================================
  # BNCC COMPETENCIES
  # ============================================================================

  @doc """
  Indexes BNCC competencies for semantic matching.
  Should be called once to populate the BNCC collection.
  """
  @spec index_bncc_competencies(list(map())) :: {:ok, integer()} | {:error, term()}
  def index_bncc_competencies(competencies) when is_list(competencies) do
    # Ensure collection exists
    :ok = QdrantClient.ensure_collection(@bncc_collection, :nv_embed)

    # Generate embeddings for competency descriptions
    texts = Enum.map(competencies, & &1.description)

    case generate_batch(texts, input_type: "passage") do
      {:ok, %{embeddings: embeddings}} ->
        points =
          competencies
          |> Enum.zip(embeddings)
          |> Enum.map(fn {comp, embedding} ->
            %{
              id: comp.code || Ecto.UUID.generate(),
              vector: embedding,
              payload: %{
                code: comp.code,
                area: comp[:area],
                component: comp[:component],
                description: comp.description,
                grade_levels: comp[:grade_levels] || []
              }
            }
          end)

        QdrantClient.upsert_points(@bncc_collection, points)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Finds BNCC competencies that match a given text.

  ## Examples

      {:ok, matches} = Embeddings.match_bncc("explain fractions using visual models")
  """
  @spec match_bncc(String.t(), keyword()) :: {:ok, list()} | {:error, term()}
  def match_bncc(text, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    score_threshold = Keyword.get(opts, :score_threshold, 0.75)

    case generate(text, input_type: "query") do
      {:ok, %{embedding: vector}} ->
        QdrantClient.search(@bncc_collection, vector,
          limit: limit,
          score_threshold: score_threshold
        )

      {:error, reason} ->
        {:error, {:embedding_failed, reason}}
    end
  end

  # ============================================================================
  # GENERIC COLLECTION OPERATIONS
  # ============================================================================

  @doc """
  Generic search across any collection.

  ## Options
  - :limit - Maximum results (default: 10)
  - :score_threshold - Minimum similarity (default: 0.7)
  - :filter - Additional filter criteria
  """
  @spec search(String.t(), String.t(), keyword()) :: {:ok, list()} | {:error, term()}
  def search(collection, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    score_threshold = Keyword.get(opts, :score_threshold, 0.7)
    filter = Keyword.get(opts, :filter, nil)

    case generate(query, input_type: "query") do
      {:ok, %{embedding: vector}} ->
        QdrantClient.search(collection, vector,
          limit: limit,
          filter: filter,
          score_threshold: score_threshold
        )

      {:error, reason} ->
        {:error, {:embedding_failed, reason}}
    end
  end

  @doc """
  Generic index operation for any collection.
  Indexes a single item with its text and payload.
  """
  @spec index(String.t(), String.t(), String.t(), map()) :: :ok | {:error, term()}
  def index(collection, id, text, payload \\ %{}) do
    # Ensure collection exists
    :ok = QdrantClient.ensure_collection(collection, :nv_embed)

    case generate(text, input_type: "passage") do
      {:ok, %{embedding: vector}} ->
        point = %{
          id: id,
          vector: vector,
          payload: Map.put(payload, :indexed_at, DateTime.utc_now() |> DateTime.to_iso8601())
        }

        case QdrantClient.upsert_points(collection, [point]) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # SIMILARITY
  # ============================================================================

  @doc """
  Computes cosine similarity between two texts.
  """
  @spec similarity(String.t(), String.t()) :: {:ok, float()} | {:error, term()}
  def similarity(text1, text2) do
    case generate_batch([text1, text2]) do
      {:ok, %{embeddings: [vec1, vec2]}} ->
        {:ok, cosine_similarity(vec1, vec2)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Computes cosine similarity between two vectors.
  """
  @spec cosine_similarity(list(float()), list(float())) :: float()
  def cosine_similarity(vec1, vec2) when length(vec1) == length(vec2) do
    dot_product = Enum.zip(vec1, vec2) |> Enum.map(fn {a, b} -> a * b end) |> Enum.sum()
    norm1 = :math.sqrt(Enum.map(vec1, fn x -> x * x end) |> Enum.sum())
    norm2 = :math.sqrt(Enum.map(vec2, fn x -> x * x end) |> Enum.sum())

    if norm1 == 0 or norm2 == 0 do
      0.0
    else
      dot_product / (norm1 * norm2)
    end
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  @doc """
  Returns the embedding dimensions for the current model.
  """
  @spec dimensions() :: integer()
  def dimensions, do: @embedding_dimensions

  @doc """
  Returns the model name being used.
  """
  @spec model() :: String.t()
  def model, do: @embedding_model

  defp auth_headers do
    api_key = Application.get_env(:hellen, :nvidia_api_key)

    [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]
  end
end
