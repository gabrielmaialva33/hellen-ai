defmodule Hellen.AI.Agents.CharacterAgent do
  @moduledoc """
  SubAgent especializado em identificação de personagens/participantes.

  Responsabilidades:
  - Identificar todos os participantes da aula
  - Contar falas e palavras por pessoa
  - Analisar sentimento de cada participante
  - Detectar padrões de interação
  - Identificar papel de cada um (professor, aluno, etc)

  Modelo: Qwen3 Next 80B Thinking (raciocínio híbrido)
  """

  @behaviour Hellen.AI.Agents.AgentBehaviour
  use Hellen.AI.Agents.AgentBase

  @impl Hellen.AI.Agents.AgentBehaviour
  def model, do: "qwen/qwen3-next-80b-a3b-thinking"

  @impl Hellen.AI.Agents.AgentBehaviour
  def task_name, do: "character_identification"

  @impl Hellen.AI.Agents.AgentBehaviour
  def task_description, do: "Identificando participantes da aula"

  @impl Hellen.AI.Agents.AgentBehaviour
  def process(transcription, context) do
    run(transcription, context)
  end

  @impl Hellen.AI.Agents.AgentBehaviour
  def build_prompt(transcription, _context) do
    """
    Você é um especialista em análise de dinâmicas de sala de aula. Sua tarefa é identificar todos os participantes na transcrição e analisar suas características.

    ## Transcrição
    #{transcription}

    ## Sua Tarefa
    Identifique cada participante distinto e analise:
    1. Quem são (professor, aluno, assistente, convidado)
    2. Quantas vezes falam
    3. Qual o sentimento geral
    4. Nível de engajamento
    5. Padrões de fala

    ## Formato de Resposta (JSON)

    ```json
    {
      "participantes": [
        {
          "identificador": "Professor(a)" | "Aluno 1" | "Nome se mencionado",
          "papel": "teacher" | "student" | "assistant" | "guest" | "other",
          "contagem_falas": 50,
          "contagem_palavras": 2000,
          "caracteristicas": ["didatico", "paciente", "engajado"],
          "padrao_fala": "Usa linguagem clara, faz pausas para perguntas",
          "citacoes_representativas": [
            "Muito bem, vamos pensar juntos sobre isso",
            "Quem pode me dar um exemplo?"
          ],
          "sentimento": "positive" | "neutral" | "negative" | "mixed",
          "nivel_engajamento": "high" | "medium" | "low",
          "momentos_destaque": [
            {
              "tipo": "pergunta" | "explicacao" | "elogio" | "correcao" | "duvida",
              "descricao": "Breve descrição do momento"
            }
          ]
        }
      ],
      "dinamica_sala": {
        "tipo_interacao": "expositiva" | "dialogada" | "colaborativa" | "mista",
        "nivel_participacao_alunos": "alto" | "medio" | "baixo",
        "clima_geral": "positivo" | "neutro" | "tenso",
        "equilibrio_fala": {
          "professor_percent": 80,
          "alunos_percent": 20
        }
      },
      "interacoes_notaveis": [
        {
          "entre": ["Professor(a)", "Aluno 1"],
          "tipo": "dialogo" | "questionamento" | "feedback",
          "qualidade": "positiva" | "neutra" | "negativa",
          "descricao": "Breve descrição"
        }
      ],
      "alertas_comportamentais": [
        {
          "tipo": "exclusao" | "interrupcao" | "desrespeito" | "desengajamento",
          "envolvidos": ["Aluno X"],
          "descricao": "O que foi observado",
          "severidade": "baixa" | "media" | "alta"
        }
      ]
    }
    ```

    ## Instruções Importantes
    1. Seja preciso na contagem de falas e palavras
    2. Identifique padrões sutis de comportamento
    3. Destaque interações positivas e negativas
    4. Alerte sobre qualquer comportamento preocupante (bullying, exclusão)

    Retorne APENAS o JSON, sem explicações adicionais.
    """
  end
end
