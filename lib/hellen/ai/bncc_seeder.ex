defmodule Hellen.AI.BnccSeeder do
  @moduledoc """
  Seeder para indexar competências BNCC no Qdrant.

  Responsável por:
  - Extrair competências do PDF da BNCC (ou usar fallback)
  - Gerar embeddings via NVIDIA NV-Embed-v2
  - Indexar no Qdrant collection "bncc_competencies"

  ## Uso

      # Seed apenas competências gerais (MVP)
      {:ok, count} = BnccSeeder.seed_general_competencies()

      # Seed com PDF real
      {:ok, count} = BnccSeeder.seed_from_pdf("tmp/BNCC.pdf")

      # Re-indexar tudo (limpa e recria)
      {:ok, count} = BnccSeeder.reseed!()

      # Verificar status
      BnccSeeder.status()
  """

  require Logger

  alias Hellen.AI.{BnccParser, Embeddings, QdrantClient}

  @bncc_collection "bncc_competencies"

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Indexa as 10 competências gerais da BNCC no Qdrant.

  Usa as competências hardcoded do BnccParser como MVP.
  Mais rápido e confiável para começar.

  ## Retorno
    {:ok, count} - Número de competências indexadas
    {:error, reason} - Erro na indexação
  """
  @spec seed_general_competencies() :: {:ok, integer()} | {:error, any()}
  def seed_general_competencies do
    Logger.info("[BnccSeeder] Starting seed of general competencies")

    competencies = BnccParser.get_fallback_general_competencies()

    case Embeddings.index_bncc_competencies(competencies) do
      {:ok, count} ->
        Logger.info("[BnccSeeder] Successfully indexed #{count} general competencies")
        {:ok, count}

      {:error, reason} = error ->
        Logger.error("[BnccSeeder] Failed to index competencies: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Indexa competências extraídas do PDF da BNCC.

  Usa NVIDIA Nemotron Parse para OCR e extração estruturada.

  ## Parâmetros
    - pdf_path: Caminho para o arquivo PDF da BNCC

  ## Opções
    - :include_skills - Se true, extrai também habilidades específicas
    - :skill_pages - Range de páginas para habilidades (default: nenhum)

  ## Retorno
    {:ok, count} ou {:error, reason}
  """
  @spec seed_from_pdf(String.t(), keyword()) :: {:ok, integer()} | {:error, any()}
  def seed_from_pdf(pdf_path, opts \\ []) do
    Logger.info("[BnccSeeder] Starting seed from PDF: #{pdf_path}")

    include_skills = Keyword.get(opts, :include_skills, false)

    with {:ok, general} <- extract_or_fallback_general(pdf_path),
         {:ok, skills} <- maybe_extract_skills(pdf_path, include_skills, opts),
         all_competencies = general ++ skills,
         {:ok, count} <- Embeddings.index_bncc_competencies(all_competencies) do
      Logger.info("[BnccSeeder] Successfully indexed #{count} items from PDF")
      {:ok, count}
    end
  end

  @doc """
  Limpa a collection e re-indexa todas as competências.

  CUIDADO: Esta operação é destrutiva!
  """
  @spec reseed!() :: {:ok, integer()} | {:error, any()}
  def reseed! do
    Logger.warning("[BnccSeeder] Reseeding - clearing collection first")

    # Deletar collection existente
    _ = QdrantClient.delete_collection(@bncc_collection)

    # Aguardar um momento para garantir que foi deletada
    Process.sleep(500)

    # Re-criar e popular
    seed_general_competencies()
  end

  @doc """
  Retorna o status atual da indexação BNCC.

  ## Retorno
    Map com informações da collection
  """
  @spec status() :: map()
  def status do
    case QdrantClient.get_collection(@bncc_collection) do
      {:ok, info} ->
        %{
          exists: true,
          points_count: info["points_count"] || 0,
          vectors_count: info["vectors_count"] || 0,
          status: info["status"] || "unknown",
          collection: @bncc_collection
        }

      {:error, _} ->
        %{
          exists: false,
          points_count: 0,
          vectors_count: 0,
          status: "not_found",
          collection: @bncc_collection
        }
    end
  end

  @doc """
  Testa a busca semântica com uma query de exemplo.

  Útil para validar que a indexação está funcionando.

  ## Exemplo
      BnccSeeder.test_search("trabalho em equipe e cooperação")
  """
  @spec test_search(String.t(), keyword()) :: {:ok, list()} | {:error, any()}
  def test_search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    threshold = Keyword.get(opts, :threshold, 0.5)

    Logger.info("[BnccSeeder] Testing search: '#{query}'")

    case Embeddings.match_bncc(query, limit: limit, score_threshold: threshold) do
      {:ok, results} ->
        Logger.info("[BnccSeeder] Found #{length(results)} matches")

        Enum.each(results, fn result ->
          score = Float.round(result.score, 3)
          code = result.payload["code"]
          name = result.payload["name"] || "N/A"
          Logger.info("  [#{score}] #{code}: #{name}")
        end)

        {:ok, results}

      {:error, reason} = error ->
        Logger.error("[BnccSeeder] Search failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Lista todas as competências indexadas.
  """
  @spec list_indexed() :: {:ok, list()} | {:error, any()}
  def list_indexed do
    case QdrantClient.scroll(@bncc_collection, limit: 100) do
      {:ok, points, _next_offset} ->
        competencies =
          Enum.map(points, fn point ->
            desc = get_in(point, ["payload", "description"]) || ""

            %{
              id: point["id"],
              code: get_in(point, ["payload", "code"]),
              name: get_in(point, ["payload", "name"]),
              area: get_in(point, ["payload", "area"]),
              description: String.slice(desc, 0, 100) <> "..."
            }
          end)

        {:ok, competencies}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp extract_or_fallback_general(pdf_path) do
    case BnccParser.extract_general_competencies(pdf_path) do
      {:ok, [_ | _] = competencies} ->
        {:ok, competencies}

      _ ->
        Logger.warning("[BnccSeeder] PDF extraction failed, using fallback")
        {:ok, BnccParser.get_fallback_general_competencies()}
    end
  end

  defp maybe_extract_skills(_pdf_path, false, _opts), do: {:ok, []}

  defp maybe_extract_skills(pdf_path, true, opts) do
    pages = Keyword.get(opts, :skill_pages, 150..200)
    area = Keyword.get(opts, :area)
    component = Keyword.get(opts, :component)

    case BnccParser.extract_skills(pdf_path, pages: pages, area: area, component: component) do
      {:ok, skills} -> {:ok, skills}
      {:error, _} -> {:ok, []}
    end
  end
end
