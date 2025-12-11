defmodule HellenWeb.LessonLive.Show do
  @moduledoc """
  Lesson details LiveView with analysis, score evolution chart, and trend indicators.
  """
  use HellenWeb, :live_view

  alias Hellen.Analysis
  alias Hellen.BNCC
  alias Hellen.Lessons
  alias Hellen.Storage

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user
    lesson = Lessons.get_lesson_with_transcription!(id, user.institution_id)
    analyses = Analysis.list_analyses_by_lesson(id, user.institution_id)
    latest_analysis = List.first(analyses) |> maybe_parse_raw_analysis()

    # Subscribe to real-time updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Hellen.PubSub, "lesson:#{id}")
    end

    {:ok,
     socket
     |> assign(page_title: lesson.title || "Detalhes da Aula")
     |> assign(lesson: lesson)
     |> assign(analyses: analyses)
     |> assign(latest_analysis: latest_analysis)
     |> assign(show_analysis: socket.assigns.live_action == :analysis)
     |> assign(active_tab: "transcription")
     |> assign(planned_content: lesson.planned_content || "")
     |> assign(editing_planned: false)
     |> assign(generating_suggestions: false)
     |> assign(uploading_file: false)
     |> allow_upload(:planned_file,
       accept: ~w(.pdf .docx .doc .md .txt),
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true
     )
     |> load_analytics_async(user, lesson)}
  end

  # Try to recover analysis data from raw JSON string when parsing failed
  defp maybe_parse_raw_analysis(nil), do: nil

  defp maybe_parse_raw_analysis(%{result: %{"error" => _, "raw" => raw}} = analysis)
       when is_binary(raw) do
    case Jason.decode(raw) do
      {:ok, parsed} ->
        # Recovered data from raw - merge into result and extract overall_score
        extract_parsed_analysis(analysis, parsed)

      {:error, _} ->
        # JSON is truncated/invalid - try to extract partial data with regex
        extract_partial_analysis(analysis, raw)
    end
  end

  defp maybe_parse_raw_analysis(analysis), do: analysis

  defp extract_parsed_analysis(analysis, parsed) do
    overall_score = parsed["overall_score"]
    bncc_codes = parsed["bncc_matches"] || []
    feedback = parsed["feedback"]
    strengths = parsed["strengths"] || []
    improvements = parsed["improvements"] || []
    bullying_alert_data = parsed["bullying_alerts"] || []

    new_result = %{
      "feedback" => feedback,
      "strengths" => strengths,
      "improvements" => improvements,
      "bncc_codes" => bncc_codes,
      "bullying_alert_data" => bullying_alert_data,
      "recovered_from_raw" => true
    }

    %{analysis | result: new_result, overall_score: overall_score}
  end

  defp extract_partial_analysis(analysis, raw) do
    # Extract raw overall_score using regex
    raw_score =
      case Regex.run(~r/"overall_score"\s*:\s*([\d.]+)/, raw) do
        [_, score_str] -> String.to_float(score_str)
        _ -> nil
      end

    # Extract BNCC codes using regex - find all "EF..." patterns
    bncc_codes =
      ~r/"(EF\d+[A-Z]+\d+)"/
      |> Regex.scan(raw)
      |> Enum.map(fn [_, code] -> code end)
      |> Enum.uniq()
      |> Enum.take(20)

    # Extract bullying alerts count
    bullying_count =
      case Regex.run(~r/"bullying_alerts"\s*:\s*\[([^\]]*)\]/, raw) do
        [_, content] when content != "" -> String.split(content, "},") |> length()
        _ -> 0
      end

    # Only create result if we found at least something
    if raw_score || length(bncc_codes) > 0 do
      # Calculate enhanced score using BNCC module
      enhanced_score =
        BNCC.calculate_score(%{
          raw_score: raw_score,
          bncc_count: length(bncc_codes),
          bullying_alerts: bullying_count,
          word_count: 0,
          has_transcription: true
        })

      new_result = %{
        "bncc_codes" => bncc_codes,
        "recovered_from_raw" => true,
        "partial_recovery" => true,
        "raw_score" => raw_score,
        "enhanced_score" => enhanced_score,
        "bullying_count" => bullying_count
      }

      %{analysis | result: new_result, overall_score: enhanced_score}
    else
      analysis
    end
  end

  defp load_analytics_async(socket, user, lesson) do
    if connected?(socket) do
      start_async(socket, :load_analytics, fn ->
        score_history = Analysis.get_user_score_history(user.id)
        {trend, trend_change} = Analysis.get_user_trend(user.id)

        discipline_avg =
          if lesson.subject && user.institution_id do
            Analysis.get_discipline_average(lesson.subject, user.institution_id)
          end

        bncc_coverage = Analysis.get_bncc_coverage(user.id, limit: 20)

        %{
          score_history: score_history,
          trend: trend,
          trend_change: trend_change,
          discipline_avg: discipline_avg,
          bncc_coverage: bncc_coverage
        }
      end)
    else
      socket
      |> assign(score_history: [])
      |> assign(trend: :stable)
      |> assign(trend_change: 0.0)
      |> assign(discipline_avg: nil)
      |> assign(bncc_coverage: [])
    end
  end

  @impl true
  def handle_async(:load_analytics, {:ok, analytics}, socket) do
    {:noreply,
     socket
     |> assign(score_history: analytics.score_history)
     |> assign(trend: analytics.trend)
     |> assign(trend_change: analytics.trend_change)
     |> assign(discipline_avg: analytics.discipline_avg)
     |> assign(bncc_coverage: analytics.bncc_coverage)}
  end

  def handle_async(:load_analytics, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(score_history: [])
     |> assign(trend: :stable)
     |> assign(trend_change: 0.0)
     |> assign(discipline_avg: nil)
     |> assign(bncc_coverage: [])}
  end

  @impl true
  def handle_async(:generate_suggestions, {:ok, suggestions_data}, socket) do
    {:noreply,
     socket
     |> assign(generating_suggestions: false)
     |> assign(ai_suggestions: suggestions_data.suggestions)
     |> assign(active_tab: "suggestions")}
  end

  @impl true
  def handle_async(:generate_suggestions, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(generating_suggestions: false)
     |> put_flash(:error, "Erro ao gerar sugestoes")}
  end

  @impl true
  def handle_params(%{"id" => _id}, _uri, socket) do
    {:noreply, assign(socket, show_analysis: socket.assigns.live_action == :analysis)}
  end

  @impl true
  def handle_info({"transcription_progress", %{progress: progress}}, socket) do
    {:noreply, assign(socket, transcription_progress: progress)}
  end

  @impl true
  def handle_info({"transcription_complete", _payload}, socket) do
    lesson = Lessons.get_lesson_with_transcription!(socket.assigns.lesson.id)
    {:noreply, assign(socket, lesson: lesson, transcription_progress: 100)}
  end

  @impl true
  def handle_info({"analysis_progress", %{progress: progress}}, socket) do
    {:noreply, assign(socket, analysis_progress: progress)}
  end

  @impl true
  def handle_info({"analysis_complete", %{analysis: analysis}}, socket) do
    lesson = %{socket.assigns.lesson | status: "completed"}
    analyses = [analysis | socket.assigns.analyses]

    {:noreply,
     socket
     |> assign(lesson: lesson, analyses: analyses, latest_analysis: analysis)
     |> put_flash(:info, "Análise concluída!")}
  end

  @impl true
  def handle_info({"status_update", %{status: status}}, socket) do
    lesson = %{socket.assigns.lesson | status: status}
    {:noreply, assign(socket, lesson: lesson)}
  end

  @impl true
  def handle_info({"transcription_failed", %{error: error}}, socket) do
    lesson = %{socket.assigns.lesson | status: "failed"}

    {:noreply,
     socket
     |> assign(lesson: lesson)
     |> put_flash(:error, "Transcrição falhou: #{error}")}
  end

  @impl true
  def handle_info({"analysis_failed", %{error: error}}, socket) do
    lesson = %{socket.assigns.lesson | status: "failed"}

    {:noreply,
     socket
     |> assign(lesson: lesson)
     |> put_flash(:error, "Análise falhou: #{error}")}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("online", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("start_processing", _params, socket) do
    lesson = socket.assigns.lesson
    user = socket.assigns.current_user

    case Lessons.start_processing(lesson, user) do
      {:ok, updated_lesson} ->
        {:noreply,
         socket
         |> assign(lesson: updated_lesson)
         |> put_flash(:info, "Processamento iniciado!")}

      {:error, :insufficient_credits} ->
        {:noreply, put_flash(socket, :error, "Créditos insuficientes")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Erro ao iniciar: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def handle_event("edit_planned", _params, socket) do
    {:noreply, assign(socket, editing_planned: true)}
  end

  @impl true
  def handle_event("cancel_edit_planned", _params, socket) do
    {:noreply,
     socket
     |> assign(editing_planned: false)
     |> assign(planned_content: socket.assigns.lesson.planned_content || "")}
  end

  @impl true
  def handle_event("update_planned_content", %{"planned_content" => content}, socket) do
    {:noreply, assign(socket, planned_content: content)}
  end

  @impl true
  def handle_event("save_planned_content", _params, socket) do
    lesson = socket.assigns.lesson
    content = socket.assigns.planned_content

    case Lessons.update_planned_content(lesson, content) do
      {:ok, updated_lesson} ->
        {:noreply,
         socket
         |> assign(lesson: updated_lesson)
         |> assign(editing_planned: false)
         |> put_flash(:info, "Material planejado salvo!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Erro ao salvar material")}
    end
  end

  @impl true
  def handle_event("generate_suggestions", _params, socket) do
    # Start async AI suggestion generation
    lesson = socket.assigns.lesson

    socket =
      socket
      |> assign(generating_suggestions: true)
      |> start_async(:generate_suggestions, fn ->
        generate_ai_suggestions(lesson)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_file", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_planned_file", _params, socket) do
    lesson = socket.assigns.lesson

    uploaded_files =
      consume_uploaded_entries(socket, :planned_file, fn %{path: path}, entry ->
        file_name = entry.client_name
        key = "lessons/#{lesson.id}/planned/#{file_name}"

        case Storage.upload_file(path, key, content_type: entry.client_type) do
          {:ok, url} -> {:ok, {url, file_name}}
          {:error, reason} -> {:error, reason}
        end
      end)

    case uploaded_files do
      [{url, file_name}] ->
        case Lessons.update_planned_file(lesson, url, file_name) do
          {:ok, updated_lesson} ->
            {:noreply,
             socket
             |> assign(lesson: updated_lesson)
             |> put_flash(:info, "Arquivo '#{file_name}' enviado com sucesso!")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Erro ao salvar arquivo")}
        end

      [] ->
        {:noreply, put_flash(socket, :error, "Nenhum arquivo selecionado")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Erro no upload: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("remove_planned_file", _params, socket) do
    lesson = socket.assigns.lesson

    case Lessons.update_planned_file(lesson, nil, nil) do
      {:ok, updated_lesson} ->
        {:noreply,
         socket
         |> assign(lesson: updated_lesson)
         |> put_flash(:info, "Arquivo removido")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao remover arquivo")}
    end
  end

  defp generate_ai_suggestions(lesson) do
    # For now, return mock suggestions - later integrate with AI
    transcription_text =
      if lesson.transcription, do: lesson.transcription.full_text, else: ""

    %{
      suggestions: [
        %{
          title: "Reportagem e Cyberbullying",
          description:
            "Aprofunde o tema com dados atualizados sobre cyberbullying no Brasil e estrategias de prevencao.",
          source: "BNCC - EF09LP03",
          source_url: "http://basenacionalcomum.mec.gov.br"
        },
        %{
          title: "Generos Jornalisticos",
          description:
            "Explore as diferencas entre noticia, reportagem e artigo de opiniao com exemplos praticos.",
          source: "BNCC - EF09LP01",
          source_url: "http://basenacionalcomum.mec.gov.br"
        },
        %{
          title: "Lei 13.185 - Programa de Combate ao Bullying",
          description:
            "Apresente a legislacao brasileira sobre bullying e as responsabilidades da escola.",
          source: "Lei Federal 13.185/2015",
          source_url: "http://www.planalto.gov.br/ccivil_03/_ato2015-2018/2015/lei/l13185.htm"
        }
      ],
      transcription_summary:
        if(String.length(transcription_text) > 100,
          do: String.slice(transcription_text, 0, 200) <> "...",
          else: transcription_text
        )
    }
  end

  # ============================================================================
  # Helper functions for templates (must be defined before render/1)
  # ============================================================================

  defp word_count(nil), do: 0

  defp word_count(text) when is_binary(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end

  defp get_bncc_code(bncc) when is_map(bncc),
    do: Map.get(bncc, "code") || Map.get(bncc, :code, "")

  defp get_bncc_code(bncc) when is_binary(bncc), do: bncc
  defp get_bncc_code(_), do: ""

  defp get_alert_description(alert) when is_map(alert) do
    Map.get(alert, "description") || Map.get(alert, :description, "Alerta detectado")
  end

  defp get_alert_description(alert) when is_binary(alert), do: alert
  defp get_alert_description(_), do: "Alerta detectado"

  # Check if bncc_matches are available (from association or recovered from raw)
  defp bncc_matches_loaded?(%{bncc_matches: matches}) when is_list(matches), do: true
  defp bncc_matches_loaded?(%{result: %{"bncc_codes" => codes}}) when is_list(codes), do: true
  defp bncc_matches_loaded?(_), do: false

  # Get BNCC matches safely (from association or recovered from raw)
  defp get_bncc_matches(%{bncc_matches: matches}) when is_list(matches), do: matches

  defp get_bncc_matches(%{result: %{"bncc_codes" => codes}}) when is_list(codes),
    do: Enum.take(codes, 10)

  defp get_bncc_matches(_), do: []

  # Check if bullying_alerts are available (from association or recovered from raw)
  defp bullying_alerts_loaded?(%{bullying_alerts: alerts}) when is_list(alerts), do: true

  defp bullying_alerts_loaded?(%{result: %{"bullying_alert_data" => alerts}})
       when is_list(alerts),
       do: true

  defp bullying_alerts_loaded?(_), do: false

  # Get bullying alerts safely (from association or recovered from raw)
  defp get_bullying_alerts(%{bullying_alerts: alerts}) when is_list(alerts), do: alerts

  defp get_bullying_alerts(%{result: %{"bullying_alert_data" => alerts}}) when is_list(alerts),
    do: alerts

  defp get_bullying_alerts(_), do: []

  # Convert upload errors to human-readable strings
  defp error_to_string(:too_large), do: "Arquivo muito grande (max. 10MB)"
  defp error_to_string(:too_many_files), do: "Apenas um arquivo permitido"

  defp error_to_string(:not_accepted),
    do: "Tipo de arquivo nao aceito (PDF, DOCX, DOC, MD ou TXT)"

  defp error_to_string(err), do: "Erro: #{inspect(err)}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="animate-fade-in">
      <!-- Pending State -->
      <div :if={@lesson.status == "pending"} class="max-w-2xl mx-auto py-12">
        <.link
          navigate={~p"/aulas"}
          class="text-sm text-slate-500 dark:text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 flex items-center mb-6 transition-colors"
        >
          <.icon name="hero-arrow-left-mini" class="h-4 w-4 mr-1" /> Voltar para Minhas Aulas
        </.link>
        <.card>
          <div class="py-12 text-center">
            <div class="inline-flex items-center justify-center w-24 h-24 rounded-3xl bg-gradient-to-br from-teal-100 to-sage-100 dark:from-teal-900/30 dark:to-sage-900/30 mb-6">
              <.icon name="hero-play-circle" class="h-12 w-12 text-teal-600 dark:text-teal-400" />
            </div>
            <h2 class="text-2xl font-bold text-slate-900 dark:text-white mb-2">
              <%= @lesson.title || "Aula sem titulo" %>
            </h2>
            <p class="text-slate-500 dark:text-slate-400 mb-2">
              <%= @lesson.subject || "Disciplina nao informada" %>
            </p>
            <p class="text-sm text-slate-500 dark:text-slate-400 max-w-md mx-auto mb-8">
              Clique no botao abaixo para iniciar a transcricao e analise pedagogica da aula.
            </p>
            <.button phx-click="start_processing" icon="hero-play" size="lg">
              Iniciar Processamento
            </.button>
          </div>
        </.card>
      </div>
      <!-- Processing State -->
      <div :if={@lesson.status in ["transcribing", "analyzing"]} class="max-w-2xl mx-auto py-12">
        <.link
          navigate={~p"/aulas"}
          class="text-sm text-slate-500 dark:text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 flex items-center mb-6 transition-colors"
        >
          <.icon name="hero-arrow-left-mini" class="h-4 w-4 mr-1" /> Voltar para Minhas Aulas
        </.link>
        <.card>
          <div class="py-12 text-center">
            <div class="inline-flex items-center justify-center w-24 h-24 rounded-3xl bg-gradient-to-br from-cyan-100 to-teal-100 dark:from-cyan-900/30 dark:to-teal-900/30 mb-6">
              <.icon
                name="hero-arrow-path"
                class="h-12 w-12 text-cyan-600 dark:text-cyan-400 animate-spin"
              />
            </div>
            <h2 class="text-2xl font-bold text-slate-900 dark:text-white mb-2">
              <%= if @lesson.status == "transcribing", do: "Transcrevendo...", else: "Analisando..." %>
            </h2>
            <p class="text-slate-500 dark:text-slate-400 mb-6">
              <%= @lesson.title || "Aula sem titulo" %>
            </p>
            <p class="text-sm text-slate-500 dark:text-slate-400 max-w-md mx-auto mb-6">
              <%= if @lesson.status == "transcribing",
                do: "Convertendo audio em texto usando IA avancada",
                else: "Gerando feedback pedagogico baseado na BNCC" %>
            </p>
            <div class="max-w-sm mx-auto">
              <.progress
                value={assigns[:transcription_progress] || assigns[:analysis_progress] || 0}
                color="teal"
                size="lg"
              />
            </div>
          </div>
        </.card>
      </div>
      <!-- Failed State -->
      <div :if={@lesson.status == "failed"} class="max-w-2xl mx-auto py-12">
        <.link
          navigate={~p"/aulas"}
          class="text-sm text-slate-500 dark:text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 flex items-center mb-6 transition-colors"
        >
          <.icon name="hero-arrow-left-mini" class="h-4 w-4 mr-1" /> Voltar para Minhas Aulas
        </.link>
        <.alert variant="error" title="Erro no processamento">
          Ocorreu um erro ao processar esta aula. O credito foi reembolsado automaticamente.
          Voce pode tentar novamente.
        </.alert>
      </div>
      <!-- ============================================ -->
      <!-- COMPLETED STATE - NotebookLM Three-Panel Layout -->
      <!-- ============================================ -->
      <div :if={@lesson.status in ["transcribed", "completed"]} class="h-[calc(100vh-4rem)]">
        <!-- Three-Panel Container -->
        <div class="flex h-full gap-0">
          <!-- LEFT PANEL - Source/Audio Info (collapsible on mobile) -->
          <aside class="hidden lg:flex lg:flex-col w-72 xl:w-80 border-r border-slate-200 dark:border-slate-700 bg-slate-50/50 dark:bg-slate-900/50">
            <!-- Back Button & Title -->
            <div class="p-4 border-b border-slate-200 dark:border-slate-700">
              <.link
                navigate={~p"/aulas"}
                class="text-sm text-slate-500 dark:text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 flex items-center mb-3 transition-colors"
              >
                <.icon name="hero-arrow-left-mini" class="h-4 w-4 mr-1" /> Minhas Aulas
              </.link>
              <h1 class="text-lg font-bold text-slate-900 dark:text-white line-clamp-2">
                <%= @lesson.title || "Aula sem titulo" %>
              </h1>
            </div>
            <!-- Audio Source Card -->
            <div class="p-4 space-y-4 flex-1 overflow-y-auto">
              <!-- Source Info -->
              <div class="bg-white dark:bg-slate-800 rounded-xl p-4 shadow-sm border border-slate-200/50 dark:border-slate-700/50">
                <div class="flex items-center gap-3 mb-4">
                  <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-teal-500 to-sage-500 flex items-center justify-center">
                    <.icon name="hero-microphone" class="h-6 w-6 text-white" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-slate-900 dark:text-white truncate">
                      Gravacao de Audio
                    </p>
                    <p class="text-xs text-slate-500 dark:text-slate-400">
                      <%= format_datetime(@lesson.inserted_at) %>
                    </p>
                  </div>
                </div>
                <!-- Audio Player (if audio_url available) -->
                <div :if={@lesson.audio_url} class="bg-slate-100 dark:bg-slate-700/50 rounded-lg p-3">
                  <audio controls class="w-full h-8" preload="metadata">
                    <source src={@lesson.audio_url} type="audio/mpeg" />
                  </audio>
                </div>
              </div>
              <!-- Metadata -->
              <div class="space-y-3">
                <div class="flex items-center gap-3 text-sm">
                  <.icon name="hero-academic-cap" class="h-5 w-5 text-slate-400 dark:text-slate-500" />
                  <span class="text-slate-700 dark:text-slate-300">
                    <%= @lesson.subject || "Disciplina nao informada" %>
                  </span>
                </div>

                <div :if={@lesson.grade_level} class="flex items-center gap-3 text-sm">
                  <.icon name="hero-users" class="h-5 w-5 text-slate-400 dark:text-slate-500" />
                  <span class="text-slate-700 dark:text-slate-300"><%= @lesson.grade_level %></span>
                </div>

                <div :if={@lesson.duration_seconds} class="flex items-center gap-3 text-sm">
                  <.icon name="hero-clock" class="h-5 w-5 text-slate-400 dark:text-slate-500" />
                  <span class="text-slate-700 dark:text-slate-300">
                    <%= format_duration(@lesson.duration_seconds) %>
                  </span>
                </div>

                <div :if={@lesson.transcription} class="flex items-center gap-3 text-sm">
                  <.icon name="hero-document-text" class="h-5 w-5 text-slate-400 dark:text-slate-500" />
                  <span class="text-slate-700 dark:text-slate-300">
                    <%= word_count(@lesson.transcription.full_text) %> palavras
                  </span>
                </div>
              </div>
              <!-- Status Badge -->
              <div class="pt-3 border-t border-slate-200 dark:border-slate-700">
                <div class="flex items-center justify-between">
                  <span class="text-xs text-slate-500 dark:text-slate-400">Status</span>
                  <.badge variant={status_variant(@lesson.status)}>
                    <%= status_label(@lesson.status) %>
                  </.badge>
                </div>
              </div>
              <!-- Trend Indicator -->
              <div :if={assigns[:trend] && @lesson.status == "completed"}>
                <.trend_indicator trend={@trend} change={@trend_change} />
              </div>
            </div>
          </aside>
          <!-- CENTER PANEL - Transcript -->
          <main class="flex-1 flex flex-col min-w-0 bg-white dark:bg-slate-800">
            <!-- Mobile Header (visible on mobile/tablet) -->
            <div class="lg:hidden p-4 border-b border-slate-200 dark:border-slate-700">
              <.link
                navigate={~p"/aulas"}
                class="text-sm text-slate-500 dark:text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 flex items-center mb-2 transition-colors"
              >
                <.icon name="hero-arrow-left-mini" class="h-4 w-4 mr-1" /> Voltar
              </.link>
              <h1 class="text-lg font-bold text-slate-900 dark:text-white truncate">
                <%= @lesson.title || "Aula sem titulo" %>
              </h1>
              <div class="flex items-center gap-3 mt-2 text-sm text-slate-500 dark:text-slate-400">
                <span><%= @lesson.subject || "Sem disciplina" %></span>
                <.badge variant={status_variant(@lesson.status)} class="text-xs">
                  <%= status_label(@lesson.status) %>
                </.badge>
              </div>
            </div>
            <!-- Tabs Header -->
            <div class="border-b border-slate-200 dark:border-slate-700 bg-slate-50/50 dark:bg-slate-800/50">
              <div class="flex items-center gap-1 px-4">
                <button
                  phx-click="switch_tab"
                  phx-value-tab="transcription"
                  class={"px-4 py-3 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "transcription", do: "border-teal-500 text-teal-600 dark:text-teal-400", else: "border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300"}"}
                >
                  <.icon name="hero-document-text" class="h-4 w-4 inline mr-1.5" /> Transcricao
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="planned"
                  class={"px-4 py-3 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "planned", do: "border-violet-500 text-violet-600 dark:text-violet-400", else: "border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300"}"}
                >
                  <.icon name="hero-clipboard-document-list" class="h-4 w-4 inline mr-1.5" /> Material
                  Planejado
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="suggestions"
                  class={"px-4 py-3 text-sm font-medium border-b-2 transition-colors #{if @active_tab == "suggestions", do: "border-amber-500 text-amber-600 dark:text-amber-400", else: "border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300"}"}
                >
                  <.icon name="hero-light-bulb" class="h-4 w-4 inline mr-1.5" /> Sugestoes
                </button>
              </div>
            </div>
            <!-- Tab Content -->
            <div class="flex-1 overflow-y-auto">
              <!-- Transcription Tab -->
              <div :if={@active_tab == "transcription"} class="p-4">
                <div
                  :if={@lesson.transcription}
                  class="bg-slate-50 dark:bg-slate-900/50 rounded-xl p-4 border border-slate-200 dark:border-slate-700"
                >
                  <p class="text-sm leading-relaxed text-slate-600 dark:text-slate-400 whitespace-pre-wrap max-h-[60vh] overflow-y-auto">
                    <%= @lesson.transcription.full_text %>
                  </p>
                </div>
                <div :if={!@lesson.transcription} class="text-center py-12">
                  <.icon
                    name="hero-document-text"
                    class="mx-auto h-12 w-12 text-slate-200 dark:text-slate-700"
                  />
                  <p class="mt-3 text-sm text-slate-500 dark:text-slate-400">
                    Transcricao nao disponivel
                  </p>
                </div>
              </div>
              <!-- Planned Material Tab -->
              <div :if={@active_tab == "planned"} class="p-6">
                <div class="mb-4 flex items-center justify-between">
                  <div>
                    <h3 class="text-sm font-semibold text-slate-900 dark:text-white">
                      Material Planejado
                    </h3>
                    <p class="text-xs text-slate-500 dark:text-slate-400">
                      Descreva o conteudo que deveria ser abordado nesta aula
                    </p>
                  </div>
                  <div :if={!@editing_planned && @lesson.planned_content}>
                    <button
                      phx-click="edit_planned"
                      class="text-sm text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300 font-medium"
                    >
                      <.icon name="hero-pencil" class="h-4 w-4 inline mr-1" /> Editar
                    </button>
                  </div>
                </div>
                <!-- View Mode -->
                <div
                  :if={!@editing_planned && @lesson.planned_content}
                  class="prose prose-slate dark:prose-invert max-w-none"
                >
                  <div class="bg-violet-50 dark:bg-violet-900/20 rounded-xl p-4 border border-violet-200 dark:border-violet-800/50">
                    <p class="text-base leading-relaxed text-slate-700 dark:text-slate-300 whitespace-pre-wrap">
                      <%= @lesson.planned_content %>
                    </p>
                  </div>
                </div>
                <!-- Edit Mode or Empty State -->
                <div :if={@editing_planned || !@lesson.planned_content}>
                  <form phx-change="update_planned_content" phx-submit="save_planned_content">
                    <textarea
                      name="planned_content"
                      rows="8"
                      class="w-full px-4 py-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-violet-500 focus:border-transparent resize-none text-sm"
                      placeholder="Descreva o conteudo planejado para esta aula. Ex: Objetivo, conteudos BNCC, atividades..."
                    ><%= @planned_content %></textarea>
                    <div class="mt-4 flex items-center gap-3">
                      <button
                        type="submit"
                        class="px-4 py-2 bg-violet-600 hover:bg-violet-700 text-white text-sm font-medium rounded-lg transition-colors"
                      >
                        <.icon name="hero-check" class="h-4 w-4 inline mr-1" /> Salvar
                      </button>
                      <button
                        :if={@editing_planned}
                        type="button"
                        phx-click="cancel_edit_planned"
                        class="px-4 py-2 text-slate-600 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200 text-sm font-medium transition-colors"
                      >
                        Cancelar
                      </button>
                      <button
                        type="button"
                        phx-click="generate_suggestions"
                        disabled={@generating_suggestions}
                        class="ml-auto px-4 py-2 bg-amber-500 hover:bg-amber-600 disabled:bg-amber-300 text-white text-sm font-medium rounded-lg transition-colors flex items-center gap-2"
                      >
                        <.icon
                          name={
                            if @generating_suggestions, do: "hero-arrow-path", else: "hero-sparkles"
                          }
                          class={"h-4 w-4 #{if @generating_suggestions, do: "animate-spin"}"}
                        />
                        <%= if @generating_suggestions,
                          do: "Gerando...",
                          else: "Gerar Sugestoes com IA" %>
                      </button>
                    </div>
                  </form>
                </div>
                <!-- File Upload Section -->
                <div class="mt-6 pt-6 border-t border-slate-200 dark:border-slate-700">
                  <h4 class="text-sm font-medium text-slate-900 dark:text-white mb-3">
                    <.icon name="hero-paper-clip" class="h-4 w-4 inline mr-1" /> Anexar Arquivo
                  </h4>
                  <!-- Current File Display -->
                  <div
                    :if={@lesson.planned_file_url}
                    class="mb-4 p-3 bg-teal-50 dark:bg-teal-900/20 rounded-lg border border-teal-200 dark:border-teal-800/50 flex items-center justify-between"
                  >
                    <div class="flex items-center gap-3">
                      <div class="w-10 h-10 rounded-lg bg-teal-100 dark:bg-teal-900/50 flex items-center justify-center">
                        <.icon name="hero-document" class="h-5 w-5 text-teal-600 dark:text-teal-400" />
                      </div>
                      <div>
                        <a
                          href={@lesson.planned_file_url}
                          target="_blank"
                          class="text-sm font-medium text-teal-700 dark:text-teal-300 hover:underline"
                        >
                          <%= @lesson.planned_file_name %>
                        </a>
                        <p class="text-xs text-teal-600 dark:text-teal-400">Clique para abrir</p>
                      </div>
                    </div>
                    <button
                      type="button"
                      phx-click="remove_planned_file"
                      class="p-2 text-red-500 hover:text-red-700 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
                    >
                      <.icon name="hero-trash" class="h-4 w-4" />
                    </button>
                  </div>
                  <!-- Upload Form -->
                  <form phx-change="validate_file" phx-submit="upload_planned_file">
                    <.live_file_input upload={@uploads.planned_file} class="sr-only" />
                    <label
                      for={@uploads.planned_file.ref}
                      class="flex flex-col items-center justify-center w-full h-24 border-2 border-dashed border-slate-300 dark:border-slate-600 rounded-xl cursor-pointer hover:border-violet-400 dark:hover:border-violet-500 hover:bg-violet-50/50 dark:hover:bg-violet-900/10 transition-colors"
                    >
                      <div class="flex flex-col items-center justify-center py-4">
                        <.icon
                          name="hero-cloud-arrow-up"
                          class="h-8 w-8 text-slate-400 dark:text-slate-500 mb-1"
                        />
                        <p class="text-sm text-slate-500 dark:text-slate-400">
                          <span class="font-medium text-violet-600 dark:text-violet-400">
                            Clique para selecionar
                          </span>
                          ou arraste o arquivo
                        </p>
                        <p class="text-xs text-slate-400 dark:text-slate-500">
                          PDF, DOCX, DOC, MD ou TXT (max. 10MB)
                        </p>
                      </div>
                    </label>
                    <!-- Upload Progress -->
                    <div :for={entry <- @uploads.planned_file.entries} class="mt-3">
                      <div class="flex items-center gap-3 p-3 bg-slate-50 dark:bg-slate-800 rounded-lg">
                        <.icon name="hero-document" class="h-5 w-5 text-violet-500" />
                        <div class="flex-1 min-w-0">
                          <p class="text-sm font-medium text-slate-900 dark:text-white truncate">
                            <%= entry.client_name %>
                          </p>
                          <div class="w-full bg-slate-200 dark:bg-slate-700 rounded-full h-1.5 mt-1">
                            <div
                              class="bg-violet-500 h-1.5 rounded-full transition-all"
                              style={"width: #{entry.progress}%"}
                            >
                            </div>
                          </div>
                        </div>
                        <span class="text-xs text-slate-500"><%= entry.progress %>%</span>
                      </div>
                      <!-- Errors -->
                      <div :for={err <- upload_errors(@uploads.planned_file, entry)} class="mt-2">
                        <p class="text-sm text-red-500">
                          <%= error_to_string(err) %>
                        </p>
                      </div>
                    </div>
                    <!-- Submit Button -->
                    <button
                      :if={length(@uploads.planned_file.entries) > 0}
                      type="submit"
                      class="mt-3 w-full px-4 py-2 bg-violet-600 hover:bg-violet-700 text-white text-sm font-medium rounded-lg transition-colors"
                    >
                      <.icon name="hero-arrow-up-tray" class="h-4 w-4 inline mr-1" /> Enviar Arquivo
                    </button>
                  </form>
                </div>
              </div>
              <!-- Suggestions Tab -->
              <div :if={@active_tab == "suggestions"} class="p-6">
                <div class="mb-4">
                  <h3 class="text-sm font-semibold text-slate-900 dark:text-white">
                    Sugestoes da IA
                  </h3>
                  <p class="text-xs text-slate-500 dark:text-slate-400">
                    Recomendacoes de conteudo baseadas na transcricao e no material planejado
                  </p>
                </div>
                <!-- No suggestions yet -->
                <div
                  :if={!assigns[:ai_suggestions] || @ai_suggestions == []}
                  class="text-center py-12"
                >
                  <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-amber-100 dark:bg-amber-900/30 mb-4">
                    <.icon name="hero-light-bulb" class="h-8 w-8 text-amber-500" />
                  </div>
                  <p class="text-slate-600 dark:text-slate-400 mb-4">
                    Nenhuma sugestao gerada ainda
                  </p>
                  <button
                    phx-click="generate_suggestions"
                    disabled={@generating_suggestions}
                    class="px-4 py-2 bg-amber-500 hover:bg-amber-600 disabled:bg-amber-300 text-white text-sm font-medium rounded-lg transition-colors inline-flex items-center gap-2"
                  >
                    <.icon
                      name={if @generating_suggestions, do: "hero-arrow-path", else: "hero-sparkles"}
                      class={"h-4 w-4 #{if @generating_suggestions, do: "animate-spin"}"}
                    />
                    <%= if @generating_suggestions, do: "Gerando...", else: "Gerar Sugestoes" %>
                  </button>
                </div>
                <!-- Suggestions List -->
                <div :if={assigns[:ai_suggestions] && @ai_suggestions != []} class="space-y-4">
                  <div
                    :for={suggestion <- @ai_suggestions}
                    class="bg-white dark:bg-slate-700/50 rounded-xl p-4 border border-slate-200 dark:border-slate-600 hover:border-amber-300 dark:hover:border-amber-700 transition-colors"
                  >
                    <div class="flex items-start gap-3">
                      <div class="w-8 h-8 rounded-lg bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center flex-shrink-0">
                        <.icon
                          name="hero-light-bulb"
                          class="h-4 w-4 text-amber-600 dark:text-amber-400"
                        />
                      </div>
                      <div class="flex-1 min-w-0">
                        <h4 class="text-sm font-semibold text-slate-900 dark:text-white mb-1">
                          <%= suggestion.title %>
                        </h4>
                        <p class="text-sm text-slate-600 dark:text-slate-400 mb-2">
                          <%= suggestion.description %>
                        </p>
                        <a
                          href={suggestion.source_url}
                          target="_blank"
                          rel="noopener"
                          class="inline-flex items-center gap-1 text-xs text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300"
                        >
                          <.icon name="hero-link" class="h-3 w-3" />
                          <%= suggestion.source %>
                        </a>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </main>
          <!-- RIGHT PANEL - Analysis & Insights -->
          <aside class="hidden md:flex md:flex-col w-80 xl:w-96 border-l border-slate-200 dark:border-slate-700 bg-slate-50/50 dark:bg-slate-900/50">
            <!-- Panel Header -->
            <div class="p-4 border-b border-slate-200 dark:border-slate-700">
              <div class="flex items-center gap-2">
                <.icon name="hero-sparkles" class="h-5 w-5 text-violet-600 dark:text-violet-400" />
                <h2 class="font-semibold text-slate-900 dark:text-white">Insights da IA</h2>
              </div>
            </div>
            <!-- Analysis Content -->
            <div class="flex-1 overflow-y-auto p-4 space-y-4">
              <!-- Score Display -->
              <div
                :if={@latest_analysis && @latest_analysis.overall_score}
                class="bg-white dark:bg-slate-800 rounded-xl p-6 shadow-sm border border-slate-200/50 dark:border-slate-700/50"
              >
                <div class="flex items-center justify-center">
                  <.score_display
                    score={round(@latest_analysis.overall_score * 100)}
                    label="Pontuacao Geral"
                    size="lg"
                  />
                </div>
              </div>
              <!-- BNCC Competencies as Chips -->
              <div
                :if={
                  @latest_analysis && bncc_matches_loaded?(@latest_analysis) &&
                    length(get_bncc_matches(@latest_analysis)) > 0
                }
                class="bg-white dark:bg-slate-800 rounded-xl p-4 shadow-sm border border-slate-200/50 dark:border-slate-700/50"
              >
                <div class="flex items-center gap-2 mb-3">
                  <.icon
                    name="hero-academic-cap"
                    class="h-4 w-4 text-violet-600 dark:text-violet-400"
                  />
                  <h3 class="text-sm font-semibold text-slate-900 dark:text-white">
                    Competencias BNCC
                  </h3>
                </div>
                <div class="flex flex-wrap gap-2">
                  <span
                    :for={bncc <- get_bncc_matches(@latest_analysis)}
                    class="group relative inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-violet-100 dark:bg-violet-900/30 text-violet-700 dark:text-violet-300 cursor-help transition-all hover:bg-violet-200 dark:hover:bg-violet-800/50 hover:scale-105"
                  >
                    <%= get_bncc_code(bncc) %>
                    <!-- Tooltip -->
                    <span class="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-3 py-2 bg-slate-900 dark:bg-slate-700 text-white text-xs rounded-lg opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 whitespace-nowrap z-50 shadow-lg max-w-xs">
                      <span class="font-semibold"><%= get_bncc_code(bncc) %></span>
                      <br />
                      <span class="text-slate-300">
                        <%= BNCC.get_description(get_bncc_code(bncc)) %>
                      </span>
                      <!-- Arrow -->
                      <span class="absolute top-full left-1/2 -translate-x-1/2 border-4 border-transparent border-t-slate-900 dark:border-t-slate-700">
                      </span>
                    </span>
                  </span>
                </div>
              </div>
              <!-- User BNCC Coverage -->
              <div
                :if={assigns[:bncc_coverage] && length(@bncc_coverage) > 0}
                class="bg-white dark:bg-slate-800 rounded-xl p-4 shadow-sm border border-slate-200/50 dark:border-slate-700/50"
              >
                <div class="flex items-center gap-2 mb-3">
                  <.icon name="hero-chart-bar" class="h-4 w-4 text-teal-600 dark:text-teal-400" />
                  <h3 class="text-sm font-semibold text-slate-900 dark:text-white">
                    Seu Historico BNCC
                  </h3>
                </div>
                <div class="space-y-2">
                  <div :for={comp <- Enum.take(@bncc_coverage, 5)} class="flex items-center gap-2">
                    <span class="text-xs font-mono text-teal-600 dark:text-teal-400 w-20 truncate">
                      <%= comp.code %>
                    </span>
                    <div class="flex-1 h-2 bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden">
                      <div
                        class="h-full bg-gradient-to-r from-teal-500 to-sage-500 rounded-full"
                        style={"width: #{round((comp.avg_score || 0) * 100)}%"}
                      >
                      </div>
                    </div>
                    <span class="text-xs text-slate-500 dark:text-slate-400 w-8 text-right">
                      <%= comp.count %>x
                    </span>
                  </div>
                </div>
              </div>
              <!-- Feedback -->
              <div
                :if={
                  @latest_analysis && @latest_analysis.result && @latest_analysis.result["feedback"]
                }
                class="bg-cyan-50 dark:bg-cyan-900/20 rounded-xl p-4 border border-cyan-200/50 dark:border-cyan-800/50"
              >
                <div class="flex items-center gap-2 mb-2">
                  <.icon
                    name="hero-chat-bubble-left-right"
                    class="h-4 w-4 text-cyan-600 dark:text-cyan-400"
                  />
                  <h3 class="text-sm font-semibold text-cyan-800 dark:text-cyan-200">Feedback</h3>
                </div>
                <p class="text-sm text-cyan-700 dark:text-cyan-300 leading-relaxed">
                  <%= @latest_analysis.result["feedback"] %>
                </p>
              </div>
              <!-- Strengths -->
              <div
                :if={
                  @latest_analysis && @latest_analysis.result && @latest_analysis.result["strengths"]
                }
                class="bg-emerald-50 dark:bg-emerald-900/20 rounded-xl p-4 border border-emerald-200/50 dark:border-emerald-800/50"
              >
                <div class="flex items-center gap-2 mb-3">
                  <.icon
                    name="hero-check-circle"
                    class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                  />
                  <h3 class="text-sm font-semibold text-emerald-800 dark:text-emerald-200">
                    Pontos Fortes
                  </h3>
                </div>
                <ul class="space-y-2">
                  <li
                    :for={strength <- @latest_analysis.result["strengths"]}
                    class="flex items-start gap-2 text-sm text-emerald-700 dark:text-emerald-300"
                  >
                    <.icon
                      name="hero-check-mini"
                      class="h-4 w-4 mt-0.5 flex-shrink-0 text-emerald-500"
                    />
                    <span><%= strength %></span>
                  </li>
                </ul>
              </div>
              <!-- Improvements -->
              <div
                :if={
                  @latest_analysis && @latest_analysis.result &&
                    @latest_analysis.result["improvements"]
                }
                class="bg-amber-50 dark:bg-amber-900/20 rounded-xl p-4 border border-amber-200/50 dark:border-amber-800/50"
              >
                <div class="flex items-center gap-2 mb-3">
                  <.icon name="hero-light-bulb" class="h-4 w-4 text-amber-600 dark:text-amber-400" />
                  <h3 class="text-sm font-semibold text-amber-800 dark:text-amber-200">
                    Sugestoes de Melhoria
                  </h3>
                </div>
                <ul class="space-y-2">
                  <li
                    :for={improvement <- @latest_analysis.result["improvements"]}
                    class="flex items-start gap-2 text-sm text-amber-700 dark:text-amber-300"
                  >
                    <.icon
                      name="hero-arrow-right-mini"
                      class="h-4 w-4 mt-0.5 flex-shrink-0 text-amber-500"
                    />
                    <span><%= improvement %></span>
                  </li>
                </ul>
              </div>
              <!-- Bullying Alerts -->
              <div
                :if={
                  @latest_analysis && bullying_alerts_loaded?(@latest_analysis) &&
                    length(get_bullying_alerts(@latest_analysis)) > 0
                }
                class="bg-red-50 dark:bg-red-900/20 rounded-xl p-4 border border-red-200/50 dark:border-red-800/50"
              >
                <div class="flex items-center gap-2 mb-3">
                  <.icon
                    name="hero-exclamation-triangle"
                    class="h-4 w-4 text-red-600 dark:text-red-400"
                  />
                  <h3 class="text-sm font-semibold text-red-800 dark:text-red-200">
                    Alertas (Lei 13.185)
                  </h3>
                </div>
                <ul class="space-y-2">
                  <li
                    :for={alert <- get_bullying_alerts(@latest_analysis)}
                    class="flex items-start gap-2 text-sm text-red-700 dark:text-red-300"
                  >
                    <.icon
                      name="hero-exclamation-circle-mini"
                      class="h-4 w-4 mt-0.5 flex-shrink-0 text-red-500"
                    />
                    <span><%= get_alert_description(alert) %></span>
                  </li>
                </ul>
              </div>
              <!-- Score Evolution Chart (collapsible) -->
              <div
                :if={assigns[:score_history] && length(@score_history) > 1}
                class="bg-white dark:bg-slate-800 rounded-xl p-4 shadow-sm border border-slate-200/50 dark:border-slate-700/50"
              >
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-2">
                    <.icon
                      name="hero-arrow-trending-up"
                      class="h-4 w-4 text-teal-600 dark:text-teal-400"
                    />
                    <h3 class="text-sm font-semibold text-slate-900 dark:text-white">
                      Evolucao do Score
                    </h3>
                  </div>
                  <.trend_badge :if={assigns[:trend]} trend={@trend} change={@trend_change} />
                </div>
                <div
                  id="score-chart"
                  phx-hook="ScoreChart"
                  phx-update="ignore"
                  data-chart-data={Jason.encode!(@score_history)}
                  data-average={@discipline_avg || 0}
                  class="h-40"
                >
                </div>
              </div>
              <!-- No Analysis or Failed Parse State -->
              <div
                :if={
                  !@latest_analysis ||
                    (!@latest_analysis.overall_score && !@latest_analysis.result["feedback"])
                }
                class="text-center py-8"
              >
                <.icon
                  name="hero-document-magnifying-glass"
                  class="mx-auto h-12 w-12 text-slate-300 dark:text-slate-600"
                />
                <p class="mt-3 text-sm text-slate-500 dark:text-slate-400">
                  <%= if @latest_analysis && @latest_analysis.result["error"] do %>
                    Erro ao processar analise. Os dados brutos foram salvos.
                  <% else %>
                    Analise nao disponivel
                  <% end %>
                </p>
              </div>
            </div>
          </aside>
        </div>
        <!-- Mobile Bottom Navigation (Analysis Tab for mobile) -->
        <div class="md:hidden fixed bottom-0 left-0 right-0 bg-white dark:bg-slate-800 border-t border-slate-200 dark:border-slate-700 px-4 py-2 z-50">
          <div class="flex items-center justify-around">
            <button
              type="button"
              phx-click={JS.show(to: "#mobile-transcript") |> JS.hide(to: "#mobile-analysis")}
              class="flex flex-col items-center gap-1 px-4 py-2 text-teal-600 dark:text-teal-400"
            >
              <.icon name="hero-document-text" class="h-5 w-5" />
              <span class="text-xs font-medium">Transcricao</span>
            </button>
            <button
              type="button"
              phx-click={JS.show(to: "#mobile-analysis") |> JS.hide(to: "#mobile-transcript")}
              class="flex flex-col items-center gap-1 px-4 py-2 text-slate-500 dark:text-slate-400"
            >
              <.icon name="hero-sparkles" class="h-5 w-5" />
              <span class="text-xs font-medium">Insights</span>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Trend indicator component
  defp trend_indicator(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium transition-colors",
      @trend == :improving &&
        "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400",
      @trend == :declining && "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400",
      @trend == :stable && "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400"
    ]}>
      <.icon
        :if={@trend == :improving}
        name="hero-arrow-trending-up"
        class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
      />
      <.icon
        :if={@trend == :declining}
        name="hero-arrow-trending-down"
        class="h-4 w-4 text-red-600 dark:text-red-400"
      />
      <.icon
        :if={@trend == :stable}
        name="hero-minus"
        class="h-4 w-4 text-slate-500 dark:text-slate-400"
      />
      <span :if={abs(@change) > 0}>
        <%= if @change > 0, do: "+", else: "" %><%= Float.round(@change, 1) %>%
      </span>
    </div>
    """
  end

  # Trend badge for chart header
  defp trend_badge(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-1.5 px-2 py-1 rounded-lg text-xs font-medium transition-colors",
      @trend == :improving &&
        "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400",
      @trend == :declining && "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400",
      @trend == :stable && "bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400"
    ]}>
      <.icon
        :if={@trend == :improving}
        name="hero-arrow-trending-up"
        class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
      />
      <.icon
        :if={@trend == :declining}
        name="hero-arrow-trending-down"
        class="h-4 w-4 text-red-600 dark:text-red-400"
      />
      <.icon
        :if={@trend == :stable}
        name="hero-minus"
        class="h-4 w-4 text-slate-500 dark:text-slate-400"
      />
      <span>
        <%= case @trend do
          :improving -> "Melhorando"
          :declining -> "Em queda"
          :stable -> "Estavel"
        end %>
      </span>
    </div>
    """
  end
end
