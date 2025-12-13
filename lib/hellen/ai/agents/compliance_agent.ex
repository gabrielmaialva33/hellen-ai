defmodule Hellen.AI.Agents.ComplianceAgent do
  @moduledoc """
  SubAgent especializado em conformidade legal e educacional.

  Responsabilidades:
  - Verificar Lei 13.185 (Programa de Combate ao Bullying)
  - Verificar Lei 13.718 (Crimes contra dignidade sexual)
  - Mapear competências BNCC abordadas (via RAG)
  - Identificar violações e riscos
  - Gerar alertas de conformidade

  Modelo: DeepSeek R1 (Thinking model para análise jurídica complexa)

  ## RAG Integration
  Este agent usa busca semântica no Qdrant para recuperar competências
  BNCC relevantes ao contexto da aula, reduzindo tokens e melhorando
  precisão das análises.
  """

  @behaviour Hellen.AI.Agents.AgentBehaviour
  use Hellen.AI.Agents.AgentBase

  alias Hellen.AI.RagRetriever

  @impl Hellen.AI.Agents.AgentBehaviour
  def model, do: "deepseek-ai/deepseek-r1"

  @impl Hellen.AI.Agents.AgentBehaviour
  def task_name, do: "legal_compliance"

  @impl Hellen.AI.Agents.AgentBehaviour
  def task_description, do: "Verificando conformidade legal e BNCC"

  @impl Hellen.AI.Agents.AgentBehaviour
  def process(transcription, context) do
    run(transcription, context)
  end

  @doc """
  Recupera contexto BNCC relevante via busca semântica no Qdrant.
  """
  @impl Hellen.AI.Agents.AgentBehaviour
  def retrieve_context(transcription, context) do
    subject = context[:subject]
    grade_level = context[:grade_level]

    # Usar primeiros 1000 chars como query semântica
    excerpt = String.slice(transcription, 0, 1000)

    case RagRetriever.retrieve_bncc_context(subject, grade_level, excerpt) do
      {:ok, bncc_context} ->
        %{bncc_rag_context: bncc_context}

      {:error, _reason} ->
        # Fallback: usar competências genéricas
        %{bncc_rag_context: get_fallback_bncc_context()}
    end
  end

  defp get_fallback_bncc_context do
    """
    ## Competências BNCC Gerais (Fallback)

    1. **Conhecimento** - Valorizar e utilizar conhecimentos sobre o mundo
    2. **Pensamento científico, crítico e criativo** - Investigar, refletir, criar soluções
    3. **Repertório cultural** - Valorizar manifestações artísticas e culturais
    4. **Comunicação** - Utilizar diferentes linguagens para se expressar
    5. **Cultura digital** - Compreender, utilizar e criar tecnologias digitais
    6. **Trabalho e projeto de vida** - Entender o mundo do trabalho e fazer escolhas
    7. **Argumentação** - Argumentar com base em fatos e dados confiáveis
    8. **Autoconhecimento e autocuidado** - Cuidar da saúde física e emocional
    9. **Empatia e cooperação** - Exercitar empatia, diálogo e resolução de conflitos
    10. **Responsabilidade e cidadania** - Agir com autonomia, responsabilidade e ética
    """
  end

  @impl Hellen.AI.Agents.AgentBehaviour
  def build_prompt(transcription, context) do
    subject = context[:subject] || "Não especificada"
    grade_level = context[:grade_level] || "Não especificado"
    characters = context[:characters] || %{}

    # BNCC context from RAG retrieval (or fallback)
    bncc_context = context[:bncc_rag_context] || get_fallback_bncc_context()

    """
    Você é um especialista em legislação educacional brasileira e conformidade pedagógica. Analise a transcrição em relação às leis e normas aplicáveis.

    ## Contexto
    - Disciplina: #{subject}
    - Nível: #{grade_level}
    - Participantes identificados: #{inspect(characters)}

    ## Transcrição
    #{transcription}

    ## Legislação a Verificar

    ### Lei 13.185/2015 - Programa de Combate à Intimidação Sistemática (Bullying)
    Art. 2º: Caracteriza-se a intimidação sistemática (bullying) quando há violência física ou psicológica em atos de:
    - Intimidação, humilhação ou discriminação
    - Ataques físicos, insultos pessoais, comentários sistemáticos e apelidos pejorativos
    - Ameaças por qualquer meio
    - Expressões preconceituosas
    - Isolamento social consciente e premeditado
    - Pilhérias (zombaria)

    Art. 4º: Objetivos do Programa incluem:
    - Capacitar docentes para identificar e resolver casos
    - Implementar medidas de conscientização, prevenção e combate
    - Integrar meios de comunicação de massa com escolas
    - Promover cidadania, capacidade empática e respeito

    ### Lei 13.718/2018 - Crimes contra dignidade sexual
    - Importunação sexual
    - Divulgação de cena de estupro, sexo ou pornografia

    #{bncc_context}

    ## Sua Tarefa
    Analise a transcrição e retorne:

    ```json
    {
      "lei_13185_bullying": {
        "conformidade": "conforme" | "alerta" | "violacao",
        "evidencias_positivas": [
          {
            "tipo": "prevencao" | "intervencao" | "conscientizacao",
            "descricao": "Ação positiva identificada",
            "citacao": "Trecho da transcrição"
          }
        ],
        "alertas": [
          {
            "tipo": "intimidacao" | "humilhacao" | "discriminacao" | "isolamento" | "apelido" | "ameaca",
            "descricao": "Descrição do alerta",
            "citacao": "Trecho problemático",
            "severidade": "baixa" | "media" | "alta" | "critica",
            "envolvidos": ["Identificação dos envolvidos"],
            "recomendacao": "O que fazer"
          }
        ],
        "analise_clima": "Análise do clima da sala em relação a bullying"
      },
      "lei_13718_dignidade": {
        "conformidade": "conforme" | "alerta" | "violacao",
        "alertas": [
          {
            "tipo": "importunacao" | "exposicao" | "linguagem_inadequada",
            "descricao": "Descrição do problema",
            "citacao": "Trecho",
            "severidade": "baixa" | "media" | "alta" | "critica",
            "recomendacao": "O que fazer"
          }
        ]
      },
      "bncc_competencias": {
        "competencias_trabalhadas": [
          {
            "numero": 9,
            "nome": "Empatia e cooperação",
            "evidencias": ["Lista de evidências na transcrição"],
            "nivel_desenvolvimento": "introdutorio" | "intermediario" | "avancado"
          }
        ],
        "competencias_predominantes": [9, 4, 7],
        "competencias_ausentes": [5, 6],
        "alinhamento_geral": "alto" | "medio" | "baixo",
        "sugestoes_integracao": ["Sugestões para melhorar alinhamento"]
      },
      "direitos_estudante": {
        "respeitados": true,
        "alertas": [
          {
            "direito": "participacao" | "expressao" | "privacidade" | "dignidade",
            "descricao": "Descrição do problema",
            "recomendacao": "O que fazer"
          }
        ]
      },
      "praticas_inclusivas": {
        "nivel": "exemplar" | "adequado" | "insuficiente" | "ausente",
        "evidencias_positivas": ["Lista de práticas inclusivas observadas"],
        "oportunidades_melhoria": ["O que poderia ser melhorado"],
        "grupos_vulneraveis_atendidos": ["Lista de grupos atendidos"]
      },
      "alertas_criticos": [
        {
          "lei_referencia": "13.185" | "13.718" | "BNCC",
          "tipo": "Tipo do alerta",
          "descricao": "Descrição completa",
          "acao_imediata_requerida": true,
          "recomendacao": "Ação sugerida"
        }
      ],
      "pontuacao_conformidade": {
        "lei_13185": 90,
        "lei_13718": 100,
        "bncc": 75,
        "geral": 88
      },
      "resumo_executivo": "Parágrafo resumindo a análise de conformidade"
    }
    ```

    ## Instruções Importantes
    1. Seja rigoroso na identificação de problemas
    2. Não crie alertas falsos - apenas com evidências claras
    3. Cite trechos específicos como evidência
    4. Priorize alertas críticos que requerem ação imediata
    5. Valorize práticas positivas encontradas

    Retorne APENAS o JSON, sem explicações adicionais.
    """
  end
end
