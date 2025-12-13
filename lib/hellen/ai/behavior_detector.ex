defmodule Hellen.AI.BehaviorDetector do
  @moduledoc """
  Detects problematic classroom behaviors with high precision.

  Analyzes transcriptions for:
  - Sarcasm patterns (teacher-to-student)
  - Student disengagement (sleeping, missing, silent)
  - Public shaming situations
  - Classroom safety indicators
  - Lei 13.185 potential violations

  Uses pattern-based detection with contextual analysis for
  more accurate scoring than pure LLM assessment.
  """

  @type detection_result :: %{
          detected: boolean(),
          severity: :critical | :high | :medium | :low | :none,
          evidence: [String.t()],
          score_impact: integer()
        }

  @type behavior_report :: %{
          sarcasm: detection_result(),
          disengagement: detection_result(),
          public_shame: detection_result(),
          exclusion: detection_result(),
          aggression: detection_result(),
          safety_score: integer(),
          lei_13185_risk: :critical | :high | :medium | :low | :none,
          summary: String.t()
        }

  # ============================================================================
  # Sarcasm Detection
  # ============================================================================

  @sarcasm_patterns [
    # Question forms with dismissive intent
    {~r/Só\s+(\w+)\s*\?/iu, :high, "Só X?"},
    {~r/E\s+só\s+isso\s*\?/iu, :high, "E só isso?"},
    {~r/Você\s+acha\s+que\s+.*\s+né\s*\?/iu, :medium, "Você acha que... né?"},

    # Habitual criticism patterns
    {~r/Você\s+tem\s+(essa\s+)?mania/iu, :critical, "Você tem (essa) mania"},
    {~r/Você\s+sempre\s+faz\s+isso/iu, :high, "Você sempre faz isso"},
    {~r/Sempre\s+a\s+mesma\s+coisa/iu, :high, "Sempre a mesma coisa"},
    {~r/De\s+novo\s*\?/iu, :medium, "De novo?"},

    # Rhetorical dismissals
    {~r/Claro,?\s+né/iu, :medium, "Claro, né"},
    {~r/Óbvio,?\s+né/iu, :medium, "Óbvio, né"},
    {~r/Lógico,?\s+né/iu, :low, "Lógico, né"},
    {~r/Que\s+surpresa/iu, :high, "Que surpresa"},

    # Derogatory comparisons
    {~r/Nem\s+o\s+[A-Za-zÀ-ú]+\s+faz\s+isso/iu, :high, "Nem o X faz isso"},
    {~r/Até\s+(criança|bebê)\s+(sabe|consegue)/iu, :critical, "Até criança sabe/consegue"},
    {~r/Parece\s+que\s+é\s+difícil/iu, :medium, "Parece que é difícil"},

    # Exasperation markers
    {~r/Quantas\s+vezes\s+(eu\s+)?(já\s+)?disse/iu, :high, "Quantas vezes já disse"},
    {~r/Eu\s+não\s+acredito/iu, :medium, "Eu não acredito"},
    {~r/Não\s+é\s+possível/iu, :medium, "Não é possível"},

    # Mocking emphasis
    {~r/Ah,?\s+tá\s+bom/iu, :medium, "Ah, tá bom"},
    {~r/Muito\s+bem,?\s+hein/iu, :medium, "Muito bem, hein"},
    {~r/Parabéns,?\s+hein/iu, :medium, "Parabéns, hein"}
  ]

  @doc """
  Detects sarcasm patterns in the transcription.

  Returns detection result with severity and evidence.

  ## Examples

      iex> BehaviorDetector.detect_sarcasm("Só sim? Você tem essa mania mesmo.")
      %{detected: true, severity: :critical, evidence: [...], score_impact: -25}
  """
  @spec detect_sarcasm(String.t()) :: detection_result()
  def detect_sarcasm(transcription) when is_binary(transcription) do
    matches = find_pattern_matches(transcription, @sarcasm_patterns)

    case matches do
      [] ->
        %{detected: false, severity: :none, evidence: [], score_impact: 0}

      matches ->
        severity = get_highest_severity(matches)
        impact = calculate_sarcasm_impact(matches)

        %{
          detected: true,
          severity: severity,
          evidence: Enum.map(matches, & &1.evidence),
          score_impact: impact
        }
    end
  end

  defp calculate_sarcasm_impact(matches) do
    base_impact =
      Enum.reduce(matches, 0, fn match, acc ->
        case match.severity do
          :critical -> acc - 15
          :high -> acc - 10
          :medium -> acc - 5
          :low -> acc - 2
          _ -> acc
        end
      end)

    # Cap at -30
    max(-30, base_impact)
  end

  # ============================================================================
  # Disengagement Detection
  # ============================================================================

  @disengagement_patterns [
    # Sleeping
    {~r/[A-Za-zÀ-ú]+\s+(dormiu|está\s+dormindo|dorme\s+de\s+novo)/iu, :critical,
     "Aluno dormindo"},
    {~r/(acorda|acordar)\s+[A-Za-zÀ-ú]+/iu, :critical, "Professor acordando aluno"},
    {~r/Olha\s+lá,?\s+[A-Za-zÀ-ú]+\s+dormindo/iu, :critical, "Comentário sobre aluno dormindo"},

    # Missing/absent
    {~r/(cadê|onde\s+está|não\s+sei\s+onde)\s+(o|a)?\s*[A-Za-zÀ-ú]+/iu, :high,
     "Aluno ausente/desaparecido"},
    {~r/[A-Za-zÀ-ú]+\s+sumiu/iu, :high, "Aluno sumiu"},
    {~r/(saiu|foi\s+embora)\s+sem\s+(pedir|avisar)/iu, :high, "Saiu sem permissão"},

    # Silence/non-participation
    {~r/ninguém\s+(responde|fala|quer)/iu, :medium, "Silêncio geral"},
    {~r/silêncio\s+total/iu, :medium, "Silêncio total"},
    {~r/[A-Za-zÀ-ú]+\s+não\s+quer\s+(participar|fazer|falar)/iu, :medium, "Recusa em participar"},

    # Explicit resistance
    {~r/(não\s+quero|eu\s+não\s+vou|não\s+quero\s+mais)/iu, :high, "Recusa explícita"},
    {~r/que\s+saco|que\s+chato/iu, :medium, "Expressão de tédio"},
    {~r/cansei\s+disso/iu, :medium, "Cansaço expresso"},

    # Distraction
    {~r/(mexendo|brincando)\s+(no|com)\s+(celular|telefone)/iu, :medium, "Distração com celular"},
    {~r/para\s+de\s+mexer\s+(no|com)/iu, :medium, "Mexendo no celular"},
    {~r/para\s+de\s+(conversar|falar)/iu, :low, "Conversa paralela"},
    {~r/presta\s+atenção/iu, :low, "Chamada de atenção"}
  ]

  @doc """
  Detects student disengagement patterns.

  Identifies sleeping, absence, silence, and explicit resistance.

  ## Examples

      iex> BehaviorDetector.detect_disengagement("Ivã dormiu de novo, acorda ele.")
      %{detected: true, severity: :critical, evidence: [...], score_impact: -20}
  """
  @spec detect_disengagement(String.t()) :: detection_result()
  def detect_disengagement(transcription) when is_binary(transcription) do
    matches = find_pattern_matches(transcription, @disengagement_patterns)

    case matches do
      [] ->
        %{detected: false, severity: :none, evidence: [], score_impact: 0}

      matches ->
        severity = get_highest_severity(matches)
        impact = calculate_disengagement_impact(matches)

        %{
          detected: true,
          severity: severity,
          evidence: Enum.map(matches, & &1.evidence),
          score_impact: impact
        }
    end
  end

  defp calculate_disengagement_impact(matches) do
    base_impact =
      Enum.reduce(matches, 0, fn match, acc ->
        case match.severity do
          :critical -> acc - 12
          :high -> acc - 8
          :medium -> acc - 4
          :low -> acc - 2
          _ -> acc
        end
      end)

    max(-25, base_impact)
  end

  # ============================================================================
  # Public Shaming Detection
  # ============================================================================

  @public_shame_patterns [
    # Public criticism
    {~r/(olha|veja)\s+o\s+que\s+[A-Za-zÀ-ú]+\s+fez/iu, :critical, "Exposição pública de erro"},
    {~r/todo\s+mundo\s+(sabe|viu|ouviu)/iu, :high, "Generalização pública"},
    {~r/na\s+frente\s+de\s+todo\s+mundo/iu, :critical, "Exposição na frente de todos"},

    # Physical/appearance comments
    {~r/(perfume|cheiro|cheirou|fedeu)/iu, :critical, "Comentário sobre odor corporal"},
    {~r/(gordo|magro|feio|bonito)\s+assim/iu, :critical, "Comentário sobre aparência"},
    {~r/olha\s+(a|o)\s+(roupa|cabelo|cara)/iu, :high, "Comentário sobre aparência"},

    # Academic shaming
    {~r/(errou|errado)\s+de\s+novo/iu, :high, "Destaque repetido de erro"},
    {~r/todo\s+mundo\s+acertou\s+menos/iu, :critical, "Comparação negativa pública"},
    {~r/só\s+você\s+(não|errou)/iu, :critical, "Isolamento por desempenho"},

    # Name and shame
    {~r/[A-Za-zÀ-ú]+,?\s+levanta\s+(a\s+mão|aí)/iu, :medium, "Chamada pública de atenção"},
    {~r/classe,?\s+(olha|veja)\s+o\s+[A-Za-zÀ-ú]+/iu, :critical, "Exposição para a classe"},

    # Laughter at student expense
    {~r/\(risos\)/iu, :medium, "Risos (verificar contexto)"},
    {~r/pode\s+rir/iu, :critical, "Permissão para rir de alguém"},
    {~r/engraçado,?\s+né/iu, :medium, "Sarcasmo sobre situação"}
  ]

  @doc """
  Detects public shaming situations.

  Identifies moments where students are exposed negatively to peers.

  ## Examples

      iex> BehaviorDetector.detect_public_shame("Perfume, você me cheirou assim")
      %{detected: true, severity: :critical, evidence: [...], score_impact: -20}
  """
  @spec detect_public_shame(String.t()) :: detection_result()
  def detect_public_shame(transcription) when is_binary(transcription) do
    matches = find_pattern_matches(transcription, @public_shame_patterns)

    case matches do
      [] ->
        %{detected: false, severity: :none, evidence: [], score_impact: 0}

      matches ->
        severity = get_highest_severity(matches)
        impact = calculate_shame_impact(matches)

        %{
          detected: true,
          severity: severity,
          evidence: Enum.map(matches, & &1.evidence),
          score_impact: impact
        }
    end
  end

  defp calculate_shame_impact(matches) do
    base_impact =
      Enum.reduce(matches, 0, fn match, acc ->
        case match.severity do
          :critical -> acc - 15
          :high -> acc - 10
          :medium -> acc - 5
          :low -> acc - 2
          _ -> acc
        end
      end)

    max(-30, base_impact)
  end

  # ============================================================================
  # Exclusion Detection (Lei 13.185 - Type VII)
  # ============================================================================

  @exclusion_patterns [
    # Social exclusion
    {~r/(você\s+)?não\s+pode\s+(participar|entrar|fazer\s+parte)/iu, :critical,
     "Exclusão de atividade"},
    {~r/sai\s+(daqui|do\s+grupo)/iu, :critical, "Expulsão de grupo"},
    {~r/ninguém\s+quer\s+(você|ela|ele)/iu, :critical, "Rejeição social"},

    # Isolation
    {~r/(fica|senta)\s+(aí\s+)?sozinho/iu, :high, "Isolamento forçado"},
    {~r/vai\s+pro\s+canto/iu, :high, "Isolamento espacial"},
    {~r/não\s+(fala|conversa)\s+com/iu, :high, "Proibição de interação"},

    # Group dynamics
    {~r/não\s+é\s+do\s+(grupo|time|nossa\s+turma)/iu, :high, "Exclusão de grupo"},
    {~r/(ela|ele)\s+não\s+(vai|entra)/iu, :medium, "Veto de participação"}
  ]

  @doc """
  Detects exclusion patterns (Lei 13.185 - Type VII: Social Bullying).
  """
  @spec detect_exclusion(String.t()) :: detection_result()
  def detect_exclusion(transcription) when is_binary(transcription) do
    matches = find_pattern_matches(transcription, @exclusion_patterns)

    case matches do
      [] ->
        %{detected: false, severity: :none, evidence: [], score_impact: 0}

      matches ->
        severity = get_highest_severity(matches)
        impact = calculate_exclusion_impact(matches)

        %{
          detected: true,
          severity: severity,
          evidence: Enum.map(matches, & &1.evidence),
          score_impact: impact
        }
    end
  end

  defp calculate_exclusion_impact(matches) do
    base_impact =
      Enum.reduce(matches, 0, fn match, acc ->
        case match.severity do
          :critical -> acc - 15
          :high -> acc - 10
          :medium -> acc - 5
          _ -> acc
        end
      end)

    max(-25, base_impact)
  end

  # ============================================================================
  # Verbal Aggression Detection (Lei 13.185 - Type IV)
  # ============================================================================

  @aggression_patterns [
    # Direct insults
    {~r/(burro|idiota|imbecil|estúpido)/iu, :critical, "Insulto direto"},
    {~r/(cala\s+a\s+boca|fecha\s+a\s+boca)/iu, :high, "Comando agressivo"},
    {~r/(inútil|incapaz|incompetente)/iu, :critical, "Insulto à capacidade"},

    # Threats
    {~r/(vou\s+te|vai\s+ver|você\s+vai)\s+(tirar|expulsar|mandar)/iu, :critical, "Ameaça"},
    {~r/se\s+não\s+(parar|calar)/iu, :high, "Ameaça condicional"},

    # Yelling indicators
    {~r/[A-Z]{3,}(!)+/u, :medium, "Texto em caps (grito)"},
    {~r/para\s+de\s+gritar/iu, :medium, "Referência a grito"},

    # Derogatory nicknames
    {~r/seu\s+(idiota|burro|inútil)/iu, :critical, "Xingamento direto"},
    {~r/(apelido|chama\s+de)\s+[A-Za-zÀ-ú]+/iu, :medium, "Apelido (verificar contexto)"}
  ]

  @doc """
  Detects verbal aggression (Lei 13.185 - Type IV: Verbal Bullying).
  """
  @spec detect_aggression(String.t()) :: detection_result()
  def detect_aggression(transcription) when is_binary(transcription) do
    matches = find_pattern_matches(transcription, @aggression_patterns)

    case matches do
      [] ->
        %{detected: false, severity: :none, evidence: [], score_impact: 0}

      matches ->
        severity = get_highest_severity(matches)
        impact = calculate_aggression_impact(matches)

        %{
          detected: true,
          severity: severity,
          evidence: Enum.map(matches, & &1.evidence),
          score_impact: impact
        }
    end
  end

  defp calculate_aggression_impact(matches) do
    base_impact =
      Enum.reduce(matches, 0, fn match, acc ->
        case match.severity do
          :critical -> acc - 20
          :high -> acc - 12
          :medium -> acc - 6
          _ -> acc
        end
      end)

    max(-35, base_impact)
  end

  # ============================================================================
  # Full Analysis
  # ============================================================================

  @doc """
  Performs complete behavior analysis of transcription.

  Returns comprehensive report with all detection categories,
  safety score, and Lei 13.185 risk assessment.

  ## Examples

      iex> BehaviorDetector.analyze("Ivã dormiu de novo. Só isso? Você tem essa mania.")
      %{
        sarcasm: %{detected: true, ...},
        disengagement: %{detected: true, ...},
        public_shame: %{detected: false, ...},
        exclusion: %{detected: false, ...},
        aggression: %{detected: false, ...},
        safety_score: 45,
        lei_13185_risk: :high,
        summary: "Detected: sarcasm (critical), disengagement (critical)"
      }
  """
  @spec analyze(String.t()) :: behavior_report()
  def analyze(transcription) when is_binary(transcription) do
    sarcasm = detect_sarcasm(transcription)
    disengagement = detect_disengagement(transcription)
    public_shame = detect_public_shame(transcription)
    exclusion = detect_exclusion(transcription)
    aggression = detect_aggression(transcription)

    detections = %{
      sarcasm: sarcasm,
      disengagement: disengagement,
      public_shame: public_shame,
      exclusion: exclusion,
      aggression: aggression
    }

    safety_score = calculate_safety_score(detections)
    risk = calculate_lei_13185_risk(detections)
    summary = build_summary(detections)

    Map.merge(detections, %{
      safety_score: safety_score,
      lei_13185_risk: risk,
      summary: summary
    })
  end

  @doc """
  Calculates classroom psychological safety score (0-100).

  Score starts at 100 and is reduced based on detected behaviors.
  """
  @spec calculate_safety_score(map()) :: integer()
  def calculate_safety_score(detections) do
    base_score = 100

    total_impact =
      detections
      |> Map.values()
      |> Enum.filter(&is_map/1)
      |> Enum.map(&Map.get(&1, :score_impact, 0))
      |> Enum.sum()

    max(0, min(100, base_score + total_impact))
  end

  @doc """
  Calculates Lei 13.185 legal risk level.
  """
  @spec calculate_lei_13185_risk(map()) :: :critical | :high | :medium | :low | :none
  def calculate_lei_13185_risk(detections) do
    severities =
      detections
      |> Map.values()
      |> Enum.filter(&is_map/1)
      |> Enum.map(&Map.get(&1, :severity, :none))

    critical_count = Enum.count(severities, &(&1 == :critical))
    high_count = Enum.count(severities, &(&1 == :high))

    cond do
      critical_count >= 2 -> :critical
      critical_count >= 1 and high_count >= 1 -> :critical
      critical_count >= 1 -> :high
      high_count >= 2 -> :high
      high_count >= 1 -> :medium
      Enum.any?(severities, &(&1 == :medium)) -> :low
      true -> :none
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp find_pattern_matches(text, patterns) do
    patterns
    |> Enum.flat_map(fn {regex, severity, description} ->
      case Regex.run(regex, text, return: :index) do
        nil ->
          []

        [{start, length} | _] ->
          evidence = String.slice(text, max(0, start - 20), length + 40)

          [
            %{
              pattern: description,
              severity: severity,
              evidence: "...#{String.trim(evidence)}..."
            }
          ]
      end
    end)
    |> Enum.uniq_by(& &1.pattern)
  end

  defp get_highest_severity(matches) do
    severities = Enum.map(matches, & &1.severity)

    cond do
      :critical in severities -> :critical
      :high in severities -> :high
      :medium in severities -> :medium
      :low in severities -> :low
      true -> :none
    end
  end

  defp build_summary(detections) do
    detected =
      detections
      |> Enum.filter(fn {_key, value} ->
        is_map(value) and Map.get(value, :detected, false)
      end)
      |> Enum.map(fn {key, value} ->
        "#{key} (#{value.severity})"
      end)

    case detected do
      [] -> "No problematic behaviors detected"
      items -> "Detected: #{Enum.join(items, ", ")}"
    end
  end
end
