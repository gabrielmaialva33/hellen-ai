defmodule Hellen.AI.Agents.SocioEmotionalAgent do
  @moduledoc """
  SubAgent especializado em análise socioemocional.

  Responsabilidades:
  - Avaliar os 5 pilares OCDE de competências socioemocionais
  - Detectar sinais de bullying, exclusão ou desconforto
  - Medir engajamento e participação
  - Analisar clima emocional da sala
  - Identificar necessidades de suporte

  Modelo: QwQ 32B (Reasoning model para análise profunda)
  """

  @behaviour Hellen.AI.Agents.AgentBehaviour
  use Hellen.AI.Agents.AgentBase

  @impl Hellen.AI.Agents.AgentBehaviour
  def model, do: "qwen/qwq-32b"

  @impl Hellen.AI.Agents.AgentBehaviour
  def task_name, do: "socioemotional_analysis"

  @impl Hellen.AI.Agents.AgentBehaviour
  def task_description, do: "Analisando competências socioemocionais"

  @impl Hellen.AI.Agents.AgentBehaviour
  def process(transcription, context) do
    run(transcription, context)
  end

  @impl Hellen.AI.Agents.AgentBehaviour
  def build_prompt(transcription, context) do
    characters = context[:characters] || %{}
    grade_level = context[:grade_level] || "Não especificado"

    """
    Você é um especialista em desenvolvimento socioemocional e psicologia educacional. Analise a transcrição usando o framework OCDE de competências socioemocionais.

    ## Contexto
    - Nível: #{grade_level}
    - Participantes: #{inspect(characters)}

    ## Transcrição
    #{transcription}

    ## Framework OCDE - 5 Pilares de Competências Socioemocionais

    ### 1. Desempenho de Tarefas (Task Performance)
    - Autodisciplina, persistência, responsabilidade
    - Motivação para alcançar objetivos
    - Autocontrole e gestão do tempo

    ### 2. Regulação Emocional (Emotional Regulation)
    - Resistência ao estresse
    - Otimismo e autoconfiança
    - Controle emocional

    ### 3. Colaboração (Collaboration)
    - Empatia, confiança, cooperação
    - Trabalho em equipe
    - Respeito mútuo

    ### 4. Mente Aberta (Open-Mindedness)
    - Curiosidade, tolerância, criatividade
    - Abertura a novas ideias
    - Pensamento crítico

    ### 5. Engajamento com Outros (Engaging with Others)
    - Sociabilidade, assertividade, energia
    - Capacidade de expressão
    - Liderança

    ## Sua Tarefa
    Analise a transcrição avaliando cada pilar:

    ```json
    {
      "pilares_ocde": {
        "desempenho_tarefas": {
          "pontuacao": 75,
          "nivel": "desenvolvido" | "em_desenvolvimento" | "inicial" | "nao_observado",
          "evidencias": [
            {
              "competencia": "persistencia" | "responsabilidade" | "autodisciplina",
              "observacao": "O que foi observado",
              "citacao": "Trecho da transcrição",
              "protagonista": "Quem demonstrou"
            }
          ],
          "oportunidades_desenvolvimento": ["Sugestões específicas"]
        },
        "regulacao_emocional": {
          "pontuacao": 80,
          "nivel": "desenvolvido" | "em_desenvolvimento" | "inicial" | "nao_observado",
          "evidencias": [...],
          "sinais_atencao": [
            {
              "tipo": "estresse" | "ansiedade" | "frustacao" | "desanimo",
              "descricao": "O que foi percebido",
              "envolvido": "Quem",
              "severidade": "baixa" | "media" | "alta"
            }
          ],
          "oportunidades_desenvolvimento": [...]
        },
        "colaboracao": {
          "pontuacao": 85,
          "nivel": "desenvolvido" | "em_desenvolvimento" | "inicial" | "nao_observado",
          "evidencias": [...],
          "dinamicas_grupo": {
            "cooperacao_observada": true,
            "conflitos": [],
            "liderancas_emergentes": ["Quem demonstrou liderança"]
          },
          "oportunidades_desenvolvimento": [...]
        },
        "mente_aberta": {
          "pontuacao": 70,
          "nivel": "desenvolvido" | "em_desenvolvimento" | "inicial" | "nao_observado",
          "evidencias": [...],
          "momentos_curiosidade": ["Quando alunos demonstraram curiosidade"],
          "resistencias_observadas": ["Momentos de fechamento a ideias"],
          "oportunidades_desenvolvimento": [...]
        },
        "engajamento_outros": {
          "pontuacao": 78,
          "nivel": "desenvolvido" | "em_desenvolvimento" | "inicial" | "nao_observado",
          "evidencias": [...],
          "niveis_participacao": {
            "alta": ["Lista de participantes muito engajados"],
            "media": ["Lista de participantes moderadamente engajados"],
            "baixa": ["Lista de participantes pouco engajados"]
          },
          "oportunidades_desenvolvimento": [...]
        }
      },
      "clima_emocional": {
        "geral": "positivo" | "neutro" | "tenso" | "negativo",
        "momentos_positivos": [
          {
            "descricao": "Momento de alto engajamento/alegria",
            "citacao": "Trecho",
            "impacto": "Efeito no grupo"
          }
        ],
        "momentos_criticos": [
          {
            "descricao": "Momento de tensão ou desconforto",
            "citacao": "Trecho",
            "como_foi_tratado": "Resposta do professor",
            "sugestao": "Como poderia ser melhor abordado"
          }
        ],
        "evolucao_clima": "Como o clima mudou durante a aula"
      },
      "bullying_exclusao": {
        "detectado": false,
        "alertas": [
          {
            "tipo": "exclusao" | "ridicularizacao" | "isolamento" | "intimidacao",
            "descricao": "O que foi observado",
            "envolvidos": {
              "agressor": "Identificação",
              "vitima": "Identificação",
              "testemunhas": ["Lista"]
            },
            "citacao": "Trecho",
            "severidade": "baixa" | "media" | "alta" | "critica",
            "intervencao_professor": "Como o professor reagiu",
            "recomendacao": "O que deve ser feito"
          }
        ],
        "fatores_protecao": ["Elementos positivos que previnem bullying"],
        "fatores_risco": ["Elementos que aumentam risco"]
      },
      "necessidades_suporte": [
        {
          "estudante": "Identificação",
          "tipo": "emocional" | "academico" | "social" | "comportamental",
          "sinais_observados": ["Lista de sinais"],
          "urgencia": "baixa" | "media" | "alta",
          "recomendacao": "Tipo de suporte recomendado"
        }
      ],
      "praticas_professor": {
        "acolhimento": {
          "nivel": "excelente" | "bom" | "regular" | "insuficiente",
          "exemplos": ["Práticas de acolhimento observadas"]
        },
        "gestao_emocional": {
          "nivel": "excelente" | "bom" | "regular" | "insuficiente",
          "exemplos": ["Como lidou com emoções na sala"]
        },
        "promocao_colaboracao": {
          "nivel": "excelente" | "bom" | "regular" | "insuficiente",
          "exemplos": ["Estratégias para promover colaboração"]
        },
        "sugestoes_melhoria": ["Recomendações específicas"]
      },
      "pontuacao_geral": {
        "socioemocionais": 77,
        "clima_sala": 80,
        "seguranca_emocional": 85,
        "media_final": 81
      },
      "resumo_executivo": "Parágrafo detalhando a análise socioemocional"
    }
    ```

    ## Instruções Importantes
    1. Seja sensível e preciso na detecção de problemas
    2. Não crie alertas sem evidências claras
    3. Valorize momentos positivos e práticas exemplares
    4. Priorize a segurança emocional dos estudantes
    5. Forneça recomendações acionáveis

    Retorne APENAS o JSON, sem explicações adicionais.
    """
  end
end
