defmodule Hellen.AI.RagRetriever do
  @moduledoc """
  Retrieval-Augmented Generation para SubAgents.

  Busca contexto relevante no Qdrant antes de chamar LLMs,
  reduzindo tokens e melhorando precisão das análises.

  ## Uso

      # Recuperar competências BNCC para contexto da aula
      {:ok, context} = RagRetriever.retrieve_bncc_context(
        "matemática",
        "5º ano",
        "Hoje vamos aprender sobre frações..."
      )

      # Com cache Redis (padrão)
      {:ok, context} = RagRetriever.retrieve_bncc_context(subject, grade, text, cache: true)

  ## Integração com Agents

  Agents que implementam `retrieve_context/2` callback recebem contexto RAG
  automaticamente antes do `build_prompt/2`.
  """

  require Logger

  alias Hellen.AI.Embeddings
  alias Hellen.Cache

  # TTL para cache de resultados RAG (24 horas - BNCC não muda)
  @rag_cache_ttl :timer.hours(24)

  # Limites padrão para busca semântica
  @default_limit 7
  @default_score_threshold 0.65

  # ============================================================================
  # BNCC Context Retrieval
  # ============================================================================

  @doc """
  Recupera competências BNCC relevantes para o contexto da aula.

  ## Parâmetros
    - subject: Disciplina (ex: "matemática", "língua portuguesa")
    - grade_level: Ano escolar (ex: "5º ano", "7º ano")
    - transcript_excerpt: Trecho da transcrição para busca semântica (primeiros ~1000 chars)

  ## Opções
    - :limit - Número máximo de resultados (default: 7)
    - :threshold - Score mínimo de similaridade (default: 0.65)
    - :cache - Usar cache Redis (default: true)

  ## Retorno
    {:ok, formatted_context} ou {:error, reason}

  ## Exemplo
      {:ok, bncc_context} = RagRetriever.retrieve_bncc_context(
        "matemática",
        "5º ano",
        "Hoje vamos aprender frações e como dividir pizzas igualmente"
      )
      # => "## Competências BNCC Relevantes\\n\\n### CG02 - Pensamento científico..."
  """
  @spec retrieve_bncc_context(String.t() | nil, String.t() | nil, String.t(), keyword()) ::
          {:ok, String.t()} | {:error, any()}
  def retrieve_bncc_context(subject, grade_level, transcript_excerpt, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    threshold = Keyword.get(opts, :threshold, @default_score_threshold)
    use_cache = Keyword.get(opts, :cache, true)

    # Normalizar excerpt para busca (primeiros 1000 chars)
    excerpt = normalize_excerpt(transcript_excerpt)

    # Tentar cache primeiro
    cache_key = rag_bncc_cache_key(subject, grade_level, excerpt)

    if use_cache do
      case Cache.get(cache_key) do
        {:ok, cached} when not is_nil(cached) ->
          Logger.debug("[RagRetriever] Cache hit for BNCC context")
          {:ok, cached}

        _ ->
          fetch_and_cache_bncc(excerpt, subject, grade_level, limit, threshold, cache_key)
      end
    else
      fetch_bncc_context(excerpt, subject, grade_level, limit, threshold)
    end
  end

  @doc """
  Recupera competências BNCC e retorna como lista estruturada (não formatada).

  Útil quando você precisa dos dados raw para processamento adicional.
  """
  @spec retrieve_bncc_raw(String.t(), keyword()) :: {:ok, list()} | {:error, any()}
  def retrieve_bncc_raw(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    threshold = Keyword.get(opts, :threshold, @default_score_threshold)

    case Embeddings.match_bncc(query, limit: limit, score_threshold: threshold) do
      {:ok, results} ->
        competencies =
          Enum.map(results, fn result ->
            %{
              code: result.payload["code"],
              name: result.payload["name"],
              description: result.payload["description"],
              area: result.payload["area"],
              score: result.score
            }
          end)

        {:ok, competencies}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # Feedback Templates Retrieval (Future)
  # ============================================================================

  @doc """
  Recupera templates de feedback similares para consistência.

  ## Parâmetros
    - analysis_type: Tipo de análise (compliance, socioemotional, etc.)
    - context: Contexto para busca semântica

  ## Retorno
    {:ok, templates} ou {:error, reason}
  """
  @spec retrieve_feedback_templates(String.t(), String.t(), keyword()) ::
          {:ok, list()} | {:error, any()}
  def retrieve_feedback_templates(analysis_type, context, opts \\ []) do
    limit = Keyword.get(opts, :limit, 3)
    _threshold = Keyword.get(opts, :threshold, 0.7)

    # Collection de feedback templates (a ser implementada)
    collection = "feedback_templates"

    query = "#{analysis_type}: #{context}"

    case Embeddings.search(collection, query, limit: limit) do
      {:ok, results} ->
        templates =
          Enum.map(results, fn result ->
            %{
              type: result.payload["type"],
              template: result.payload["template"],
              score: result.score
            }
          end)

        {:ok, templates}

      {:error, :not_found} ->
        # Collection não existe ainda
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # Similar Lessons Retrieval (Future)
  # ============================================================================

  @doc """
  Recupera aulas similares do histórico para contexto.

  Útil para PlanningAgent sugerir melhorias baseadas em lições passadas.
  """
  @spec retrieve_similar_lessons(String.t(), keyword()) :: {:ok, list()} | {:error, any()}
  def retrieve_similar_lessons(transcript_excerpt, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    threshold = Keyword.get(opts, :threshold, 0.75)
    exclude_lesson_id = Keyword.get(opts, :exclude)

    case Embeddings.search_lessons(transcript_excerpt, limit: limit, score_threshold: threshold) do
      {:ok, results} ->
        lessons =
          results
          |> Enum.reject(fn r -> r.payload["lesson_id"] == exclude_lesson_id end)
          |> Enum.map(fn result ->
            %{
              lesson_id: result.payload["lesson_id"],
              text: result.payload["text"],
              subject: result.payload["subject"],
              score: result.score
            }
          end)

        {:ok, lessons}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # Context Builder (Multi-source)
  # ============================================================================

  @doc """
  Constrói contexto completo para um agent combinando múltiplas fontes.

  ## Parâmetros
    - agent_type: Tipo do agent (:compliance, :socioemotional, :scoring, etc.)
    - transcription: Transcrição da aula
    - context: Contexto adicional (subject, grade_level, etc.)

  ## Retorno
    Map com todos os contextos recuperados
  """
  @spec build_agent_context(atom(), String.t(), map()) :: map()
  def build_agent_context(agent_type, transcription, context) do
    subject = context[:subject]
    grade_level = context[:grade_level]
    excerpt = String.slice(transcription, 0, 1000)

    base_context = %{}

    base_context =
      case agent_type do
        :compliance ->
          # ComplianceAgent precisa de BNCC
          case retrieve_bncc_context(subject, grade_level, excerpt) do
            {:ok, bncc} -> Map.put(base_context, :bncc_context, bncc)
            _ -> base_context
          end

        :scoring ->
          # ScoringAgent pode usar templates de feedback
          case retrieve_feedback_templates("scoring", excerpt) do
            {:ok, templates} -> Map.put(base_context, :feedback_templates, templates)
            _ -> base_context
          end

        :planning ->
          # PlanningAgent pode usar lições similares
          lesson_id = context[:lesson_id]

          case retrieve_similar_lessons(excerpt, exclude: lesson_id) do
            {:ok, lessons} -> Map.put(base_context, :similar_lessons, lessons)
            _ -> base_context
          end

        _ ->
          base_context
      end

    base_context
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp fetch_and_cache_bncc(excerpt, subject, grade_level, limit, threshold, cache_key) do
    case fetch_bncc_context(excerpt, subject, grade_level, limit, threshold) do
      {:ok, context} = result ->
        # Cache o resultado
        Cache.set(cache_key, context, ttl: @rag_cache_ttl)
        result

      error ->
        error
    end
  end

  defp fetch_bncc_context(excerpt, _subject, _grade_level, limit, threshold) do
    # Por enquanto, busca semântica pura sem filtros
    # TODO: Adicionar filtros por subject/grade_level quando tivermos mais dados
    case Embeddings.match_bncc(excerpt, limit: limit, score_threshold: threshold) do
      {:ok, results} ->
        context = format_bncc_context(results)
        {:ok, context}

      {:error, reason} ->
        Logger.warning("[RagRetriever] BNCC retrieval failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp format_bncc_context([]) do
    "Nenhuma competência BNCC específica identificada para este contexto."
  end

  defp format_bncc_context(results) do
    header = "## Competências BNCC Relevantes para Esta Aula\n\n"

    competencies =
      results
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {result, idx} ->
        code = result.payload["code"] || "N/A"
        name = result.payload["name"] || ""
        description = result.payload["description"] || ""
        score = Float.round(result.score * 100, 1)

        """
        ### #{idx}. #{code} - #{name} (#{score}% relevância)
        #{description}
        """
      end)

    footer = """

    ---
    *Competências recuperadas via busca semântica no banco vetorial BNCC.*
    """

    header <> competencies <> footer
  end

  defp normalize_excerpt(text) when is_binary(text) do
    text
    |> String.slice(0, 1000)
    |> String.trim()
  end

  defp normalize_excerpt(_), do: ""

  defp rag_bncc_cache_key(subject, grade_level, excerpt) do
    # Hash do excerpt para key mais curta
    excerpt_hash =
      :crypto.hash(:md5, excerpt)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 12)

    subject_key = normalize_key_part(subject)
    grade_key = normalize_key_part(grade_level)

    "rag:bncc:#{subject_key}:#{grade_key}:#{excerpt_hash}"
  end

  defp normalize_key_part(nil), do: "any"
  defp normalize_key_part(""), do: "any"

  defp normalize_key_part(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/, "_")
    |> String.slice(0, 20)
  end
end
