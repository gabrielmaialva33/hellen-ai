defmodule Hellen.AI.Agents.ScoringAgent do
  @moduledoc """
  SubAgent especializado em pontuação final e validação.

  Responsabilidades:
  - Agregar resultados de todos os outros agentes
  - Calcular pontuação final rigorosa
  - Validar consistência entre análises
  - Detectar viés ou inconsistências
  - Produzir avaliação final unificada

  Modelo: Llama 3.1 405B (máxima qualidade para decisão final)
  """

  @behaviour Hellen.AI.Agents.AgentBehaviour
  use Hellen.AI.Agents.AgentBase

  @impl Hellen.AI.Agents.AgentBehaviour
  def model, do: "meta/llama-3.1-405b-instruct"

  @impl Hellen.AI.Agents.AgentBehaviour
  def task_name, do: "final_scoring"

  @impl Hellen.AI.Agents.AgentBehaviour
  def task_description, do: "Calculando pontuação final"

  @impl Hellen.AI.Agents.AgentBehaviour
  def process(aggregated_results, context) do
    run(aggregated_results, context)
  end

  @impl Hellen.AI.Agents.AgentBehaviour
  def build_prompt(aggregated_results, context) do
    transcript_analysis = aggregated_results[:transcript] || %{}
    character_analysis = aggregated_results[:characters] || %{}
    planning_analysis = aggregated_results[:planning] || %{}
    compliance_analysis = aggregated_results[:compliance] || %{}
    socioemotional_analysis = aggregated_results[:socioemotional] || %{}

    subject = context[:subject] || "Não especificada"
    grade_level = context[:grade_level] || "Não especificado"

    """
    Você é um avaliador senior de qualidade pedagógica. Sua tarefa é analisar os resultados de múltiplos agentes especializados e produzir uma avaliação final unificada e rigorosa.

    ## Contexto
    - Disciplina: #{subject}
    - Nível: #{grade_level}

    ## Resultados dos Agentes Especializados

    ### 1. Análise de Transcrição (TranscriptAgent)
    #{Jason.encode!(transcript_analysis, pretty: true)}

    ### 2. Análise de Participantes (CharacterAgent)
    #{Jason.encode!(character_analysis, pretty: true)}

    ### 3. Análise de Planejamento (PlanningAgent)
    #{Jason.encode!(planning_analysis, pretty: true)}

    ### 4. Análise de Conformidade Legal (ComplianceAgent)
    #{Jason.encode!(compliance_analysis, pretty: true)}

    ### 5. Análise Socioemocional (SocioEmotionalAgent)
    #{Jason.encode!(socioemotional_analysis, pretty: true)}

    ## Sua Tarefa
    Analise todos os resultados acima e produza uma avaliação final:

    ```json
    {
      "validacao_consistencia": {
        "consistente": true,
        "divergencias": [
          {
            "entre": ["agente1", "agente2"],
            "aspecto": "O que divergiu",
            "resolucao": "Como foi resolvido"
          }
        ],
        "confiabilidade_geral": "alta" | "media" | "baixa"
      },
      "pontuacao_final": {
        "pedagogia": {
          "nota": 82,
          "peso": 0.25,
          "justificativa": "Motivo da nota",
          "componentes": {
            "clareza_explicacao": 85,
            "metodologia": 80,
            "recursos_didaticos": 78,
            "sequencia_logica": 84
          }
        },
        "engajamento": {
          "nota": 78,
          "peso": 0.20,
          "justificativa": "Motivo da nota",
          "componentes": {
            "participacao_alunos": 75,
            "interatividade": 80,
            "motivacao": 78
          }
        },
        "conformidade": {
          "nota": 95,
          "peso": 0.20,
          "justificativa": "Motivo da nota",
          "componentes": {
            "bncc": 90,
            "lei_bullying": 100,
            "direitos_estudante": 95
          }
        },
        "socioemocional": {
          "nota": 80,
          "peso": 0.20,
          "justificativa": "Motivo da nota",
          "componentes": {
            "clima_sala": 82,
            "competencias_ocde": 78,
            "seguranca_emocional": 80
          }
        },
        "planejamento": {
          "nota": 75,
          "peso": 0.15,
          "justificativa": "Motivo da nota",
          "componentes": {
            "aderencia_plano": 70,
            "adaptacoes": 80,
            "objetivos_atingidos": 75
          }
        },
        "nota_final": 82.1,
        "classificacao": "excelente" | "muito_bom" | "bom" | "regular" | "insuficiente"
      },
      "destaques_positivos": [
        {
          "area": "pedagogia" | "engajamento" | "conformidade" | "socioemocional" | "planejamento",
          "descricao": "O que foi excelente",
          "impacto": "Por que é importante"
        }
      ],
      "pontos_melhoria": [
        {
          "area": "pedagogia" | "engajamento" | "conformidade" | "socioemocional" | "planejamento",
          "descricao": "O que pode melhorar",
          "sugestao_acao": "Como melhorar",
          "prioridade": "alta" | "media" | "baixa"
        }
      ],
      "alertas_criticos": [
        {
          "tipo": "bullying" | "violacao_legal" | "seguranca" | "exclusao",
          "descricao": "Descrição do alerta",
          "fonte": "Qual agente identificou",
          "acao_requerida": "O que deve ser feito imediatamente"
        }
      ],
      "recomendacoes_formacao": [
        {
          "tema": "Tema de formação sugerido",
          "justificativa": "Por que seria benéfico",
          "urgencia": "alta" | "media" | "baixa"
        }
      ],
      "comparativo_benchmarks": {
        "vs_media_plataforma": "+5.2",
        "vs_media_disciplina": "-2.1",
        "vs_media_nivel": "+1.8",
        "posicao_percentil": 72
      },
      "evolucao_sugerida": {
        "foco_proximo_ciclo": ["Lista de focos prioritários"],
        "metas_recomendadas": [
          {
            "meta": "Descrição da meta",
            "indicador": "Como medir",
            "prazo_sugerido": "curto" | "medio" | "longo"
          }
        ]
      },
      "resumo_executivo": "3-4 parágrafos resumindo toda a avaliação de forma clara e construtiva",
      "feedback_professor": "Mensagem direta e empática para o professor, destacando pontos fortes e oportunidades de crescimento"
    }
    ```

    ## Critérios de Pontuação

    ### Escala de Notas
    - 90-100: Excelente - Referência para outros professores
    - 80-89: Muito Bom - Acima das expectativas
    - 70-79: Bom - Atende às expectativas
    - 60-69: Regular - Necessita melhorias
    - 0-59: Insuficiente - Requer intervenção

    ### Pesos das Dimensões
    - Pedagogia: 25%
    - Engajamento: 20%
    - Conformidade Legal: 20%
    - Socioemocional: 20%
    - Planejamento: 15%

    ## Instruções Importantes
    1. Seja rigoroso mas justo na avaliação
    2. Identifique inconsistências entre os agentes e resolva
    3. Priorize alertas críticos de segurança
    4. Forneça feedback construtivo e acionável
    5. O feedback ao professor deve ser empático e motivador
    6. Não infle notas - seja honesto sobre problemas
    7. Destaque genuinamente os pontos fortes

    Retorne APENAS o JSON, sem explicações adicionais.
    """
  end
end
