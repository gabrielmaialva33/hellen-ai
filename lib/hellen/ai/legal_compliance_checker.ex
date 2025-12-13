defmodule Hellen.AI.LegalComplianceChecker do
  @moduledoc """
  Pattern-based compliance checker for Brazilian education laws.

  Validates transcriptions against:
  - Lei 13.185/2015 (Anti-bullying Program)
  - Lei 13.718/2018 (Digital Crimes / Internet Safety)
  - BNCC General Competencies

  This module provides fast, deterministic compliance checks
  without requiring LLM calls, serving as a verification layer.
  """

  alias Hellen.AI.BehaviorDetector
  alias Hellen.AI.ContextDetector

  @type compliance_level :: :compliant | :partial | :non_compliant | :violation
  @type risk_level :: :critical | :high | :medium | :low | :none

  @type lei_13185_result :: %{
          compliance_level: compliance_level(),
          risk_level: risk_level(),
          score: integer(),
          bullying_types_mentioned: [String.t()],
          bullying_types_practiced: [String.t()],
          preventive_approach: boolean(),
          violations: [String.t()],
          recommendations: [String.t()]
        }

  @type compliance_report :: %{
          lei_13185: lei_13185_result(),
          overall_compliance: compliance_level(),
          overall_risk: risk_level(),
          combined_score: integer(),
          legal_summary: String.t()
        }

  # Lei 13.185 - 9 Types of Bullying (Art. 2°)
  @bullying_types %{
    physical: %{
      patterns: [~r/bullying\s+físico/iu, ~r/agredir|socar|chutar|empurrar|beliscar/iu],
      name: "Físico",
      description: "Agredir, socar, chutar, beliscar, empurrar"
    },
    psychological: %{
      patterns: [~r/bullying\s+psicológico/iu, ~r/isolar|ignorar|humilhar|chantagear/iu],
      name: "Psicológico",
      description: "Isolar, ignorar, humilhar, chantagear, perseguir"
    },
    moral: %{
      patterns: [~r/bullying\s+moral/iu, ~r/difamar|caluniar|rumores?\s+falsos?/iu],
      name: "Moral",
      description: "Difamar, caluniar, disseminar rumores falsos"
    },
    verbal: %{
      patterns: [~r/bullying\s+verbal/iu, ~r/insultar|xingar|apelid(o|ar)\s+pejorativ/iu],
      name: "Verbal",
      description: "Insultar, xingar, apelidar pejorativamente"
    },
    material: %{
      patterns: [~r/bullying\s+material/iu, ~r/furtar|roubar|destruir\s+pertences/iu],
      name: "Material",
      description: "Furtar, roubar, destruir pertences"
    },
    sexual: %{
      patterns: [~r/bullying\s+sexual/iu, ~r/assédio\s+sexual|abusar/iu],
      name: "Sexual",
      description: "Assediar, induzir, abusar"
    },
    social: %{
      patterns: [~r/bullying\s+social/iu, ~r/excluir\s+de\s+grupos?|não\s+deixar\s+participar/iu],
      name: "Social",
      description: "Excluir de grupos, não deixar participar"
    },
    virtual: %{
      patterns: [
        ~r/bullying\s+virtual/iu,
        ~r/depreciar\s+online|mensagens?\s+ofensivas?\s+online/iu
      ],
      name: "Virtual",
      description: "Depreciar, enviar mensagens ofensivas online"
    },
    cyberbullying: %{
      patterns: [~r/cyberbullying/iu, ~r/perfis?\s+fals(o|a)s?|páginas?\s+fake/iu],
      name: "Cyberbullying",
      description: "Falsificar perfis, criar páginas fake"
    }
  }

  # Lei 13.185 - 7 School Obligations (Art. 4°)
  # Currently defined for future expansion - detect obligations mentioned in lessons
  @school_obligations %{
    prevention_programs: %{
      patterns: [~r/programa\s+de\s+prevenção/iu, ~r/prevenção\s+permanente/iu],
      name: "Programas de prevenção",
      description: "Implementar programas de prevenção permanentes"
    },
    staff_training: %{
      patterns: [~r/capacitação|treinamento|formação\s+de\s+professores/iu],
      name: "Capacitação de profissionais",
      description: "Capacitar professores e funcionários"
    },
    victim_support: %{
      patterns: [~r/acolher|acolhimento|apoio\s+às?\s+vítimas?/iu],
      name: "Acolhimento de vítimas",
      description: "Acolher e proteger vítimas"
    },
    aggressor_accountability: %{
      patterns: [~r/responsabiliza(r|ção)|consequências?\s+para\s+agressor/iu],
      name: "Responsabilização de agressores",
      description: "Responsabilizar agressores com abordagem educativa"
    },
    educational_campaigns: %{
      patterns: [~r/campanha\s+educativa|conscientização/iu],
      name: "Campanhas educativas",
      description: "Realizar campanhas educativas periódicas"
    },
    psychological_assistance: %{
      patterns: [~r/assistência\s+psicológica|apoio\s+psicológico|psicólogo/iu],
      name: "Assistência psicológica",
      description: "Oferecer assistência psicológica quando necessário"
    },
    family_involvement: %{
      patterns: [~r/articulação\s+com\s+famílias|envolver\s+(a\s+)?família/iu],
      name: "Articulação com famílias",
      description: "Articular ações com famílias e comunidade"
    }
  }

  # Preventive vs Punitive approach detection
  @preventive_patterns [
    ~r/vamos\s+conversar\s+sobre/iu,
    ~r/o\s+que\s+(vocês\s+)?acham/iu,
    ~r/como\s+podemos\s+(resolver|ajudar)/iu,
    ~r/educação|educar|ensinar/iu,
    ~r/prevenção|prevenir/iu,
    ~r/conscientização|conscientizar/iu
  ]

  @punitive_patterns [
    ~r/castigo|punição|punir/iu,
    ~r/suspensão|expulsão/iu,
    ~r/vai\s+ser\s+advertido/iu,
    ~r/chamar\s+os\s+pais\s+para\s+(reclam|punir)/iu
  ]

  @doc """
  Performs comprehensive legal compliance check.

  Returns detailed compliance report including Lei 13.185 analysis,
  detected violations, and recommendations.
  """
  @spec check_compliance(String.t()) :: compliance_report()
  def check_compliance(transcription) when is_binary(transcription) do
    # Get behavior analysis for violation detection
    behavior_report = BehaviorDetector.analyze(transcription)
    context_report = ContextDetector.analyze(transcription)

    # Check Lei 13.185 compliance
    lei_13185_result = check_lei_13185(transcription, behavior_report, context_report)

    # Calculate combined score
    combined_score = calculate_combined_score(lei_13185_result, context_report)

    # Determine overall compliance and risk
    overall_compliance = determine_overall_compliance(combined_score, lei_13185_result)
    overall_risk = determine_overall_risk(lei_13185_result, context_report)

    %{
      lei_13185: lei_13185_result,
      context_analysis: %{
        teaching_bullying: context_report.teaching_about_bullying,
        practicing_bullying: context_report.practicing_bullying,
        contradictions: length(context_report.contradictions),
        hypocrisy_score: context_report.hypocrisy_score
      },
      overall_compliance: overall_compliance,
      overall_risk: overall_risk,
      combined_score: combined_score,
      legal_summary: build_legal_summary(lei_13185_result, context_report, overall_compliance)
    }
  end

  @doc """
  Checks compliance specifically with Lei 13.185/2015.
  """
  @spec check_lei_13185(String.t(), map(), map()) :: lei_13185_result()
  def check_lei_13185(transcription, behavior_report, context_report) do
    # Detect mentioned bullying types (educational content)
    types_mentioned = detect_bullying_types_mentioned(transcription)

    # Detect practiced bullying behaviors (violations)
    types_practiced = detect_bullying_types_practiced(behavior_report)

    # Check approach (preventive vs punitive)
    preventive = preventive_approach?(transcription)

    # Identify violations
    violations = identify_violations(behavior_report, context_report)

    # Calculate compliance score
    score = calculate_lei_13185_score(types_mentioned, types_practiced, preventive, violations)

    # Determine compliance level
    compliance_level = score_to_compliance_level(score)

    # Determine risk level
    risk_level = calculate_risk_level(types_practiced, violations, context_report)

    # Build recommendations
    recommendations = build_lei_13185_recommendations(types_practiced, preventive, violations)

    %{
      compliance_level: compliance_level,
      risk_level: risk_level,
      score: score,
      bullying_types_mentioned: types_mentioned,
      bullying_types_practiced: types_practiced,
      preventive_approach: preventive,
      violations: violations,
      recommendations: recommendations
    }
  end

  @doc """
  Detects bullying types mentioned in educational context.
  """
  @spec detect_bullying_types_mentioned(String.t()) :: [String.t()]
  def detect_bullying_types_mentioned(transcription) do
    @bullying_types
    |> Enum.filter(fn {_key, type} ->
      Enum.any?(type.patterns, &Regex.match?(&1, transcription))
    end)
    |> Enum.map(fn {_key, type} -> type.name end)
  end

  @doc """
  Detects school obligations mentioned in the lesson (Art. 4° of Lei 13.185).
  Useful for assessing if the lesson addresses institutional responsibilities.
  """
  @spec detect_obligations_mentioned(String.t()) :: [String.t()]
  def detect_obligations_mentioned(transcription) do
    @school_obligations
    |> Enum.filter(fn {_key, obligation} ->
      Enum.any?(obligation.patterns, &Regex.match?(&1, transcription))
    end)
    |> Enum.map(fn {_key, obligation} -> obligation.name end)
  end

  @doc """
  Detects bullying types being practiced (violations).
  """
  @spec detect_bullying_types_practiced(map()) :: [String.t()]
  def detect_bullying_types_practiced(behavior_report) do
    practiced = []

    # Map detected behaviors to bullying types
    practiced =
      if behavior_report.sarcasm.detected or behavior_report.aggression.detected do
        ["Verbal" | practiced]
      else
        practiced
      end

    practiced =
      if behavior_report.public_shame.detected do
        ["Psicológico" | practiced]
      else
        practiced
      end

    practiced =
      if behavior_report.exclusion.detected do
        ["Social" | practiced]
      else
        practiced
      end

    Enum.uniq(practiced)
  end

  @doc """
  Checks if the lesson uses a preventive (educational) vs punitive approach.
  """
  @spec preventive_approach?(String.t()) :: boolean()
  def preventive_approach?(transcription) do
    preventive_count = count_pattern_matches(transcription, @preventive_patterns)
    punitive_count = count_pattern_matches(transcription, @punitive_patterns)

    preventive_count > punitive_count
  end

  # Private functions

  defp count_pattern_matches(text, patterns) do
    Enum.count(patterns, &Regex.match?(&1, text))
  end

  defp identify_violations(behavior_report, context_report) do
    violations = []

    # Direct behavior violations
    violations =
      if behavior_report.sarcasm.detected and behavior_report.sarcasm.severity == :critical do
        ["Uso de sarcasmo com severidade crítica (Art. 2°, IV - Verbal)" | violations]
      else
        violations
      end

    violations =
      if behavior_report.public_shame.detected do
        ["Exposição pública de aluno (Art. 2°, II - Psicológico)" | violations]
      else
        violations
      end

    violations =
      if behavior_report.exclusion.detected do
        ["Comportamento de exclusão (Art. 2°, VII - Social)" | violations]
      else
        violations
      end

    violations =
      if behavior_report.aggression.detected do
        ["Agressão verbal (Art. 2°, IV - Verbal)" | violations]
      else
        violations
      end

    # Context-based violations (hypocrisy)
    violations =
      if context_report.teaching_about_bullying and context_report.practicing_bullying do
        [
          "VIOLAÇÃO GRAVE: Praticando bullying durante aula sobre bullying (contradição pedagógica)"
          | violations
        ]
      else
        violations
      end

    violations
  end

  defp calculate_lei_13185_score(types_mentioned, types_practiced, preventive, violations) do
    base_score = 50

    # Bonus for mentioning bullying types (educational value)
    mention_bonus = min(length(types_mentioned) * 5, 20)

    # Bonus for preventive approach
    approach_bonus = if preventive, do: 15, else: 0

    # Penalty for practiced bullying
    practice_penalty = length(types_practiced) * 15

    # Penalty for violations
    violation_penalty =
      violations
      |> Enum.map(fn v ->
        if String.contains?(v, "VIOLAÇÃO GRAVE"), do: 30, else: 10
      end)
      |> Enum.sum()

    score = base_score + mention_bonus + approach_bonus - practice_penalty - violation_penalty
    max(0, min(100, score))
  end

  defp score_to_compliance_level(score) do
    cond do
      score >= 80 -> :compliant
      score >= 60 -> :partial
      score >= 40 -> :non_compliant
      true -> :violation
    end
  end

  defp calculate_risk_level(types_practiced, violations, context_report) do
    has_grave_violation = Enum.any?(violations, &String.contains?(&1, "VIOLAÇÃO GRAVE"))
    practiced_count = length(types_practiced)
    violation_count = length(violations)

    do_calculate_risk_level(has_grave_violation, practiced_count, violation_count, context_report)
  end

  defp do_calculate_risk_level(true, _, _, _), do: :critical
  defp do_calculate_risk_level(_, p, v, _) when p >= 2 and v >= 2, do: :critical
  defp do_calculate_risk_level(_, p, v, _) when p >= 2 or v >= 2, do: :high
  defp do_calculate_risk_level(_, p, v, _) when p >= 1 or v >= 1, do: :medium
  defp do_calculate_risk_level(_, _, _, %{practicing_bullying: true}), do: :medium
  defp do_calculate_risk_level(_, _, _, _), do: :none

  defp build_lei_13185_recommendations(types_practiced, preventive, violations) do
    recommendations = []

    # Recommendations based on practiced types
    recommendations =
      if "Verbal" in types_practiced do
        [
          "Substituir sarcasmo e linguagem agressiva por comunicação assertiva e respeitosa"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if "Psicológico" in types_practiced do
        [
          "Abordar questões individuais em particular, nunca expondo alunos publicamente"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if "Social" in types_practiced do
        ["Garantir que todos os alunos sejam incluídos nas atividades da aula" | recommendations]
      else
        recommendations
      end

    # Recommendations based on approach
    recommendations =
      if preventive do
        recommendations
      else
        [
          "Adotar abordagem preventiva/educativa em vez de punitiva conforme Art. 4° da Lei 13.185"
          | recommendations
        ]
      end

    # Recommendations based on violations
    recommendations =
      if Enum.any?(violations, &String.contains?(&1, "VIOLAÇÃO GRAVE")) do
        [
          "URGENTE: Revisar completamente a abordagem pedagógica - comportamento contradiz o tema ensinado"
          | recommendations
        ]
      else
        recommendations
      end

    case recommendations do
      [] -> ["Manter práticas atuais e continuar o trabalho preventivo"]
      _ -> Enum.reverse(recommendations)
    end
  end

  defp calculate_combined_score(lei_13185_result, context_report) do
    # Weight: Lei 13.185 (60%) + Context/Hypocrisy (40%)
    lei_score = lei_13185_result.score * 0.6
    context_score = context_report.hypocrisy_score * 0.4

    round(lei_score + context_score)
  end

  defp determine_overall_compliance(combined_score, lei_13185_result) do
    # If there's a grave violation, override to violation
    if lei_13185_result.compliance_level == :violation do
      :violation
    else
      score_to_compliance_level(combined_score)
    end
  end

  defp determine_overall_risk(lei_13185_result, context_report) do
    lei_risk = lei_13185_result.risk_level
    has_hypocrisy = context_report.teaching_about_bullying and context_report.practicing_bullying

    cond do
      lei_risk == :critical or has_hypocrisy -> :critical
      lei_risk == :high -> :high
      lei_risk == :medium -> :medium
      lei_risk == :low -> :low
      true -> :none
    end
  end

  defp build_legal_summary(lei_13185_result, context_report, overall_compliance) do
    compliance_text =
      case overall_compliance do
        :compliant -> "✅ CONFORME - Aula em conformidade com Lei 13.185/2015"
        :partial -> "⚠️ PARCIALMENTE CONFORME - Ajustes necessários para conformidade total"
        :non_compliant -> "❌ NÃO CONFORME - Violações detectadas que requerem ação"
        :violation -> "🚨 VIOLAÇÃO GRAVE - Ação imediata necessária"
      end

    hypocrisy_text =
      if context_report.teaching_about_bullying and context_report.practicing_bullying do
        " | ALERTA: Contradição entre tema ensinado e comportamento observado."
      else
        ""
      end

    violations_text =
      case length(lei_13185_result.violations) do
        0 -> ""
        n -> " | #{n} violação(ões) identificada(s)."
      end

    "#{compliance_text}#{hypocrisy_text}#{violations_text}"
  end
end
