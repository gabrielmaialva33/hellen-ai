defmodule HellenWeb.LessonLive.Show do
  use HellenWeb, :live_view

  alias Hellen.Analysis
  alias Hellen.Lessons

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    lesson = Lessons.get_lesson_with_transcription!(id)
    analyses = Analysis.list_analyses_by_lesson(id)
    latest_analysis = List.first(analyses)

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
     |> assign(show_analysis: socket.assigns.live_action == :analysis)}
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
    # Reload lesson with transcription
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

  # Catch-all for any other PubSub messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

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
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex justify-between items-start">
        <div>
          <.link
            navigate={~p"/"}
            class="text-sm text-gray-500 hover:text-gray-700 flex items-center mb-2"
          >
            <.icon name="hero-arrow-left-mini" class="h-4 w-4 mr-1" /> Voltar ao Dashboard
          </.link>
          <h1 class="text-2xl font-bold text-gray-900">
            <%= @lesson.title || "Aula sem título" %>
          </h1>
          <p class="mt-1 text-sm text-gray-500">
            <%= @lesson.subject || "Disciplina não informada" %> • <%= format_date(
              @lesson.inserted_at
            ) %>
          </p>
        </div>
        <.badge variant={status_variant(@lesson.status)} class="text-sm px-3 py-1">
          <%= status_label(@lesson.status) %>
        </.badge>
      </div>

      <div :if={@lesson.status == "pending"} class="text-center py-8">
        <.card>
          <div class="py-6">
            <.icon name="hero-play-circle" class="mx-auto h-16 w-16 text-indigo-400" />
            <h3 class="mt-4 text-lg font-semibold text-gray-900">Pronto para processar</h3>
            <p class="mt-2 text-sm text-gray-500">
              Clique no botão abaixo para iniciar a transcrição e análise da aula.
            </p>
            <div class="mt-6">
              <.button phx-click="start_processing">
                <.icon name="hero-play" class="h-4 w-4 mr-2" /> Iniciar Processamento
              </.button>
            </div>
          </div>
        </.card>
      </div>

      <div :if={@lesson.status in ["transcribing", "analyzing"]} class="text-center py-8">
        <.card>
          <div class="py-6">
            <div class="mx-auto h-16 w-16 text-indigo-400 animate-spin">
              <.icon name="hero-arrow-path" class="h-16 w-16" />
            </div>
            <h3 class="mt-4 text-lg font-semibold text-gray-900">
              <%= if @lesson.status == "transcribing", do: "Transcrevendo...", else: "Analisando..." %>
            </h3>
            <p class="mt-2 text-sm text-gray-500">
              <%= if @lesson.status == "transcribing",
                do: "Convertendo áudio em texto usando IA",
                else: "Gerando feedback pedagógico baseado na BNCC" %>
            </p>
            <div class="mt-6 max-w-md mx-auto">
              <.progress value={assigns[:transcription_progress] || assigns[:analysis_progress] || 0} />
            </div>
          </div>
        </.card>
      </div>

      <div :if={@lesson.status == "failed"}>
        <.alert variant="error" title="Erro no processamento">
          Ocorreu um erro ao processar esta aula. O crédito foi reembolsado automaticamente.
          Você pode tentar novamente.
        </.alert>
      </div>

      <div
        :if={@lesson.status in ["transcribed", "completed"]}
        class="grid grid-cols-1 lg:grid-cols-2 gap-8"
      >
        <.card>
          <:header>
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-gray-900">Transcrição</h2>
              <.badge variant="success">Concluída</.badge>
            </div>
          </:header>
          <div :if={@lesson.transcription} class="prose prose-sm max-w-none max-h-96 overflow-y-auto">
            <p class="whitespace-pre-wrap text-gray-700">
              <%= @lesson.transcription.full_text %>
            </p>
          </div>
          <div :if={!@lesson.transcription} class="text-gray-500 text-sm">
            Transcrição não disponível
          </div>
        </.card>

        <.card>
          <:header>
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-gray-900">Análise Pedagógica</h2>
              <.badge :if={@latest_analysis} variant="success">Concluída</.badge>
              <.badge :if={!@latest_analysis && @lesson.status == "completed"} variant="pending">
                Pendente
              </.badge>
            </div>
          </:header>

          <div :if={@latest_analysis} class="space-y-4">
            <div :if={@latest_analysis.overall_score} class="flex items-center justify-center">
              <div class="text-center">
                <div class="text-4xl font-bold text-indigo-600">
                  <%= round(@latest_analysis.overall_score * 100) %>%
                </div>
                <div class="text-sm text-gray-500">Pontuação Geral</div>
              </div>
            </div>

            <div :if={@latest_analysis.result} class="space-y-4">
              <.analysis_section
                :if={@latest_analysis.result["feedback"]}
                title="Feedback"
                icon="hero-chat-bubble-left-right"
              >
                <%= @latest_analysis.result["feedback"] %>
              </.analysis_section>

              <.analysis_section
                :if={@latest_analysis.result["strengths"]}
                title="Pontos Fortes"
                icon="hero-check-circle"
              >
                <ul class="list-disc list-inside space-y-1">
                  <li :for={strength <- @latest_analysis.result["strengths"]} class="text-sm">
                    <%= strength %>
                  </li>
                </ul>
              </.analysis_section>

              <.analysis_section
                :if={@latest_analysis.result["improvements"]}
                title="Sugestões de Melhoria"
                icon="hero-light-bulb"
              >
                <ul class="list-disc list-inside space-y-1">
                  <li :for={improvement <- @latest_analysis.result["improvements"]} class="text-sm">
                    <%= improvement %>
                  </li>
                </ul>
              </.analysis_section>
            </div>
          </div>

          <div :if={!@latest_analysis} class="text-center py-6 text-gray-500">
            <.icon name="hero-document-magnifying-glass" class="mx-auto h-12 w-12 text-gray-300" />
            <p class="mt-2 text-sm">Análise não disponível</p>
          </div>
        </.card>
      </div>
    </div>
    """
  end

  defp analysis_section(assigns) do
    ~H"""
    <div class="border-t pt-4 first:border-t-0 first:pt-0">
      <h3 class="flex items-center text-sm font-medium text-gray-900 mb-2">
        <.icon name={@icon} class="h-4 w-4 mr-2 text-indigo-500" />
        <%= @title %>
      </h3>
      <div class="text-sm text-gray-600">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  defp status_variant("pending"), do: "pending"
  defp status_variant("transcribing"), do: "processing"
  defp status_variant("transcribed"), do: "processing"
  defp status_variant("analyzing"), do: "processing"
  defp status_variant("completed"), do: "completed"
  defp status_variant("failed"), do: "failed"
  defp status_variant(_), do: "default"

  defp status_label("pending"), do: "Pendente"
  defp status_label("transcribing"), do: "Transcrevendo"
  defp status_label("transcribed"), do: "Analisando"
  defp status_label("analyzing"), do: "Analisando"
  defp status_label("completed"), do: "Concluído"
  defp status_label("failed"), do: "Falhou"
  defp status_label(_), do: "Desconhecido"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y às %H:%M")
  end
end
