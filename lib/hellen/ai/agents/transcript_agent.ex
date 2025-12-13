defmodule Hellen.AI.Agents.TranscriptAgent do
  @moduledoc """
  SubAgent especializado em processamento de transcrições.

  Responsabilidades:
  - Ler e processar transcrição completa
  - Criar resumo executivo
  - Extrair tópicos principais
  - Identificar momentos-chave
  - Detectar estrutura da aula

  Modelo: Llama 3.1 70B (custo-benefício)
  """

  @behaviour Hellen.AI.Agents.AgentBehaviour
  use Hellen.AI.Agents.AgentBase

  @impl Hellen.AI.Agents.AgentBehaviour
  def model, do: "meta/llama-3.1-70b-instruct"

  @impl Hellen.AI.Agents.AgentBehaviour
  def task_name, do: "transcript_processing"

  @impl Hellen.AI.Agents.AgentBehaviour
  def task_description, do: "Processando transcrição da aula"

  @impl Hellen.AI.Agents.AgentBehaviour
  def process(transcription, context) do
    run(transcription, context)
  end

  @impl Hellen.AI.Agents.AgentBehaviour
  def build_prompt(transcription, context) do
    subject = context[:subject] || "Não especificada"
    grade_level = context[:grade_level] || "Não especificado"

    """
    Você é um especialista em análise de aulas. Analise a transcrição abaixo e extraia informações estruturadas.

    ## Contexto
    - Disciplina: #{subject}
    - Nível: #{grade_level}

    ## Transcrição
    #{transcription}

    ## Sua Tarefa
    Analise a transcrição e retorne um JSON com:

    ```json
    {
      "resumo_executivo": "Resumo de 2-3 parágrafos da aula",
      "duracao_estimada_minutos": 45,
      "topicos_principais": [
        {
          "titulo": "Nome do tópico",
          "descricao": "Breve descrição",
          "tempo_estimado_percent": 30
        }
      ],
      "momentos_chave": [
        {
          "tipo": "abertura | desenvolvimento | fechamento | interacao | momento_critico",
          "descricao": "O que aconteceu",
          "relevancia": "alta | media | baixa"
        }
      ],
      "estrutura_aula": {
        "tem_abertura": true,
        "tem_desenvolvimento": true,
        "tem_fechamento": true,
        "transicoes_claras": true
      },
      "vocabulario_tecnico": ["termo1", "termo2"],
      "perguntas_feitas": [
        {
          "pergunta": "Texto da pergunta",
          "tipo": "aberta | fechada | retorica",
          "respondida": true
        }
      ],
      "estatisticas": {
        "total_palavras": 5000,
        "palavras_professor": 4000,
        "palavras_alunos": 1000,
        "ratio_professor_aluno": 4.0
      }
    }
    ```

    Retorne APENAS o JSON, sem explicações adicionais.
    """
  end
end
