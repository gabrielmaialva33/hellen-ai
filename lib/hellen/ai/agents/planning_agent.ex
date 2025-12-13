defmodule Hellen.AI.Agents.PlanningAgent do
  @moduledoc """
  SubAgent especializado em análise de planejamento vs execução.

  Responsabilidades:
  - Ler material planejado (DOCX/PDF extraído)
  - Comparar com transcrição da aula
  - Calcular percentual de aderência
  - Identificar gaps e adições
  - Avaliar sequência didática

  Modelo: Kimi K2 Thinking (200K context para documentos longos)
  """

  @behaviour Hellen.AI.Agents.AgentBehaviour
  use Hellen.AI.Agents.AgentBase

  @impl Hellen.AI.Agents.AgentBehaviour
  def model, do: "moonshotai/kimi-k2-instruct"

  @impl Hellen.AI.Agents.AgentBehaviour
  def task_name, do: "planning_analysis"

  @impl Hellen.AI.Agents.AgentBehaviour
  def task_description, do: "Comparando planejamento com execução"

  @impl Hellen.AI.Agents.AgentBehaviour
  def process(transcription, context) do
    run(transcription, context)
  end

  @impl Hellen.AI.Agents.AgentBehaviour
  def build_prompt(transcription, context) do
    planned_content = context[:planned_content] || "Não fornecido"
    subject = context[:subject] || "Não especificada"
    grade_level = context[:grade_level] || "Não especificado"

    """
    Você é um especialista em análise pedagógica e planejamento de aulas. Sua tarefa é comparar o que foi planejado com o que foi efetivamente executado.

    ## Contexto
    - Disciplina: #{subject}
    - Nível: #{grade_level}

    ## Material Planejado
    #{planned_content}

    ## Transcrição da Aula Realizada
    #{transcription}

    ## Sua Tarefa
    Compare detalhadamente o planejamento com a execução e avalie:
    1. O que foi planejado e executado
    2. O que foi planejado mas não executado
    3. O que foi executado sem estar no planejamento (improviso/adaptação)
    4. Qualidade das adaptações feitas
    5. Coerência da sequência didática

    ## Formato de Resposta (JSON)

    ```json
    {
      "aderencia_percentual": 85,
      "classificacao_aderencia": "alta" | "media" | "baixa",
      "itens_planejados": [
        {
          "item": "Descrição do item planejado",
          "status": "executado" | "parcial" | "nao_executado",
          "observacao": "Como foi executado ou por que não foi"
        }
      ],
      "itens_nao_planejados": [
        {
          "item": "O que foi feito sem estar no plano",
          "tipo": "improviso" | "adaptacao" | "desvio",
          "avaliacao": "positivo" | "neutro" | "negativo",
          "justificativa": "Por que foi positivo/negativo"
        }
      ],
      "gaps_identificados": [
        {
          "descricao": "O que faltou",
          "impacto": "alto" | "medio" | "baixo",
          "sugestao": "Como poderia ser abordado"
        }
      ],
      "sequencia_didatica": {
        "coerencia": "alta" | "media" | "baixa",
        "ordem_logica": true,
        "transicoes_adequadas": true,
        "tempo_adequado_por_topico": true,
        "observacoes": "Detalhes sobre a sequência"
      },
      "uso_recursos": {
        "recursos_previstos": ["lista de recursos no plano"],
        "recursos_utilizados": ["lista do que foi usado"],
        "recursos_nao_utilizados": ["o que não foi usado"],
        "recursos_improvisados": ["recursos usados sem previsão"]
      },
      "objetivos_aprendizagem": {
        "objetivos_planejados": ["lista dos objetivos"],
        "objetivos_atingidos": ["lista dos atingidos"],
        "taxa_atingimento": 75,
        "analise": "Avaliação qualitativa do atingimento"
      },
      "adaptacoes_pedagogicas": [
        {
          "descricao": "Adaptação feita pelo professor",
          "contexto": "Por que foi necessária",
          "qualidade": "excelente" | "boa" | "regular" | "ruim",
          "justificativa": "Avaliação da adaptação"
        }
      ],
      "recomendacoes": [
        {
          "area": "planejamento" | "execucao" | "recursos" | "tempo",
          "sugestao": "Recomendação específica",
          "prioridade": "alta" | "media" | "baixa"
        }
      ],
      "resumo_executivo": "Parágrafo resumindo a análise de aderência e qualidade da execução"
    }
    ```

    ## Instruções Importantes
    1. Se não houver material planejado, foque em analisar a estrutura da aula executada
    2. Seja específico nos gaps e recomendações
    3. Valorize adaptações pedagógicas bem feitas
    4. Considere o contexto da sala de aula (imprevistos acontecem)

    Retorne APENAS o JSON, sem explicações adicionais.
    """
  end
end
