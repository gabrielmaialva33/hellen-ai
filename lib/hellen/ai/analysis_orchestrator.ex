defmodule Hellen.AI.AnalysisOrchestrator do
  @moduledoc """
  Orchestrates the full analysis pipeline with multiple outputs.

  Coordinates the v3.0 MASTERCLASS analysis flow:
  1. Core Analysis (13 dimensions with full legal compliance)
  2. Optional: Self-Consistency validation
  3. Optional: Legal Compliance Check (Lei 13.185 + Lei 13.718)
  4. Optional: Socioemotional Analysis (OCDE 5 pillars)
  5. Parallel output generation:
     - Practical Examples for critical dimensions
     - Coaching Email for teacher

  ## Usage

      # Full v3.0 analysis with all outputs
      {:ok, result} = AnalysisOrchestrator.run_full_analysis_v3(transcription, context)

      # Full v2.0 analysis (legacy)
      {:ok, result} = AnalysisOrchestrator.run_full_analysis(transcription, context)

      # Quick analysis (compliance check only)
      {:ok, result} = AnalysisOrchestrator.run_quick_analysis(transcription)

      # Legal compliance only
      {:ok, result} = AnalysisOrchestrator.run_legal_compliance(transcription)

      # Self-consistency for critical analyses
      {:ok, result} = AnalysisOrchestrator.run_with_consensus(transcription, context)

  ## Output Structure v3.0

      %{
        core_analysis: %{...},        # 13-dimension analysis with legal compliance
        legal_compliance: %{...},     # Lei 13.185 + Lei 13.718 details
        socioemotional: %{...},       # OCDE 5 pillars scores
        practical_examples: [%{...}], # Before/after examples for critical dimensions
        coaching_email: %{...},       # Personalized email for teacher
        summary: %{...},              # Quick summary with key metrics
        processing_time_ms: 12345,
        total_tokens: 8000
      }
  """

  require Logger

  alias Hellen.AI.NvidiaClient

  @doc """
  Runs the full analysis pipeline with parallel output generation.

  ## Options
  - `:generate_examples` - Generate practical examples for critical dimensions (default: true)
  - `:generate_email` - Generate coaching email (default: true)
  - `:self_consistency` - Use self-consistency for core analysis (default: false)
  - `:samples` - Number of samples for self-consistency (default: 3)
  """
  def run_full_analysis(transcription, context \\ %{}, opts \\ []) do
    generate_examples = Keyword.get(opts, :generate_examples, true)
    generate_email = Keyword.get(opts, :generate_email, true)
    use_self_consistency = Keyword.get(opts, :self_consistency, false)
    samples = Keyword.get(opts, :samples, 3)

    Logger.info("[AnalysisOrchestrator] Starting full analysis pipeline")
    start_time = System.monotonic_time(:millisecond)

    # Step 1: Core Analysis
    core_result =
      if use_self_consistency do
        NvidiaClient.analyze_with_self_consistency(transcription, context, samples: samples)
      else
        NvidiaClient.analyze_v2(transcription, context)
      end

    case core_result do
      {:ok, core_analysis} ->
        # Extract critical dimensions for examples
        critical_dimensions = extract_critical_dimensions(core_analysis)

        # Step 2: Parallel output generation
        parallel_tasks =
          build_parallel_tasks(
            transcription,
            context,
            core_analysis,
            critical_dimensions,
            generate_examples,
            generate_email
          )

        results = run_parallel_tasks(parallel_tasks)

        # Aggregate results
        practical_examples = Map.get(results, :practical_examples, [])
        coaching_email = Map.get(results, :coaching_email)

        processing_time = System.monotonic_time(:millisecond) - start_time
        total_tokens = calculate_total_tokens(core_analysis, results)

        Logger.info("[AnalysisOrchestrator] Full pipeline completed in #{processing_time}ms")

        {:ok,
         %{
           core_analysis: normalize_core_analysis(core_analysis),
           practical_examples: practical_examples,
           coaching_email: coaching_email,
           summary: build_summary(core_analysis, critical_dimensions),
           metadata: %{
             version: "2.0",
             self_consistency: use_self_consistency,
             confidence: Map.get(core_analysis, :confidence),
             samples_used: Map.get(core_analysis, :sample_count, 1)
           },
           processing_time_ms: processing_time,
           total_tokens: total_tokens
         }}

      {:error, reason} ->
        Logger.error("[AnalysisOrchestrator] Core analysis failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Runs the full v3.0 MASTERCLASS analysis pipeline with legal compliance.

  ## Options
  - `:generate_examples` - Generate practical examples (default: true)
  - `:generate_email` - Generate coaching email (default: true)
  - `:include_legal` - Include separate legal compliance check (default: true)
  - `:include_socioemotional` - Include OCDE analysis (default: true)
  - `:self_consistency` - Use self-consistency (default: false)
  - `:samples` - Number of samples for self-consistency (default: 3)
  """
  def run_full_analysis_v3(transcription, context \\ %{}, opts \\ []) do
    config = parse_v3_options(opts)

    Logger.info("[AnalysisOrchestrator] Starting v3.0 MASTERCLASS pipeline")
    start_time = System.monotonic_time(:millisecond)

    core_result = run_core_analysis_v3(transcription, context, config)
    process_v3_pipeline(core_result, transcription, context, config, start_time)
  end

  defp parse_v3_options(opts) do
    %{
      generate_examples: Keyword.get(opts, :generate_examples, true),
      generate_email: Keyword.get(opts, :generate_email, true),
      include_legal: Keyword.get(opts, :include_legal, true),
      include_socioemotional: Keyword.get(opts, :include_socioemotional, true),
      use_self_consistency: Keyword.get(opts, :self_consistency, false),
      samples: Keyword.get(opts, :samples, 3)
    }
  end

  defp run_core_analysis_v3(transcription, context, %{use_self_consistency: true, samples: samples}) do
    NvidiaClient.analyze_with_self_consistency(transcription, context, samples: samples)
  end

  defp run_core_analysis_v3(transcription, context, _config) do
    NvidiaClient.analyze_v3(transcription, context)
  end

  defp process_v3_pipeline({:error, reason}, _transcription, _context, _config, _start_time) do
    Logger.error("[AnalysisOrchestrator] v3.0 core analysis failed: #{inspect(reason)}")
    {:error, reason}
  end

  defp process_v3_pipeline({:ok, core_analysis}, transcription, context, config, start_time) do
    critical_dimensions = extract_critical_dimensions(core_analysis)

    parallel_tasks = build_v3_parallel_tasks(transcription, context, core_analysis, critical_dimensions, config)
    results = run_parallel_tasks_v3(parallel_tasks)

    processing_time = System.monotonic_time(:millisecond) - start_time
    total_tokens = calculate_total_tokens_v3(core_analysis, results)

    Logger.info("[AnalysisOrchestrator] v3.0 pipeline completed in #{processing_time}ms")

    {:ok, build_v3_response(core_analysis, critical_dimensions, results, config, processing_time, total_tokens)}
  end

  defp build_v3_parallel_tasks(transcription, context, core_analysis, critical_dimensions, config) do
    []
    |> maybe_add_legal_task(transcription, config.include_legal)
    |> maybe_add_socioemotional_task(transcription, config.include_socioemotional)
    |> maybe_add_example_tasks(transcription, critical_dimensions, config.generate_examples)
    |> maybe_add_email_task(core_analysis, context, config.generate_email)
  end

  # Pipeline helper functions for building parallel tasks
  defp maybe_add_legal_task(tasks, _transcription, false), do: tasks

  defp maybe_add_legal_task(tasks, transcription, true) do
    [{:legal, nil, fn -> NvidiaClient.check_legal_compliance(transcription) end} | tasks]
  end

  defp maybe_add_socioemotional_task(tasks, _transcription, false), do: tasks

  defp maybe_add_socioemotional_task(tasks, transcription, true) do
    [{:socioemotional, nil, fn -> NvidiaClient.analyze_socioemotional(transcription) end} | tasks]
  end

  defp maybe_add_example_tasks(tasks, _transcription, _critical_dimensions, false), do: tasks
  defp maybe_add_example_tasks(tasks, _transcription, [], _generate), do: tasks

  defp maybe_add_example_tasks(tasks, transcription, critical_dimensions, true) do
    example_tasks =
      Enum.map(critical_dimensions, fn dim ->
        {:example, dim, fn -> NvidiaClient.generate_practical_examples(transcription, dim.nome, dim.gap) end}
      end)

    tasks ++ example_tasks
  end

  defp maybe_add_email_task(tasks, _core_analysis, _context, false), do: tasks

  defp maybe_add_email_task(tasks, core_analysis, context, true) do
    email_context = build_email_context(core_analysis, context)
    [{:email, nil, fn -> NvidiaClient.generate_coaching_email(email_context) end} | tasks]
  end

  defp build_v3_response(core_analysis, critical_dimensions, results, config, processing_time, total_tokens) do
    %{
      core_analysis: normalize_core_analysis(core_analysis),
      legal_compliance: Map.get(results, :legal),
      socioemotional: Map.get(results, :socioemotional),
      practical_examples: Map.get(results, :practical_examples, []),
      coaching_email: Map.get(results, :coaching_email),
      summary: build_summary_v3(core_analysis, critical_dimensions, results),
      metadata: %{
        version: "3.0",
        technique: "MASTERCLASS",
        self_consistency: config.use_self_consistency,
        confidence: Map.get(core_analysis, :confidence),
        samples_used: Map.get(core_analysis, :sample_count, 1),
        legal_included: config.include_legal,
        socioemotional_included: config.include_socioemotional
      },
      processing_time_ms: processing_time,
      total_tokens: total_tokens
    }
  end

  @doc """
  Runs only legal compliance check (Lei 13.185 + Lei 13.718).
  Fast check for legal risk assessment.
  """
  def run_legal_compliance(transcription) do
    Logger.info("[AnalysisOrchestrator] Starting legal compliance check")
    start_time = System.monotonic_time(:millisecond)

    case NvidiaClient.check_legal_compliance(transcription) do
      {:ok, result} ->
        processing_time = System.monotonic_time(:millisecond) - start_time

        {:ok,
         %{
           legal_compliance: result.structured,
           lei_13185_score: get_in(result.structured, ["lei_13185_conformidade", "score_geral"]),
           lei_13718_score: get_in(result.structured, ["lei_13718_conformidade", "score_geral"]),
           risco_legal: get_in(result.structured, ["conformidade_geral", "risco_legal"]),
           status: get_in(result.structured, ["conformidade_geral", "status"]),
           processing_time_ms: processing_time,
           tokens_used: result.tokens_used
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Runs a quick compliance check for fast feedback.
  Returns in ~10-15 seconds vs ~60s for full analysis.
  """
  def run_quick_analysis(transcription) do
    Logger.info("[AnalysisOrchestrator] Starting quick analysis")
    start_time = System.monotonic_time(:millisecond)

    case NvidiaClient.quick_compliance_check(transcription) do
      {:ok, result} ->
        processing_time = System.monotonic_time(:millisecond) - start_time

        {:ok,
         %{
           quick_check: result.structured,
           urgency: get_in(result.structured, ["urgencia_acao"]),
           conformidade: get_in(result.structured, ["conformidade_geral_percent"]),
           recommendation: get_in(result.structured, ["recomendacao_rapida"]),
           processing_time_ms: processing_time,
           tokens_used: result.tokens_used
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Runs analysis with self-consistency for maximum accuracy.
  Best for critical analyses that require high confidence.
  """
  def run_with_consensus(transcription, context \\ %{}, opts \\ []) do
    samples = Keyword.get(opts, :samples, 3)

    run_full_analysis(transcription, context,
      self_consistency: true,
      samples: samples,
      generate_examples: true,
      generate_email: true
    )
  end

  @doc """
  Generates additional outputs for an existing analysis.
  Useful when you already have the core analysis.
  """
  def generate_additional_outputs(transcription, core_analysis, context \\ %{}, opts \\ []) do
    generate_examples = Keyword.get(opts, :generate_examples, true)
    generate_email = Keyword.get(opts, :generate_email, true)

    critical_dimensions = extract_critical_dimensions(%{structured: core_analysis})

    parallel_tasks =
      build_parallel_tasks(
        transcription,
        context,
        %{structured: core_analysis},
        critical_dimensions,
        generate_examples,
        generate_email
      )

    results = run_parallel_tasks(parallel_tasks)

    {:ok,
     %{
       practical_examples: Map.get(results, :practical_examples, []),
       coaching_email: Map.get(results, :coaching_email)
     }}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp extract_critical_dimensions(core_analysis) do
    # Extract from self-consistency consensus or regular analysis
    structured =
      case core_analysis do
        %{consensus: consensus} -> consensus
        %{structured: s} -> s
        other -> other
      end

    dimensions = Map.get(structured, "analise_dimensoes", [])

    # Find dimensions with conformidade < 50% (critical)
    dimensions
    |> Enum.filter(fn dim ->
      score = Map.get(dim, "conformidade_percent", 100)
      score < 50
    end)
    |> Enum.sort_by(&Map.get(&1, "conformidade_percent", 0))
    # Top 3 most critical
    |> Enum.take(3)
    |> Enum.map(fn dim ->
      %{
        numero: Map.get(dim, "numero"),
        nome: Map.get(dim, "nome"),
        score: Map.get(dim, "conformidade_percent"),
        gap: Map.get(dim, "gap_principal", "Não especificado")
      }
    end)
  end

  defp build_parallel_tasks(
         transcription,
         context,
         core_analysis,
         critical_dims,
         gen_examples,
         gen_email
       ) do
    []
    |> maybe_add_example_tasks(transcription, critical_dims, gen_examples)
    |> maybe_add_email_task(core_analysis, context, gen_email)
  end

  defp build_email_context(core_analysis, context) do
    structured =
      case core_analysis do
        %{consensus: consensus} -> consensus
        %{structured: s} -> s
        other -> other
      end

    metadata = Map.get(structured, "metadata", %{})
    pontos_fortes = Map.get(structured, "pontos_fortes", [])
    pontos_criticos = Map.get(structured, "pontos_criticos", [])

    # Get first strong point
    ponto_forte =
      case pontos_fortes do
        [first | _] -> Map.get(first, "ponto", "Domínio do conteúdo")
        _ -> "Comprometimento com a aula"
      end

    # Get first critical point
    ponto_critico =
      case pontos_criticos do
        [first | _] -> Map.get(first, "titulo", "Sensibilização")
        _ -> "Gestão de tempo"
      end

    %{
      teacher_name: context[:teacher_name] || "Professor(a)",
      conformidade: Map.get(metadata, "conformidade_geral_percent", 50),
      ponto_forte: ponto_forte,
      ponto_critico: ponto_critico,
      desafio: Map.get(metadata, "potencial_melhoria", "MEDIO"),
      transcription_summary: "Análise baseada na transcrição da aula"
    }
  end

  defp run_parallel_tasks(tasks) do
    tasks
    |> Task.async_stream(
      fn {type, dim, fun} ->
        result = fun.()
        {type, dim, result}
      end,
      timeout: 120_000,
      max_concurrency: 4
    )
    |> Enum.reduce(%{practical_examples: [], coaching_email: nil}, fn
      {:ok, {:example, dim, {:ok, result}}}, acc ->
        example = %{
          dimension: dim.nome,
          dimension_numero: dim.numero,
          gap: dim.gap,
          examples: result.structured
        }

        Map.update!(acc, :practical_examples, &[example | &1])

      {:ok, {:email, _, {:ok, result}}}, acc ->
        Map.put(acc, :coaching_email, result.structured)

      {:ok, {_type, _dim, {:error, reason}}}, acc ->
        Logger.warning("[AnalysisOrchestrator] Task failed: #{inspect(reason)}")
        acc

      {:exit, reason}, acc ->
        Logger.warning("[AnalysisOrchestrator] Task exited: #{inspect(reason)}")
        acc
    end)
  end

  defp normalize_core_analysis(%{consensus: consensus} = analysis) do
    %{
      structured: consensus,
      confidence: analysis.confidence,
      disagreements: analysis.disagreements,
      sample_count: analysis.sample_count,
      version: analysis.version
    }
  end

  defp normalize_core_analysis(%{structured: structured} = analysis) do
    %{
      structured: structured,
      version: Map.get(analysis, :version, "2.0"),
      technique: Map.get(analysis, :technique, "CoT+FewShot")
    }
  end

  defp normalize_core_analysis(other), do: other

  defp build_summary(core_analysis, critical_dimensions) do
    structured =
      case core_analysis do
        %{consensus: consensus} -> consensus
        %{structured: s} -> s
        other -> other
      end

    metadata = Map.get(structured, "metadata", %{})

    %{
      conformidade_geral: Map.get(metadata, "conformidade_geral_percent", 0),
      status: Map.get(metadata, "status_geral", "⚠️ ADEQUADO"),
      potencial_melhoria: Map.get(metadata, "potencial_melhoria", "MEDIO"),
      dimensoes_criticas: Enum.map(critical_dimensions, & &1.nome),
      pontos_fortes_count: length(Map.get(structured, "pontos_fortes", [])),
      pontos_criticos_count: length(Map.get(structured, "pontos_criticos", []))
    }
  end

  defp calculate_total_tokens(core_analysis, parallel_results) do
    core_tokens = Map.get(core_analysis, :tokens_used, 0)

    example_tokens =
      parallel_results
      |> Map.get(:practical_examples, [])
      |> Enum.reduce(0, fn ex, acc -> acc + Map.get(ex, :tokens_used, 0) end)

    email_tokens =
      case Map.get(parallel_results, :coaching_email) do
        %{tokens_used: t} -> t
        _ -> 0
      end

    core_tokens + example_tokens + email_tokens
  end

  # ============================================================================
  # v3.0 Helper Functions
  # ============================================================================

  defp run_parallel_tasks_v3(tasks) do
    tasks
    |> Task.async_stream(
      fn {type, dim, fun} ->
        result = fun.()
        {type, dim, result}
      end,
      timeout: 150_000,
      max_concurrency: 5
    )
    |> Enum.reduce(
      %{practical_examples: [], coaching_email: nil, legal: nil, socioemotional: nil},
      fn
        {:ok, {:example, dim, {:ok, result}}}, acc ->
          example = %{
            dimension: dim.nome,
            dimension_numero: dim.numero,
            gap: dim.gap,
            examples: result.structured
          }

          Map.update!(acc, :practical_examples, &[example | &1])

        {:ok, {:email, _, {:ok, result}}}, acc ->
          Map.put(acc, :coaching_email, result.structured)

        {:ok, {:legal, _, {:ok, result}}}, acc ->
          Map.put(acc, :legal, result.structured)

        {:ok, {:socioemotional, _, {:ok, result}}}, acc ->
          Map.put(acc, :socioemotional, result.structured)

        {:ok, {type, _dim, {:error, reason}}}, acc ->
          Logger.warning("[AnalysisOrchestrator] v3.0 task #{type} failed: #{inspect(reason)}")
          acc

        {:exit, reason}, acc ->
          Logger.warning("[AnalysisOrchestrator] v3.0 task exited: #{inspect(reason)}")
          acc
      end
    )
  end

  defp build_summary_v3(core_analysis, critical_dimensions, parallel_results) do
    structured =
      case core_analysis do
        %{consensus: consensus} -> consensus
        %{structured: s} -> s
        other -> other
      end

    metadata = Map.get(structured, "metadata", %{})
    legal = Map.get(parallel_results, :legal, %{})
    socioemotional = Map.get(parallel_results, :socioemotional, %{})

    %{
      conformidade_geral: Map.get(metadata, "conformidade_geral_percent", 0),
      conformidade_legal: Map.get(metadata, "conformidade_legal_percent", 0),
      status: Map.get(metadata, "status_geral", "⚠️ ADEQUADO"),
      risco_legal: Map.get(metadata, "risco_legal", "BAIXO"),
      potencial_melhoria: Map.get(metadata, "potencial_melhoria", "MEDIO"),
      dimensoes_criticas: Enum.map(critical_dimensions, & &1.nome),
      pontos_fortes_count: length(Map.get(structured, "pontos_fortes", [])),
      pontos_criticos_count: length(Map.get(structured, "pontos_criticos", [])),
      lei_13185: %{
        score: get_in(legal, ["lei_13185_conformidade", "score_geral"]),
        abordagem_preventiva: get_in(legal, ["lei_13185_conformidade", "abordagem_preventiva"])
      },
      lei_13718: %{
        score: get_in(legal, ["lei_13718_conformidade", "score_geral"]),
        cidadania_digital: get_in(legal, ["lei_13718_conformidade", "cidadania_digital_pilares"])
      },
      socioemotional_score: Map.get(socioemotional, "score_socioemocional_geral"),
      competencias_bncc: Map.get(structured, "competencias_bncc", %{})
    }
  end

  defp calculate_total_tokens_v3(core_analysis, parallel_results) do
    core_tokens = Map.get(core_analysis, :tokens_used, 0)

    example_tokens =
      parallel_results
      |> Map.get(:practical_examples, [])
      |> Enum.reduce(0, fn ex, acc -> acc + Map.get(ex, :tokens_used, 0) end)

    legal_tokens =
      case Map.get(parallel_results, :legal) do
        %{tokens_used: t} -> t
        _ -> 0
      end

    socioemotional_tokens =
      case Map.get(parallel_results, :socioemotional) do
        %{tokens_used: t} -> t
        _ -> 0
      end

    email_tokens =
      case Map.get(parallel_results, :coaching_email) do
        %{tokens_used: t} -> t
        _ -> 0
      end

    core_tokens + example_tokens + legal_tokens + socioemotional_tokens + email_tokens
  end
end
