defmodule Hellen.AI.QdrantClient do
  @moduledoc """
  Client for Qdrant vector database.
  Handles collection management, vector insertion, and semantic search.

  Uses Qdrant REST API on port 6333.

  Collections:
  - lessons: Transcription chunks for semantic search
  - bncc: BNCC competencies for matching
  - feedback_templates: Pedagogical feedback templates
  """

  require Logger

  alias Hellen.AI.Embeddings

  @default_url "http://localhost:6333"
  @default_timeout 30_000

  # Vector dimensions for different embedding models
  @dimensions %{
    # NVIDIA NV-Embed-v2 (1024 dimensions)
    nv_embed: 1024,
    # OpenAI text-embedding-3-small
    openai_small: 1536,
    # Sentence transformers
    sentence_transformers: 384
  }

  # Get base URL from config or use default
  defp base_url do
    Application.get_env(:hellen, :qdrant_url, @default_url)
  end

  # ============================================================================
  # COLLECTION MANAGEMENT
  # ============================================================================

  @doc """
  Creates a collection with the specified vector configuration.

  ## Examples

      QdrantClient.create_collection("lessons", :nv_embed)
      QdrantClient.create_collection("bncc", :nv_embed, distance: "Cosine")
  """
  @spec create_collection(String.t(), atom(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_collection(name, embedding_type \\ :nv_embed, opts \\ []) do
    distance = Keyword.get(opts, :distance, "Cosine")
    dimensions = Map.get(@dimensions, embedding_type, @dimensions.nv_embed)

    body = %{
      vectors: %{
        size: dimensions,
        distance: distance
      },
      optimizers_config: %{
        indexing_threshold: 20_000
      },
      replication_factor: 1
    }

    case request(:put, "/collections/#{name}", body) do
      {:ok, %{status: status}} when status in [200, 201] ->
        Logger.info("Created Qdrant collection: #{name} (#{dimensions}d, #{distance})")
        {:ok, %{name: name, dimensions: dimensions, distance: distance}}

      {:ok, %{status: 400, body: %{"status" => %{"error" => error}}}} ->
        if String.contains?(error, "already exists") do
          Logger.info("Collection #{name} already exists")
          {:ok, %{name: name, exists: true}}
        else
          {:error, error}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a collection.
  """
  @spec delete_collection(String.t()) :: :ok | {:error, term()}
  def delete_collection(name) do
    case request(:delete, "/collections/#{name}") do
      {:ok, %{status: 200}} ->
        Logger.info("Deleted Qdrant collection: #{name}")
        :ok

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets collection info.
  """
  @spec get_collection(String.t()) :: {:ok, map()} | {:error, term()}
  def get_collection(name) do
    case request(:get, "/collections/#{name}") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body["result"]}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all collections.
  """
  @spec list_collections() :: {:ok, list()} | {:error, term()}
  def list_collections do
    case request(:get, "/collections") do
      {:ok, %{status: 200, body: body}} ->
        collections =
          body["result"]["collections"]
          |> Enum.map(& &1["name"])

        {:ok, collections}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Ensures a collection exists, creating it if needed.
  """
  @spec ensure_collection(String.t(), atom(), keyword()) :: :ok | {:error, term()}
  def ensure_collection(name, embedding_type \\ :nv_embed, opts \\ []) do
    case get_collection(name) do
      {:ok, _} ->
        :ok

      {:error, :not_found} ->
        case create_collection(name, embedding_type, opts) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # POINT OPERATIONS
  # ============================================================================

  @doc """
  Inserts points (vectors with payloads) into a collection.

  ## Examples

      points = [
        %{id: "uuid-1", vector: [0.1, 0.2, ...], payload: %{text: "chunk 1", lesson_id: "..."}},
        %{id: "uuid-2", vector: [0.3, 0.4, ...], payload: %{text: "chunk 2", lesson_id: "..."}}
      ]
      QdrantClient.upsert_points("lessons", points)
  """
  @spec upsert_points(String.t(), list(map())) :: {:ok, integer()} | {:error, term()}
  def upsert_points(collection, points) when is_list(points) do
    # Format points for Qdrant API
    formatted_points =
      Enum.map(points, fn point ->
        %{
          id: point.id || Ecto.UUID.generate(),
          vector: point.vector,
          payload: point[:payload] || %{}
        }
      end)

    body = %{
      points: formatted_points
    }

    case request(:put, "/collections/#{collection}/points", body) do
      {:ok, %{status: 200, body: %{"status" => "ok"}}} ->
        Logger.debug("Upserted #{length(points)} points to #{collection}")
        {:ok, length(points)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to upsert points: #{status} - #{inspect(body)}")
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets points by IDs.
  """
  @spec get_points(String.t(), list(String.t())) :: {:ok, list()} | {:error, term()}
  def get_points(collection, ids) when is_list(ids) do
    body = %{
      ids: ids,
      with_payload: true,
      with_vector: false
    }

    case request(:post, "/collections/#{collection}/points", body) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body["result"]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes points by IDs.
  """
  @spec delete_points(String.t(), list(String.t())) :: :ok | {:error, term()}
  def delete_points(collection, ids) when is_list(ids) do
    body = %{
      points: ids
    }

    case request(:post, "/collections/#{collection}/points/delete", body) do
      {:ok, %{status: 200}} ->
        Logger.debug("Deleted #{length(ids)} points from #{collection}")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes points matching a filter.
  """
  @spec delete_points_by_filter(String.t(), map()) :: :ok | {:error, term()}
  def delete_points_by_filter(collection, filter) do
    body = %{
      filter: filter
    }

    case request(:post, "/collections/#{collection}/points/delete", body) do
      {:ok, %{status: 200}} ->
        Logger.debug("Deleted points by filter from #{collection}")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # SEARCH OPERATIONS
  # ============================================================================

  @doc """
  Performs semantic search using a query vector.

  ## Options
  - :limit - Maximum number of results (default: 10)
  - :score_threshold - Minimum similarity score (default: 0.7)
  - :filter - Qdrant filter conditions
  - :with_payload - Include payload in results (default: true)

  ## Examples

      {:ok, results} = QdrantClient.search("lessons", query_vector, limit: 5)
      {:ok, results} = QdrantClient.search("lessons", query_vector,
        filter: %{must: [%{key: "lesson_id", match: %{value: "uuid"}}]}
      )
  """
  @spec search(String.t(), list(float()), keyword()) :: {:ok, list()} | {:error, term()}
  def search(collection, vector, opts \\ []) when is_list(vector) do
    limit = Keyword.get(opts, :limit, 10)
    score_threshold = Keyword.get(opts, :score_threshold, 0.7)
    filter = Keyword.get(opts, :filter, nil)
    with_payload = Keyword.get(opts, :with_payload, true)

    body =
      %{
        vector: vector,
        limit: limit,
        score_threshold: score_threshold,
        with_payload: with_payload
      }
      |> maybe_add_filter(filter)

    case request(:post, "/collections/#{collection}/points/search", body) do
      {:ok, %{status: 200, body: body}} ->
        results =
          body["result"]
          |> Enum.map(fn result ->
            %{
              id: result["id"],
              score: result["score"],
              payload: result["payload"]
            }
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Searches using text by first generating an embedding.
  Requires the Embeddings module to be configured.
  """
  @spec search_text(String.t(), String.t(), keyword()) :: {:ok, list()} | {:error, term()}
  def search_text(collection, query_text, opts \\ []) do
    case Embeddings.generate(query_text) do
      {:ok, %{embedding: vector}} ->
        search(collection, vector, opts)

      {:error, reason} ->
        {:error, {:embedding_failed, reason}}
    end
  end

  @doc """
  Batch search with multiple vectors.
  """
  @spec batch_search(String.t(), list(list(float())), keyword()) ::
          {:ok, list(list())} | {:error, term()}
  def batch_search(collection, vectors, opts \\ []) when is_list(vectors) do
    limit = Keyword.get(opts, :limit, 10)
    score_threshold = Keyword.get(opts, :score_threshold, 0.7)

    searches =
      Enum.map(vectors, fn vector ->
        %{
          vector: vector,
          limit: limit,
          score_threshold: score_threshold,
          with_payload: true
        }
      end)

    body = %{
      searches: searches
    }

    case request(:post, "/collections/#{collection}/points/search/batch", body) do
      {:ok, %{status: 200, body: body}} ->
        results =
          body["result"]
          |> Enum.map(fn search_result ->
            Enum.map(search_result, fn result ->
              %{
                id: result["id"],
                score: result["score"],
                payload: result["payload"]
              }
            end)
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # SCROLL/PAGINATION
  # ============================================================================

  @doc """
  Scrolls through all points in a collection.
  Useful for iteration or export.
  """
  @spec scroll(String.t(), keyword()) :: {:ok, list(), String.t() | nil} | {:error, term()}
  def scroll(collection, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, nil)
    filter = Keyword.get(opts, :filter, nil)

    body =
      %{
        limit: limit,
        with_payload: true,
        with_vector: false
      }
      |> maybe_add_filter(filter)
      |> maybe_add_offset(offset)

    case request(:post, "/collections/#{collection}/points/scroll", body) do
      {:ok, %{status: 200, body: body}} ->
        points = body["result"]["points"]
        next_offset = body["result"]["next_page_offset"]
        {:ok, points, next_offset}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # HEALTH CHECK
  # ============================================================================

  @doc """
  Checks if Qdrant is healthy.
  """
  @spec health() :: :ok | {:error, term()}
  def health do
    case Req.get("#{base_url()}/health", receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status}} -> {:error, {:unhealthy, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets Qdrant cluster info.
  """
  @spec info() :: {:ok, map()} | {:error, term()}
  def info do
    case request(:get, "/") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp request(method, path, body \\ nil) do
    url = "#{base_url()}#{path}"

    opts =
      [
        receive_timeout: @default_timeout
      ]
      |> add_json_body(method, body)

    case apply(Req, method, [url, opts]) do
      {:ok, %{status: status, body: body}} ->
        {:ok, %{status: status, body: body}}

      {:error, reason} ->
        Logger.error("Qdrant request failed: #{method} #{path} - #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp add_json_body(opts, method, body)
       when method in [:put, :post, :patch] and not is_nil(body) do
    Keyword.put(opts, :json, body)
  end

  defp add_json_body(opts, _method, _body), do: opts

  defp maybe_add_filter(body, nil), do: body
  defp maybe_add_filter(body, filter), do: Map.put(body, :filter, filter)

  defp maybe_add_offset(body, nil), do: body
  defp maybe_add_offset(body, offset), do: Map.put(body, :offset, offset)
end
