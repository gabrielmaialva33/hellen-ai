defmodule Hellen.AI.ProcessingStatus do
  @moduledoc """
  Tracks and broadcasts real-time processing status for AI operations.

  This module provides:
  - Step-by-step tracking of analysis pipeline
  - Model usage information for UI display
  - Progress broadcasting via PubSub
  - Timing and cost estimation

  ## Usage

      # Start tracking a lesson analysis
      ProcessingStatus.start(lesson_id)

      # Update with each step
      ProcessingStatus.update(lesson_id, :transcription, %{
        model: "nvidia/parakeet-1.1b-rnnt-multilingual-asr",
        status: :running,
        message: "Transcrevendo áudio..."
      })

      # Complete a step
      ProcessingStatus.complete(lesson_id, :transcription, %{
        duration_ms: 5000,
        tokens_used: 0
      })

  ## Events

  All events are broadcast to `lesson:\#{lesson_id}` topic.
  """

  alias Hellen.AI.ModelRegistry
  require Logger

  @pubsub Hellen.PubSub

  # Processing steps in order
  @steps [
    :upload,
    :transcription,
    :quick_check,
    :legal_compliance,
    :socioemotional,
    :core_analysis,
    :behavior_detection,
    :validation,
    :scoring,
    :saving
  ]

  @step_descriptions %{
    upload: %{
      pt: "Upload do arquivo",
      en: "File upload",
      icon: "upload"
    },
    transcription: %{
      pt: "Transcrevendo áudio",
      en: "Transcribing audio",
      icon: "microphone"
    },
    quick_check: %{
      pt: "Verificação rápida",
      en: "Quick check",
      icon: "bolt"
    },
    legal_compliance: %{
      pt: "Análise de conformidade legal",
      en: "Legal compliance analysis",
      icon: "scale"
    },
    socioemotional: %{
      pt: "Análise socioemocional",
      en: "Socioemotional analysis",
      icon: "heart"
    },
    core_analysis: %{
      pt: "Análise pedagógica principal",
      en: "Core pedagogical analysis",
      icon: "academic-cap"
    },
    behavior_detection: %{
      pt: "Detecção de comportamentos",
      en: "Behavior detection",
      icon: "eye"
    },
    validation: %{
      pt: "Validação de resultados",
      en: "Results validation",
      icon: "check-circle"
    },
    scoring: %{
      pt: "Calculando pontuação",
      en: "Calculating score",
      icon: "calculator"
    },
    saving: %{
      pt: "Salvando análise",
      en: "Saving analysis",
      icon: "document-check"
    }
  }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Starts tracking processing for a lesson.
  Broadcasts initial state to subscribers.
  """
  @spec start(binary()) :: :ok
  def start(lesson_id) do
    status = %{
      lesson_id: lesson_id,
      started_at: DateTime.utc_now(),
      current_step: nil,
      steps: initialize_steps(),
      models_used: [],
      total_tokens: 0,
      estimated_cost: 0.0
    }

    broadcast(lesson_id, "processing_started", status)
    Logger.info("[ProcessingStatus] Started tracking for lesson #{lesson_id}")
    :ok
  end

  @doc """
  Updates the status of a processing step.
  """
  @spec update(binary(), atom(), map()) :: :ok
  def update(lesson_id, step, params) do
    model_id = params[:model]
    model_info = if model_id, do: ModelRegistry.model_for_display(model_id), else: nil

    step_info = Map.get(@step_descriptions, step, %{pt: to_string(step), en: to_string(step)})

    event = %{
      lesson_id: lesson_id,
      step: step,
      step_index: Enum.find_index(@steps, &(&1 == step)) || 0,
      total_steps: length(@steps),
      status: params[:status] || :running,
      message: params[:message] || step_info.pt,
      model: model_info,
      model_id: model_id,
      started_at: DateTime.utc_now(),
      progress_percent: calculate_progress(step)
    }

    broadcast(lesson_id, "processing_step_update", event)
    Logger.info("[ProcessingStatus] #{lesson_id} - #{step}: #{params[:status] || :running}")
    :ok
  end

  @doc """
  Marks a step as completed with results.
  """
  @spec complete(binary(), atom(), map()) :: :ok
  def complete(lesson_id, step, results \\ %{}) do
    step_info = Map.get(@step_descriptions, step, %{pt: to_string(step), en: to_string(step)})

    event = %{
      lesson_id: lesson_id,
      step: step,
      step_index: Enum.find_index(@steps, &(&1 == step)) || 0,
      status: :completed,
      message: "#{step_info.pt} - Concluído",
      duration_ms: results[:duration_ms] || 0,
      tokens_used: results[:tokens_used] || 0,
      model_id: results[:model_id],
      result_summary: results[:summary],
      progress_percent: calculate_progress(step) + step_progress_increment()
    }

    broadcast(lesson_id, "processing_step_complete", event)

    Logger.info(
      "[ProcessingStatus] #{lesson_id} - #{step}: completed in #{results[:duration_ms]}ms"
    )

    :ok
  end

  @doc """
  Marks a step as failed.
  """
  @spec fail(binary(), atom(), String.t()) :: :ok
  def fail(lesson_id, step, reason) do
    event = %{
      lesson_id: lesson_id,
      step: step,
      status: :failed,
      error: reason,
      failed_at: DateTime.utc_now()
    }

    broadcast(lesson_id, "processing_step_failed", event)
    Logger.error("[ProcessingStatus] #{lesson_id} - #{step}: failed - #{reason}")
    :ok
  end

  @doc """
  Marks the entire processing as complete.
  """
  @spec finish(binary(), map()) :: :ok
  def finish(lesson_id, summary \\ %{}) do
    event = %{
      lesson_id: lesson_id,
      status: :completed,
      finished_at: DateTime.utc_now(),
      total_duration_ms: summary[:total_duration_ms] || 0,
      total_tokens: summary[:total_tokens] || 0,
      estimated_cost: summary[:estimated_cost] || 0.0,
      models_used: summary[:models_used] || [],
      progress_percent: 100
    }

    broadcast(lesson_id, "processing_complete", event)
    Logger.info("[ProcessingStatus] #{lesson_id} - Processing complete")
    :ok
  end

  @doc """
  Returns step descriptions for UI.
  """
  @spec get_steps() :: [map()]
  def get_steps do
    Enum.map(@steps, fn step ->
      info = Map.get(@step_descriptions, step, %{})

      %{
        key: step,
        name_pt: info[:pt] || to_string(step),
        name_en: info[:en] || to_string(step),
        icon: info[:icon] || "cog"
      }
    end)
  end

  @doc """
  Returns a specific step's description.
  """
  @spec get_step_info(atom()) :: map()
  def get_step_info(step) do
    Map.get(@step_descriptions, step, %{pt: to_string(step), en: to_string(step), icon: "cog"})
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp initialize_steps do
    Enum.map(@steps, fn step ->
      info = Map.get(@step_descriptions, step, %{})

      %{
        key: step,
        status: :pending,
        name: info[:pt] || to_string(step),
        icon: info[:icon] || "cog"
      }
    end)
  end

  defp calculate_progress(step) do
    index = Enum.find_index(@steps, &(&1 == step)) || 0
    round(index / length(@steps) * 100)
  end

  defp step_progress_increment do
    round(100 / length(@steps))
  end

  defp broadcast(lesson_id, event, payload) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "lesson:#{lesson_id}",
      {event, payload}
    )
  end
end
