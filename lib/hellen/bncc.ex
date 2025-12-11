defmodule Hellen.BNCC do
  @moduledoc """
  BNCC competency codes and descriptions for Lingua Portuguesa (9o ano).
  Used for tooltips and analysis matching.
  """

  @bncc_descriptions %{
    # Leitura
    "EF09LP01" => "Analisar o fenomeno da disseminacao de noticias falsas nas redes sociais",
    "EF09LP02" => "Analisar e comentar a cobertura da imprensa sobre fatos de relevancia social",
    "EF09LP03" => "Produzir artigos de opiniao, tendo em vista o contexto de producao",
    "EF09LP04" => "Reconhecer o uso de aspas em textos de diferentes generos",

    # Producao de Textos
    "EF09LP05" => "Identificar argumentos principais e secundarios em textos argumentativos",
    "EF09LP06" => "Identificar efeitos de sentido decorrentes do uso de recursos linguisticos",
    "EF09LP07" => "Produzir textos publicitarios e propagandas",
    "EF09LP08" => "Analisar os efeitos de sentido do uso de figuras de linguagem",

    # Oralidade
    "EF09LP09" => "Produzir entrevistas, podcasts e reportagens multimidia",
    "EF09LP10" => "Planejar e produzir textos do campo jornalistico-midiático",

    # Analise Linguistica
    "EF09LP11" => "Inferir efeitos de sentido decorrentes do uso de recursos coesivos",
    "EF09LP12" => "Identificar estrangeirismos e neologismos",
    "EF09LP13" => "Reconhecer variacoes linguisticas e preconceito linguistico",
    "EF09LP14" => "Analisar textos argumentativos e contra-argumentos",
    "EF09LP15" => "Identificar elementos de coesao sequencial",
    "EF09LP16" => "Analisar e utilizar modalizadores e operadores argumentativos",
    "EF09LP17" => "Analisar forma de composicao e estilo de generos jornalisticos",
    "EF09LP18" => "Analisar organizacao textual e recursos expressivos",
    "EF09LP19" => "Comparar propostas politicas e economicas em textos",
    "EF09LP20" => "Relacionar diferentes posicoes politicas com dados e evidencias",

    # Competencias gerais
    "EF9LP01" => "Analisar fenomenos de disseminacao de informacao",
    "EF9LP02" => "Analisar cobertura jornalistica",
    "EF9LP03" => "Producao de textos argumentativos",
    "EF9LP04" => "Uso de citacoes e referencias",
    "EF9LP05" => "Argumentacao e contra-argumentacao",
    "EF9LP06" => "Recursos linguisticos e efeitos de sentido",
    "EF9LP07" => "Textos publicitarios",
    "EF9LP08" => "Figuras de linguagem",
    "EF9LP09" => "Producao multimidia",
    "EF9LP10" => "Textos jornalisticos",

    # Lei antibullying
    "LEI13185" => "Lei 13.185/2015 - Programa de Combate a Intimidacao Sistematica (Bullying)"
  }

  @doc """
  Returns the description for a BNCC code.
  """
  def get_description(code) when is_binary(code) do
    # Normalize code (remove spaces, uppercase)
    normalized = code |> String.trim() |> String.upcase()
    Map.get(@bncc_descriptions, normalized, "Competencia BNCC")
  end

  def get_description(_), do: "Competencia BNCC"

  @doc """
  Returns the category/area for a BNCC code.
  """
  def get_category(code) when is_binary(code) do
    normalized = code |> String.trim() |> String.upcase()

    cond do
      String.contains?(normalized, "LP01") or String.contains?(normalized, "LP02") ->
        "Leitura"

      String.contains?(normalized, "LP03") or String.contains?(normalized, "LP04") or
          String.contains?(normalized, "LP05") ->
        "Producao"

      String.contains?(normalized, "LP09") or String.contains?(normalized, "LP10") ->
        "Oralidade"

      String.contains?(normalized, "LP1") ->
        "Analise Linguistica"

      String.starts_with?(normalized, "LEI") ->
        "Legislacao"

      true ->
        "BNCC"
    end
  end

  def get_category(_), do: "BNCC"

  @doc """
  Returns all known BNCC codes.
  """
  def all_codes, do: Map.keys(@bncc_descriptions)

  @doc """
  Calculate a weighted score based on BNCC coverage and other factors.
  Returns a float between 0.0 and 1.0.
  """
  def calculate_score(params) do
    bncc_count = Map.get(params, :bncc_count, 0)
    bullying_alerts = Map.get(params, :bullying_alerts, 0)
    word_count = Map.get(params, :word_count, 0)
    has_transcription = Map.get(params, :has_transcription, false)
    raw_score = Map.get(params, :raw_score, nil)

    # If we have a raw score from AI, use it as base
    base_score = if raw_score, do: raw_score, else: 0.5

    # BNCC bonus: each competency adds up to 0.03 (max 0.30 for 10+ competencies)
    bncc_bonus = min(bncc_count * 0.03, 0.30)

    # Bullying penalty: each alert reduces score by 0.05 (max -0.15)
    bullying_penalty = min(bullying_alerts * 0.05, 0.15)

    # Word count bonus: lessons with more content get small bonus
    word_bonus =
      cond do
        word_count > 2000 -> 0.05
        word_count > 1000 -> 0.03
        word_count > 500 -> 0.01
        true -> 0.0
      end

    # Transcription bonus
    transcription_bonus = if has_transcription, do: 0.05, else: 0.0

    # Calculate final score
    final_score = base_score + bncc_bonus - bullying_penalty + word_bonus + transcription_bonus

    # Clamp between 0.0 and 1.0
    max(0.0, min(1.0, final_score))
  end
end
