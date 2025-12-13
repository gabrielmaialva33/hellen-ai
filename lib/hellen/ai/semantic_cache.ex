defmodule Hellen.AI.SemanticCache do
  @moduledoc """
  Semantic Caching for AI responses.

  Uses Qdrant to find semantically similar previous queries and returns
  cached responses to save tokens and reduce latency.
  """

  require Logger
  alias Hellen.AI.Embeddings
  alias Hellen.AI.QdrantClient

  @collection_name "semantic_cache"
  # High threshold for strict semantic matching
  @similarity_threshold 0.95

  @doc """
  Ensures the semantic cache collection exists in Qdrant.
  """
  def setup do
    QdrantClient.ensure_collection(@collection_name, :nv_embed)
  end

  @doc """
  Tries to find a cached response for the given query/prompt.
  Returns `{:ok, response}` if found, or `{:miss, :reason}` if not.
  """
  def get(query_text) do
    # 1. Generate embedding for the query
    case Embeddings.generate(query_text, input_type: "query") do
      {:ok, %{embedding: vector}} ->
        # 2. Search Qdrant
        case QdrantClient.search(@collection_name, vector,
               limit: 1,
               score_threshold: @similarity_threshold
             ) do
          {:ok, [%{score: score, payload: payload} | _]} ->
            Logger.info("Semantic Cache HIT (score: #{score})")
            # Assuming stored as stringified JSON
            {:ok, Jason.decode!(payload["response"])}

          {:ok, []} ->
            Logger.debug("Semantic Cache MISS")
            {:miss, :not_found}

          {:error, reason} ->
            Logger.error("Semantic Cache search failed: #{inspect(reason)}")
            {:miss, reason}
        end

      {:error, reason} ->
        Logger.error("Embedding generation failed for cache: #{inspect(reason)}")
        {:miss, reason}
    end
  end

  @doc """
  Stores a response in the semantic cache.
  """
  def put(query_text, response_data) do
    # 1. Generate embedding
    case Embeddings.generate(query_text, input_type: "query") do
      {:ok, %{embedding: vector}} ->
        # 2. Upsert to Qdrant
        point = %{
          id: Ecto.UUID.generate(),
          vector: vector,
          payload: %{
            query: query_text,
            response: Jason.encode!(response_data),
            cached_at: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        }

        QdrantClient.upsert_points(@collection_name, [point])
        Logger.info("Cached response for query: #{String.slice(query_text, 0, 50)}...")
        :ok

      {:error, reason} ->
        Logger.error("Failed to cache response: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Wraps an AI execution function with semantic caching.
  """
  def fetch_or_compute(query, compute_fn) do
    case get(query) do
      {:ok, cached_response} ->
        {:ok, cached_response}

      {:miss, _} ->
        compute_and_cache(query, compute_fn)
    end
  end

  defp compute_and_cache(query, compute_fn) do
    case compute_fn.() do
      {:ok, response} ->
        Task.start(fn -> put(query, response) end)
        {:ok, response}

      error ->
        error
    end
  end
end
