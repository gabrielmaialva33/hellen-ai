defmodule Hellen.AI.BnccParser do
  @moduledoc """
  Parser de documentos BNCC usando NVIDIA Nemotron Parse.

  Extrai competências e habilidades da BNCC (Base Nacional Comum Curricular)
  de arquivos PDF, usando OCR avançado e classificação semântica.

  ## Processo de Extração

  ```
  PDF → PNG (por página) → Nemotron Parse → Markdown → JSON estruturado
  ```

  ## Uso

      # Extrair competências gerais (páginas 9-10)
      {:ok, competencies} = BnccParser.extract_general_competencies(pdf_path)

      # Extrair habilidades de uma área específica
      {:ok, skills} = BnccParser.extract_skills(pdf_path, area: "linguagens", pages: 150..200)
  """

  require Logger

  @nvidia_url "https://integrate.api.nvidia.com/v1/chat/completions"
  @model "nvidia/nemotron-parse"
  @max_tokens 8192

  # Páginas das competências gerais no PDF oficial da BNCC
  @general_competencies_pages [9, 10]

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Extrai as 10 competências gerais da BNCC do PDF.

  ## Parâmetros
    - pdf_path: Caminho para o arquivo PDF da BNCC

  ## Retorno
    {:ok, [competency]} ou {:error, reason}

  ## Exemplo
      {:ok, competencies} = BnccParser.extract_general_competencies("tmp/BNCC.pdf")
      # => [%{code: "CG01", name: "Conhecimento", description: "..."}]
  """
  @spec extract_general_competencies(String.t()) :: {:ok, list(map())} | {:error, any()}
  def extract_general_competencies(pdf_path) do
    Logger.info("[BnccParser] Extracting general competencies from #{pdf_path}")

    with {:ok, images} <- pdf_to_images(pdf_path, @general_competencies_pages),
         {:ok, markdown_results} <- parse_images_with_nemotron(images),
         {:ok, competencies} <- extract_competencies_from_markdown(markdown_results) do
      Logger.info("[BnccParser] Extracted #{length(competencies)} competencies")
      {:ok, competencies}
    end
  end

  @doc """
  Extrai habilidades específicas de uma área/componente da BNCC.

  ## Parâmetros
    - pdf_path: Caminho para o arquivo PDF
    - opts:
      - :area - Área de conhecimento (linguagens, matematica, ciencias, etc.)
      - :component - Componente curricular (lingua_portuguesa, matematica, etc.)
      - :pages - Range de páginas a processar

  ## Retorno
    {:ok, [skill]} ou {:error, reason}
  """
  @spec extract_skills(String.t(), keyword()) :: {:ok, list(map())} | {:error, any()}
  def extract_skills(pdf_path, opts \\ []) do
    pages = Keyword.get(opts, :pages, 1..10)
    area = Keyword.get(opts, :area)
    component = Keyword.get(opts, :component)

    Logger.info("[BnccParser] Extracting skills from pages #{inspect(pages)}")

    with {:ok, images} <- pdf_to_images(pdf_path, Enum.to_list(pages)),
         {:ok, markdown_results} <- parse_images_with_nemotron(images),
         {:ok, skills} <- extract_skills_from_markdown(markdown_results, area, component) do
      Logger.info("[BnccParser] Extracted #{length(skills)} skills")
      {:ok, skills}
    end
  end

  @doc """
  Parseia uma única página de imagem usando Nemotron Parse.

  Útil para testes e processamento individual.
  """
  @spec parse_page_image(String.t()) :: {:ok, map()} | {:error, any()}
  def parse_page_image(image_path) do
    with {:ok, base64} <- encode_image_base64(image_path),
         {:ok, result} <- call_nemotron_parse(base64, get_mime_type(image_path)) do
      {:ok, result}
    end
  end

  @doc """
  Retorna as 10 competências gerais hardcoded como fallback.

  Use quando não for possível processar o PDF ou para testes.
  """
  @spec get_fallback_general_competencies() :: list(map())
  def get_fallback_general_competencies do
    [
      %{
        code: "CG01",
        name: "Conhecimento",
        description:
          "Valorizar e utilizar os conhecimentos historicamente construídos sobre o mundo físico, social, cultural e digital para entender e explicar a realidade, continuar aprendendo e colaborar para a construção de uma sociedade justa, democrática e inclusiva.",
        area: "geral",
        skill_type: "competencia_geral",
        keywords: ["conhecimento", "aprendizagem", "sociedade", "democracia"]
      },
      %{
        code: "CG02",
        name: "Pensamento científico, crítico e criativo",
        description:
          "Exercitar a curiosidade intelectual e recorrer à abordagem própria das ciências, incluindo a investigação, a reflexão, a análise crítica, a imaginação e a criatividade, para investigar causas, elaborar e testar hipóteses, formular e resolver problemas e criar soluções.",
        area: "geral",
        skill_type: "competencia_geral",
        keywords: ["ciência", "investigação", "criatividade", "resolução de problemas"]
      },
      %{
        code: "CG03",
        name: "Repertório cultural",
        description:
          "Valorizar e fruir as diversas manifestações artísticas e culturais, das locais às mundiais, e participar de práticas diversificadas da produção artístico-cultural.",
        area: "geral",
        skill_type: "competencia_geral",
        keywords: ["cultura", "arte", "diversidade", "manifestações culturais"]
      },
      %{
        code: "CG04",
        name: "Comunicação",
        description:
          "Utilizar diferentes linguagens – verbal, corporal, visual, sonora e digital –, bem como conhecimentos das linguagens artística, matemática e científica, para se expressar e partilhar informações, experiências, ideias e sentimentos.",
        area: "geral",
        skill_type: "competencia_geral",
        keywords: ["linguagem", "expressão", "comunicação", "digital"]
      },
      %{
        code: "CG05",
        name: "Cultura digital",
        description:
          "Compreender, utilizar e criar tecnologias digitais de informação e comunicação de forma crítica, significativa, reflexiva e ética para comunicar-se, acessar e disseminar informações, produzir conhecimentos e resolver problemas.",
        area: "geral",
        skill_type: "competencia_geral",
        keywords: ["tecnologia", "digital", "ética", "informação"]
      },
      %{
        code: "CG06",
        name: "Trabalho e projeto de vida",
        description:
          "Valorizar a diversidade de saberes e vivências culturais e apropriar-se de conhecimentos e experiências para entender as relações próprias do mundo do trabalho e fazer escolhas alinhadas ao exercício da cidadania e ao seu projeto de vida.",
        area: "geral",
        skill_type: "competencia_geral",
        keywords: ["trabalho", "projeto de vida", "cidadania", "escolhas"]
      },
      %{
        code: "CG07",
        name: "Argumentação",
        description:
          "Argumentar com base em fatos, dados e informações confiáveis, para formular, negociar e defender ideias, pontos de vista e decisões comuns que respeitem e promovam os direitos humanos.",
        area: "geral",
        skill_type: "competencia_geral",
        keywords: ["argumentação", "direitos humanos", "debate", "fatos"]
      },
      %{
        code: "CG08",
        name: "Autoconhecimento e autocuidado",
        description:
          "Conhecer-se, apreciar-se e cuidar de sua saúde física e emocional, compreendendo-se na diversidade humana e reconhecendo suas emoções e as dos outros, com autocrítica e capacidade de lidar com elas.",
        area: "geral",
        skill_type: "competencia_geral",
        keywords: ["saúde", "emocional", "autoconhecimento", "autocuidado"]
      },
      %{
        code: "CG09",
        name: "Empatia e cooperação",
        description:
          "Exercitar a empatia, o diálogo, a resolução de conflitos e a cooperação, fazendo-se respeitar e promovendo o respeito ao outro e aos direitos humanos, com acolhimento e valorização da diversidade.",
        area: "geral",
        skill_type: "competencia_geral",
        keywords: ["empatia", "cooperação", "diálogo", "respeito", "diversidade"]
      },
      %{
        code: "CG10",
        name: "Responsabilidade e cidadania",
        description:
          "Agir pessoal e coletivamente com autonomia, responsabilidade, flexibilidade, resiliência e determinação, tomando decisões com base em princípios éticos, democráticos, inclusivos, sustentáveis e solidários.",
        area: "geral",
        skill_type: "competencia_geral",
        keywords: ["cidadania", "responsabilidade", "ética", "democracia", "sustentabilidade"]
      }
    ]
  end

  # ============================================================================
  # Private - PDF to Images
  # ============================================================================

  defp pdf_to_images(pdf_path, pages) do
    # Usar pdftoppm ou convert para extrair páginas como PNG
    # Por enquanto, retorna erro indicando necessidade de implementação
    # ou usa as competências de fallback

    if File.exists?(pdf_path) do
      Logger.info("[BnccParser] PDF exists, attempting conversion for pages: #{inspect(pages)}")

      # Tentar usar pdftoppm (poppler-utils)
      output_dir = Path.join(System.tmp_dir!(), "bncc_pages_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(output_dir)

      results =
        Enum.map(pages, fn page ->
          output_file = Path.join(output_dir, "page_#{page}")

          case System.cmd("pdftoppm", [
                 "-png",
                 "-f",
                 to_string(page),
                 "-l",
                 to_string(page),
                 "-r",
                 "150",
                 pdf_path,
                 output_file
               ]) do
            {_, 0} ->
              # pdftoppm adiciona sufixo com número da página
              png_file = "#{output_file}-#{page}.png"

              if File.exists?(png_file) do
                {:ok, %{page: page, path: png_file}}
              else
                # Tentar com formato diferente
                alt_png = "#{output_file}-#{String.pad_leading(to_string(page), 2, "0")}.png"

                if File.exists?(alt_png) do
                  {:ok, %{page: page, path: alt_png}}
                else
                  {:error, {:file_not_found, page}}
                end
              end

            {error, _code} ->
              {:error, {:pdftoppm_failed, page, error}}
          end
        end)

      errors = Enum.filter(results, &match?({:error, _}, &1))

      if Enum.empty?(errors) do
        images = Enum.map(results, fn {:ok, img} -> img end)
        {:ok, images}
      else
        Logger.warning("[BnccParser] Some pages failed: #{inspect(errors)}")
        # Retornar as que funcionaram
        images = results |> Enum.filter(&match?({:ok, _}, &1)) |> Enum.map(fn {:ok, img} -> img end)

        if Enum.empty?(images) do
          {:error, :pdf_conversion_failed}
        else
          {:ok, images}
        end
      end
    else
      {:error, {:file_not_found, pdf_path}}
    end
  end

  # ============================================================================
  # Private - Nemotron Parse API
  # ============================================================================

  defp parse_images_with_nemotron(images) do
    results =
      Enum.map(images, fn %{page: page, path: path} ->
        Logger.info("[BnccParser] Parsing page #{page} with Nemotron Parse")

        case parse_page_image(path) do
          {:ok, result} ->
            {:ok, Map.put(result, :page, page)}

          {:error, reason} ->
            Logger.error("[BnccParser] Failed to parse page #{page}: #{inspect(reason)}")
            {:error, {page, reason}}
        end
      end)

    successes = Enum.filter(results, &match?({:ok, _}, &1)) |> Enum.map(fn {:ok, r} -> r end)

    if Enum.empty?(successes) do
      {:error, :all_pages_failed}
    else
      {:ok, successes}
    end
  end

  defp call_nemotron_parse(base64_image, mime_type) do
    api_key = Application.get_env(:hellen, :nvidia_api_key)

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    body = %{
      "model" => @model,
      "messages" => [
        %{
          "role" => "user",
          "content" => [
            %{
              "type" => "image_url",
              "image_url" => %{
                "url" => "data:#{mime_type};base64,#{base64_image}"
              }
            }
          ]
        }
      ],
      "tools" => [
        %{
          "type" => "function",
          "function" => %{
            "name" => "markdown_bbox"
          }
        }
      ],
      "max_tokens" => @max_tokens
    }

    case Req.post(@nvidia_url, json: body, headers: headers, receive_timeout: 120_000) do
      {:ok, %{status: 200, body: response}} ->
        parse_nemotron_response(response)

      {:ok, %{status: status, body: body}} ->
        Logger.error("[BnccParser] Nemotron API error: #{status} - #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("[BnccParser] Request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  defp parse_nemotron_response(response) do
    case get_in(response, ["choices", Access.at(0), "message"]) do
      nil ->
        {:error, :invalid_response}

      message ->
        # Nemotron retorna tool_calls com o resultado
        tool_calls = message["tool_calls"] || []
        content = message["content"] || ""

        result = %{
          content: content,
          tool_calls: tool_calls,
          markdown: extract_markdown_from_response(message)
        }

        {:ok, result}
    end
  end

  defp extract_markdown_from_response(message) do
    # Tentar extrair markdown do content ou tool_calls
    cond do
      message["content"] && message["content"] != "" ->
        message["content"]

      message["tool_calls"] && length(message["tool_calls"]) > 0 ->
        message["tool_calls"]
        |> Enum.map(fn tc ->
          case tc["function"]["arguments"] do
            args when is_binary(args) ->
              case Jason.decode(args) do
                {:ok, %{"text" => text}} -> text
                {:ok, %{"markdown" => md}} -> md
                _ -> args
              end

            args when is_map(args) ->
              args["text"] || args["markdown"] || ""

            _ ->
              ""
          end
        end)
        |> Enum.join("\n\n")

      true ->
        ""
    end
  end

  # ============================================================================
  # Private - Extract Competencies
  # ============================================================================

  defp extract_competencies_from_markdown(markdown_results) do
    # Combinar todos os markdowns
    full_text =
      markdown_results
      |> Enum.map(& &1.markdown)
      |> Enum.join("\n\n")

    # Regex para encontrar competências numeradas (1. NOME\nDescrição...)
    competency_regex = ~r/(?:^|\n)(\d+)\.\s*([A-ZÁÉÍÓÚÂÊÔÀÃÕÇ][A-ZÁÉÍÓÚÂÊÔÀÃÕÇ\s,]+)\n((?:[^0-9\n].*?\n?)+)/u

    competencies =
      Regex.scan(competency_regex, full_text)
      |> Enum.map(fn [_full, number, name, description] ->
        code = "CG#{String.pad_leading(number, 2, "0")}"

        %{
          code: code,
          name: String.trim(name),
          description: String.trim(description),
          area: "geral",
          skill_type: "competencia_geral",
          keywords: extract_keywords(description)
        }
      end)

    if Enum.empty?(competencies) do
      # Fallback se regex não encontrar
      Logger.warning("[BnccParser] No competencies found via regex, using fallback")
      {:ok, get_fallback_general_competencies()}
    else
      {:ok, competencies}
    end
  end

  defp extract_skills_from_markdown(markdown_results, area, component) do
    full_text =
      markdown_results
      |> Enum.map(& &1.markdown)
      |> Enum.join("\n\n")

    # Regex para códigos de habilidade (EF01LP01, EF07MA02, etc.)
    skill_regex = ~r/(EF\d{2}[A-Z]{2}\d{2})\s*[-–:]\s*(.*?)(?=EF\d{2}[A-Z]{2}\d{2}|$)/s

    skills =
      Regex.scan(skill_regex, full_text)
      |> Enum.map(fn [_full, code, description] ->
        %{
          code: code,
          description: String.trim(description),
          area: area || infer_area_from_code(code),
          component: component || infer_component_from_code(code),
          grade_level: infer_grade_from_code(code),
          skill_type: "habilidade",
          keywords: extract_keywords(description)
        }
      end)

    {:ok, skills}
  end

  defp extract_keywords(text) do
    # Extrair palavras-chave relevantes do texto
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\sáéíóúâêôàãõç]/u, "")
    |> String.split()
    |> Enum.filter(&(String.length(&1) > 4))
    |> Enum.uniq()
    |> Enum.take(5)
  end

  defp infer_area_from_code(code) do
    case Regex.run(~r/EF\d{2}([A-Z]{2})/, code) do
      [_, component_code] ->
        case component_code do
          "LP" -> "linguagens"
          "AR" -> "linguagens"
          "EF" -> "linguagens"
          "LI" -> "linguagens"
          "MA" -> "matematica"
          "CI" -> "ciencias_natureza"
          "GE" -> "ciencias_humanas"
          "HI" -> "ciencias_humanas"
          "ER" -> "ensino_religioso"
          _ -> "outros"
        end

      _ ->
        "outros"
    end
  end

  defp infer_component_from_code(code) do
    case Regex.run(~r/EF\d{2}([A-Z]{2})/, code) do
      [_, component_code] ->
        case component_code do
          "LP" -> "lingua_portuguesa"
          "AR" -> "arte"
          "EF" -> "educacao_fisica"
          "LI" -> "lingua_inglesa"
          "MA" -> "matematica"
          "CI" -> "ciencias"
          "GE" -> "geografia"
          "HI" -> "historia"
          "ER" -> "ensino_religioso"
          _ -> "outros"
        end

      _ ->
        "outros"
    end
  end

  defp infer_grade_from_code(code) do
    case Regex.run(~r/EF(\d{2})/, code) do
      [_, year_code] ->
        case year_code do
          "01" -> "1º ano"
          "02" -> "2º ano"
          "03" -> "3º ano"
          "04" -> "4º ano"
          "05" -> "5º ano"
          "06" -> "6º ano"
          "07" -> "7º ano"
          "08" -> "8º ano"
          "09" -> "9º ano"
          "12" -> "1º e 2º anos"
          "15" -> "1º ao 5º ano"
          "35" -> "3º ao 5º ano"
          "67" -> "6º e 7º anos"
          "69" -> "6º ao 9º ano"
          "89" -> "8º e 9º anos"
          _ -> "#{year_code}º ano"
        end

      _ ->
        "não especificado"
    end
  end

  # ============================================================================
  # Private - Utilities
  # ============================================================================

  defp encode_image_base64(image_path) do
    case File.read(image_path) do
      {:ok, data} -> {:ok, Base.encode64(data)}
      {:error, reason} -> {:error, {:file_read_error, reason}}
    end
  end

  defp get_mime_type(path) do
    case Path.extname(path) |> String.downcase() do
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      _ -> "image/png"
    end
  end
end
