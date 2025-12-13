defmodule Hellen.AI.AgentOrchestrator do
  @moduledoc """
  Orquestrador principal de SubAgents para análise paralela.

  Coordena a execução de múltiplos agentes especializados em paralelo,
  maximizando performance e garantindo consistência.

  ## Pipeline de Execução

  ```
  Fase 1 - LEITURA (Paralelo, ~20s max)
  ├── TranscriptAgent (Llama 70B)
  ├── CharacterAgent (Qwen Thinking)
  └── PlanningAgent (Kimi K2)
           │
           ▼
  Fase 2 - ANÁLISE (Paralelo, ~30s max)
  ├── ComplianceAgent (DeepSeek R1)
  └── SocioEmotionalAgent (QwQ)
           │
           ▼
  Fase 3 - SCORING (Sequencial, ~15s)
  └── ScoringAgent (Llama 405B)
           │
           ▼
      RESULTADO FINAL
  ```

  Tempo total: ~65s (vs ~180s sequencial)
  """

  use GenServer
  require Logger

  alias Hellen.AI.Agents.{
    CharacterAgent,
    ComplianceAgent,
    PlanningAgent,
    ScoringAgent,
    SocioEmotionalAgent,
    TranscriptAgent
  }

  alias Hellen.AI.ProcessingStatus

  @timeout :infinity

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Executa análise completa com subagents em paralelo.

  ## Parâmetros
    - lesson_id: ID da aula para broadcast de status
    - transcription: Texto da transcrição
    - context: Map com contexto adicional
      - :subject - Disciplina
      - :grade_level - Nível/série
      - :planned_content - Conteúdo planejado (opcional)

  ## Retorno
    {:ok, result} ou {:error, reason}
  """
  @spec analyze(binary(), String.t(), map()) :: {:ok, map()} | {:error, any()}
  def analyze(lesson_id, transcription, context \\ %{}) do
    context = Map.put(context, :lesson_id, lesson_id)
    start_time = System.monotonic_time(:millisecond)

    Logger.info("[AgentOrchestrator] Starting parallel analysis for lesson #{lesson_id}")
    ProcessingStatus.start(lesson_id)

    try do
      # Fase 1: Leitura em Paralelo
      reading_results = run_reading_phase(transcription, context)

      case reading_results do
        {:ok, reading_data} ->
          # Fase 2: Análise em Paralelo
          analysis_context = Map.merge(context, reading_data)
          analysis_results = run_analysis_phase(transcription, analysis_context)

          case analysis_results do
            {:ok, analysis_data} ->
              # Fase 3: Scoring Final
              all_results = Map.merge(reading_data, analysis_data)
              scoring_result = run_scoring_phase(all_results, context)

              case scoring_result do
                {:ok, final_result} ->
                  total_time = System.monotonic_time(:millisecond) - start_time
                  Logger.info("[AgentOrchestrator] Analysis complete in #{total_time}ms")

                  ProcessingStatus.finish(lesson_id, %{
                    total_duration_ms: total_time,
                    models_used: get_models_used()
                  })

                  {:ok,
                   %{
                     transcript: reading_data.transcript,
                     characters: reading_data.characters,
                     planning: reading_data.planning,
                     compliance: analysis_data.compliance,
                     socioemotional: analysis_data.socioemotional,
                     scoring: final_result,
                     metadata: %{
                       total_duration_ms: total_time,
                       models_used: get_models_used(),
                       phases: %{
                         reading: reading_data[:_phase_duration_ms],
                         analysis: analysis_data[:_phase_duration_ms],
                         scoring: final_result[:processing_time_ms]
                       }
                     }
                   }}

                {:error, reason} ->
                  ProcessingStatus.fail(lesson_id, :scoring, inspect(reason))
                  {:error, {:scoring_failed, reason}}
              end

            {:error, reason} ->
              {:error, {:analysis_failed, reason}}
          end

        {:error, reason} ->
          {:error, {:reading_failed, reason}}
      end
    rescue
      e ->
        Logger.error("[AgentOrchestrator] Error: #{inspect(e)}")
        ProcessingStatus.fail(lesson_id, :core_analysis, inspect(e))
        {:error, {:orchestration_error, e}}
    end
  end

  @doc """
  Executa análise rápida apenas com agentes essenciais.
  Útil para preview ou quando velocidade é crítica.
  """
  @spec quick_analyze(binary(), String.t(), map()) :: {:ok, map()} | {:error, any()}
  def quick_analyze(lesson_id, transcription, context \\ %{}) do
    context = Map.put(context, :lesson_id, lesson_id)
    start_time = System.monotonic_time(:millisecond)

    Logger.info("[AgentOrchestrator] Starting quick analysis for lesson #{lesson_id}")

    tasks = [
      Task.async(fn -> TranscriptAgent.run(transcription, context) end),
      Task.async(fn -> CharacterAgent.run(transcription, context) end)
    ]

    results = Task.await_many(tasks, @timeout)

    total_time = System.monotonic_time(:millisecond) - start_time

    case results do
      [{:ok, transcript}, {:ok, characters}] ->
        {:ok,
         %{
           transcript: transcript,
           characters: characters,
           quick_mode: true,
           total_duration_ms: total_time
         }}

      _ ->
        {:error, :quick_analysis_failed}
    end
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(opts) do
    {:ok, %{opts: opts}}
  end

  @impl GenServer
  def handle_call({:analyze, lesson_id, transcription, context}, _from, state) do
    result = analyze(lesson_id, transcription, context)
    {:reply, result, state}
  end

  # ============================================================================
  # Private Functions - Phase Execution
  # ============================================================================

  defp run_reading_phase(transcription, context) do
    start_time = System.monotonic_time(:millisecond)
    lesson_id = context[:lesson_id]

    Logger.info("[AgentOrchestrator] Phase 1: Reading (parallel)")

    if lesson_id do
      ProcessingStatus.update(lesson_id, :core_analysis, %{
        status: :running,
        message: "Fase 1: Leitura paralela"
      })
    end

    tasks = [
      Task.async(fn ->
        Logger.info("[AgentOrchestrator] Starting TranscriptAgent")
        TranscriptAgent.run(transcription, context)
      end),
      Task.async(fn ->
        Logger.info("[AgentOrchestrator] Starting CharacterAgent")
        CharacterAgent.run(transcription, context)
      end),
      Task.async(fn ->
        Logger.info("[AgentOrchestrator] Starting PlanningAgent")
        PlanningAgent.run(transcription, context)
      end)
    ]

    results = Task.await_many(tasks, @timeout)
    duration = System.monotonic_time(:millisecond) - start_time

    Logger.info("[AgentOrchestrator] Reading phase completed in #{duration}ms")

    case results do
      [{:ok, transcript}, {:ok, characters}, {:ok, planning}] ->
        {:ok,
         %{
           transcript: transcript,
           characters: characters,
           planning: planning,
           _phase_duration_ms: duration
         }}

      results ->
        log_failures(results, [:transcript, :characters, :planning])
        {:error, {:reading_phase_failed, results}}
    end
  end

  defp run_analysis_phase(transcription, context) do
    start_time = System.monotonic_time(:millisecond)
    lesson_id = context[:lesson_id]

    Logger.info("[AgentOrchestrator] Phase 2: Analysis (parallel)")

    if lesson_id do
      ProcessingStatus.update(lesson_id, :behavior_detection, %{
        status: :running,
        message: "Fase 2: Análise profunda"
      })
    end

    tasks = [
      Task.async(fn ->
        Logger.info("[AgentOrchestrator] Starting ComplianceAgent")
        ComplianceAgent.run(transcription, context)
      end),
      Task.async(fn ->
        Logger.info("[AgentOrchestrator] Starting SocioEmotionalAgent")
        SocioEmotionalAgent.run(transcription, context)
      end)
    ]

    results = Task.await_many(tasks, @timeout)
    duration = System.monotonic_time(:millisecond) - start_time

    Logger.info("[AgentOrchestrator] Analysis phase completed in #{duration}ms")

    case results do
      [{:ok, compliance}, {:ok, socioemotional}] ->
        {:ok,
         %{
           compliance: compliance,
           socioemotional: socioemotional,
           _phase_duration_ms: duration
         }}

      results ->
        log_failures(results, [:compliance, :socioemotional])
        {:error, {:analysis_phase_failed, results}}
    end
  end

  defp run_scoring_phase(all_results, context) do
    lesson_id = context[:lesson_id]

    Logger.info("[AgentOrchestrator] Phase 3: Final Scoring")

    if lesson_id do
      ProcessingStatus.update(lesson_id, :scoring, %{
        status: :running,
        message: "Fase 3: Pontuação final"
      })
    end

    aggregated = %{
      transcript: all_results[:transcript][:result] || %{},
      characters: all_results[:characters][:result] || %{},
      planning: all_results[:planning][:result] || %{},
      compliance: all_results[:compliance][:result] || %{},
      socioemotional: all_results[:socioemotional][:result] || %{}
    }

    ScoringAgent.run(aggregated, context)
  end

  defp log_failures(results, agent_names) do
    results
    |> Enum.zip(agent_names)
    |> Enum.each(fn
      {{:error, reason}, agent} ->
        Logger.error("[AgentOrchestrator] #{agent} failed: #{inspect(reason)}")

      _ ->
        :ok
    end)
  end

  defp get_models_used do
    [
      %{agent: "TranscriptAgent", model: TranscriptAgent.model()},
      %{agent: "CharacterAgent", model: CharacterAgent.model()},
      %{agent: "PlanningAgent", model: PlanningAgent.model()},
      %{agent: "ComplianceAgent", model: ComplianceAgent.model()},
      %{agent: "SocioEmotionalAgent", model: SocioEmotionalAgent.model()},
      %{agent: "ScoringAgent", model: ScoringAgent.model()}
    ]
  end
end
