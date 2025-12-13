defmodule Hellen.AI.ContextDetector do
  @moduledoc """
  Detects lesson context and identifies contradictions between
  what is being taught and how it's being taught.

  Critical for identifying hypocrisy scenarios like:
  - Teaching about bullying while using sarcasm
  - Teaching about respect while publicly shaming students
  - Teaching digital citizenship while ignoring disengaged students

  These contradictions result in severe score penalties as they
  undermine the pedagogical value of the lesson.
  """

  alias Hellen.AI.BehaviorDetector

  @type lesson_topic :: :bullying | :cyberbullying | :respect | :inclusion | :citizenship | :other
  @type contradiction :: %{
          topic: lesson_topic(),
          behavior: atom(),
          severity: :critical | :high | :medium,
          description: String.t(),
          score_penalty: integer()
        }

  @type context_report :: %{
          detected_topics: [lesson_topic()],
          contradictions: [contradiction()],
          hypocrisy_score: integer(),
          teaching_about_bullying: boolean(),
          practicing_bullying: boolean(),
          recommendation: String.t()
        }

  # Topic detection patterns
  @topic_patterns %{
    bullying: [
      ~r/bullying/iu,
      ~r/intimidação\s+sistemática/iu,
      ~r/lei\s+13\.?185/iu,
      ~r/agress(ão|or|ões)/iu
    ],
    cyberbullying: [
      ~r/cyberbullying/iu,
      ~r/bullying\s+(virtual|online|digital)/iu,
      ~r/hate\s*(speech)?/iu,
      ~r/mensagens?\s+ofensivas?/iu
    ],
    respect: [
      ~r/respeito/iu,
      ~r/empatia/iu,
      ~r/tolerância/iu,
      ~r/convivência/iu
    ],
    inclusion: [
      ~r/inclusão/iu,
      ~r/diversidade/iu,
      ~r/acessibilidade/iu,
      ~r/necessidades?\s+especiais?/iu
    ],
    citizenship: [
      ~r/cidadania/iu,
      ~r/direitos?\s+(e\s+)?deveres?/iu,
      ~r/ética/iu,
      ~r/responsabilidade\s+social/iu
    ]
  }

  # Behavior-topic contradiction mappings
  @contradictions %{
    bullying: [:sarcasm, :public_shame, :exclusion, :aggression],
    cyberbullying: [:sarcasm, :public_shame, :exclusion, :aggression],
    respect: [:sarcasm, :public_shame, :aggression],
    inclusion: [:exclusion, :disengagement],
    citizenship: [:sarcasm, :public_shame, :exclusion]
  }

  # Contradiction severity multipliers (topic + behavior -> multiplier)
  @contradiction_multipliers %{
    {:bullying, :sarcasm} => 2.5,
    {:bullying, :public_shame} => 2.5,
    {:cyberbullying, :sarcasm} => 2.5,
    {:cyberbullying, :public_shame} => 2.5,
    {:respect, :aggression} => 2.0,
    {:respect, :sarcasm} => 2.0,
    {:inclusion, :exclusion} => 2.0
  }

  @doc """
  Analyzes transcription for context contradictions.

  Detects what topic is being taught and compares with detected behaviors
  to identify pedagogical hypocrisy.

  ## Examples

      iex> ContextDetector.analyze("Hoje vamos falar sobre bullying... Só isso? Você tem essa mania!")
      %{
        detected_topics: [:bullying],
        contradictions: [%{topic: :bullying, behavior: :sarcasm, severity: :critical, ...}],
        hypocrisy_score: 35,
        teaching_about_bullying: true,
        practicing_bullying: true,
        recommendation: "..."
      }
  """
  @spec analyze(String.t()) :: context_report()
  def analyze(transcription) when is_binary(transcription) do
    # 1. Detect lesson topics
    topics = detect_topics(transcription)

    # 2. Run behavior detection
    behavior_report = BehaviorDetector.analyze(transcription)

    # 3. Find contradictions
    contradictions = find_contradictions(topics, behavior_report)

    # 4. Calculate hypocrisy score
    hypocrisy_score = calculate_hypocrisy_score(contradictions)

    # 5. Build detailed report
    teaching_bullying = :bullying in topics or :cyberbullying in topics

    practicing_bullying =
      behavior_report.sarcasm.detected or
        behavior_report.public_shame.detected or
        behavior_report.exclusion.detected or
        behavior_report.aggression.detected

    %{
      detected_topics: topics,
      contradictions: contradictions,
      hypocrisy_score: hypocrisy_score,
      teaching_about_bullying: teaching_bullying,
      practicing_bullying: practicing_bullying,
      behavior_safety_score: behavior_report.safety_score,
      recommendation: build_recommendation(contradictions, teaching_bullying, practicing_bullying)
    }
  end

  @doc """
  Detects lesson topics from transcription.
  """
  @spec detect_topics(String.t()) :: [lesson_topic()]
  def detect_topics(transcription) do
    @topic_patterns
    |> Enum.filter(fn {_topic, patterns} ->
      Enum.any?(patterns, &Regex.match?(&1, transcription))
    end)
    |> Enum.map(fn {topic, _} -> topic end)
  end

  @doc """
  Checks if a specific topic is being discussed.
  """
  @spec topic_detected?(String.t(), lesson_topic()) :: boolean()
  def topic_detected?(transcription, topic) do
    patterns = Map.get(@topic_patterns, topic, [])
    Enum.any?(patterns, &Regex.match?(&1, transcription))
  end

  @doc """
  Returns the contradiction severity multiplier.

  Teaching about a topic while violating it is worse than
  just violating it in a random lesson.
  """
  @spec contradiction_multiplier(lesson_topic(), atom()) :: float()
  def contradiction_multiplier(topic, behavior) do
    contradicting_behaviors = Map.get(@contradictions, topic, [])

    if behavior in contradicting_behaviors do
      Map.get(@contradiction_multipliers, {topic, behavior}, 1.5)
    else
      1.0
    end
  end

  # Private functions

  defp find_contradictions([], _behavior_report), do: []

  defp find_contradictions(topics, behavior_report) do
    detected_behaviors = extract_detected_behaviors(behavior_report)

    topics
    |> Enum.flat_map(fn topic ->
      contradicting = Map.get(@contradictions, topic, [])

      detected_behaviors
      |> Enum.filter(fn {behavior, _data} -> behavior in contradicting end)
      |> Enum.map(fn {behavior, data} ->
        build_contradiction(topic, behavior, data)
      end)
    end)
    |> Enum.sort_by(& &1.score_penalty, :desc)
  end

  defp extract_detected_behaviors(report) do
    [
      {:sarcasm, report.sarcasm},
      {:disengagement, report.disengagement},
      {:public_shame, report.public_shame},
      {:exclusion, report.exclusion},
      {:aggression, report.aggression}
    ]
    |> Enum.filter(fn {_name, data} -> data.detected end)
  end

  defp build_contradiction(topic, behavior, behavior_data) do
    severity = calculate_contradiction_severity(topic, behavior, behavior_data.severity)
    penalty = calculate_contradiction_penalty(topic, behavior, behavior_data)

    %{
      topic: topic,
      behavior: behavior,
      behavior_severity: behavior_data.severity,
      severity: severity,
      evidence: Enum.take(behavior_data.evidence, 2),
      description: describe_contradiction(topic, behavior),
      score_penalty: penalty
    }
  end

  defp calculate_contradiction_severity(topic, behavior, behavior_severity) do
    multiplier = contradiction_multiplier(topic, behavior)

    cond do
      multiplier >= 2.0 and behavior_severity in [:critical, :high] -> :critical
      multiplier >= 1.5 and behavior_severity == :critical -> :critical
      multiplier >= 1.5 -> :high
      true -> :medium
    end
  end

  defp calculate_contradiction_penalty(topic, behavior, behavior_data) do
    base_penalty = abs(behavior_data.score_impact)
    multiplier = contradiction_multiplier(topic, behavior)
    round(base_penalty * multiplier)
  end

  defp describe_contradiction(topic, behavior) do
    descriptions = %{
      {:bullying, :sarcasm} =>
        "Ensinar sobre bullying enquanto usa sarcasmo é contraditório e prejudica a mensagem",
      {:bullying, :public_shame} =>
        "Expor aluno publicamente durante aula sobre bullying demonstra o problema que deveria ser combatido",
      {:bullying, :exclusion} =>
        "Excluir alunos durante aula anti-bullying contradiz completamente o objetivo",
      {:bullying, :aggression} =>
        "Usar linguagem agressiva ao ensinar sobre bullying é pedagogicamente inaceitável",
      {:cyberbullying, :sarcasm} =>
        "Sarcasmo em aula sobre cyberbullying demonstra comportamento inadequado",
      {:cyberbullying, :public_shame} =>
        "Exposição pública em aula sobre cyberbullying contradiz a mensagem",
      {:respect, :sarcasm} => "Usar sarcasmo enquanto ensina sobre respeito é contraditório",
      {:respect, :public_shame} =>
        "Expor alunos publicamente em aula sobre respeito demonstra falta de respeito",
      {:respect, :aggression} => "Agressão verbal em aula sobre respeito é inaceitável",
      {:inclusion, :exclusion} =>
        "Excluir alunos em aula sobre inclusão contradiz completamente o tema",
      {:inclusion, :disengagement} =>
        "Ignorar alunos desengajados em aula sobre inclusão demonstra falta de prática",
      {:citizenship, :sarcasm} =>
        "Sarcasmo em aula sobre cidadania prejudica a formação de valores",
      {:citizenship, :public_shame} =>
        "Exposição pública em aula sobre cidadania contradiz os valores ensinados",
      {:citizenship, :exclusion} =>
        "Excluir alunos em aula sobre cidadania contradiz os princípios democráticos"
    }

    Map.get(
      descriptions,
      {topic, behavior},
      "Comportamento inadequado detectado durante aula sobre #{topic}"
    )
  end

  defp calculate_hypocrisy_score(contradictions) do
    base_score = 100

    total_penalty =
      contradictions
      |> Enum.map(& &1.score_penalty)
      |> Enum.sum()

    max(0, base_score - total_penalty)
  end

  defp build_recommendation([], _teaching_bullying, _practicing_bullying) do
    "Nenhuma contradição pedagógica detectada. Aula alinhada com o tema proposto."
  end

  defp build_recommendation(_contradictions, true, true) do
    """
    ALERTA CRÍTICO: Detectada contradição grave entre tema e prática.
    A aula aborda bullying/respeito, mas comportamentos inadequados foram identificados.
    Esta contradição pode anular o impacto pedagógico e até reforçar comportamentos negativos.
    AÇÃO IMEDIATA: Revisar postura e linguagem antes de abordar este tema novamente.
    """
  end

  defp build_recommendation(contradictions, _teaching_bullying, _practicing_bullying) do
    severity_count =
      contradictions
      |> Enum.map(& &1.severity)
      |> Enum.frequencies()

    critical = Map.get(severity_count, :critical, 0)
    high = Map.get(severity_count, :high, 0)

    cond do
      critical >= 2 ->
        "Múltiplas contradições críticas detectadas. Necessária revisão urgente da abordagem pedagógica."

      critical >= 1 ->
        "Contradição crítica detectada. Alinhar comportamento com o tema ensinado."

      high >= 2 ->
        "Várias contradições relevantes. Revisar comunicação e postura durante a aula."

      true ->
        "Contradições detectadas. Considerar ajustes na abordagem para maior coerência."
    end
  end
end
