defmodule Hellen.AI.AgentSupervisor do
  @moduledoc """
  Supervisor para todos os SubAgents de análise.

  Gerencia o ciclo de vida dos agentes e do orquestrador,
  garantindo que sejam reiniciados em caso de falha.

  ## Arquitetura

  ```
  AgentSupervisor (one_for_one)
  ├── AgentOrchestrator
  ├── TranscriptAgent
  ├── CharacterAgent
  ├── PlanningAgent
  ├── ComplianceAgent
  ├── SocioEmotionalAgent
  └── ScoringAgent
  ```
  """

  use Supervisor

  alias Hellen.AI.AgentOrchestrator

  alias Hellen.AI.Agents.{
    CharacterAgent,
    ComplianceAgent,
    PlanningAgent,
    ScoringAgent,
    SocioEmotionalAgent,
    TranscriptAgent
  }

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      # Agentes individuais (opcionais para chamadas diretas)
      {TranscriptAgent, name: TranscriptAgent},
      {CharacterAgent, name: CharacterAgent},
      {PlanningAgent, name: PlanningAgent},
      {ComplianceAgent, name: ComplianceAgent},
      {SocioEmotionalAgent, name: SocioEmotionalAgent},
      {ScoringAgent, name: ScoringAgent},

      # Orquestrador principal
      AgentOrchestrator
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
