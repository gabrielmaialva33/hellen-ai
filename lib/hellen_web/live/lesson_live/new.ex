defmodule HellenWeb.LessonLive.New do
  use HellenWeb, :live_view

  alias Hellen.Lessons
  alias Hellen.Storage

  # 500MB
  @max_file_size 500 * 1024 * 1024
  @accepted_types ~w(.mp3 .mp4 .m4a .wav .webm .ogg .flac .mov .avi .mkv)

  @impl true

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Nova Aula")
     |> assign(form: to_form(%{"title" => "", "subject" => ""}, as: :lesson))
     |> assign(uploading: false)
     |> assign(upload_state: :empty)
     |> assign(step: :upload)
     |> assign(lesson: nil)
     |> assign(transcription_progress: 0)
     |> allow_upload(:media,
       accept: @accepted_types,
       max_entries: 1,
       max_file_size: @max_file_size,
       auto_upload: true
     )}
  end

  @impl true
  def handle_event("validate", %{"lesson" => params}, socket) do
    form = to_form(params, as: :lesson)
    {:noreply, assign(socket, form: form)}
  end

  # Handle validate event without lesson params (e.g., file selection only)
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit", params, socket) do
    handle_submit(socket.assigns.step, params, socket)
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  @impl true
  def handle_event("online", _params, socket) do
    {:noreply, socket}
  end

  defp handle_submit(:upload, params, socket) do
    require Logger
    Logger.info("Submit upload step with params: #{inspect(params)}")

    user = socket.assigns.current_user
    lesson_params = Map.get(params, "lesson", %{})
    socket = assign(socket, uploading: true)

    try do
      result = upload_and_create_lesson(socket, user, lesson_params)
      handle_upload_result(result, user, socket)
    rescue
      e ->
        Logger.error("Exception in submit: #{inspect(e)}")
        Logger.error("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")

        {:noreply,
         socket |> assign(uploading: false) |> put_flash(:error, "Erro inesperado: #{inspect(e)}")}
    end
  end

  defp handle_submit(:details, %{"lesson" => lesson_params}, socket) do
    case Lessons.update_lesson(socket.assigns.lesson, lesson_params) do
      {:ok, lesson} ->
        {:noreply,
         socket
         |> put_flash(:info, "Aula configurada com sucesso!")
         |> push_navigate(to: ~p"/lessons/#{lesson.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp handle_upload_result({:ok, lesson}, user, socket) do
    require Logger

    case Lessons.start_processing(lesson, user) do
      {:ok, updated_lesson} ->
        if connected?(socket),
          do: Phoenix.PubSub.subscribe(Hellen.PubSub, "lesson:#{updated_lesson.id}")

        finish_upload_success(socket, lesson, updated_lesson)

      {:error, :insufficient_credits} ->
        {:noreply,
         socket
         |> assign(uploading: false)
         |> put_flash(:error, "Créditos insuficientes para processar a aula.")}

      {:error, reason} ->
        Logger.error("Processing start error: #{inspect(reason)}")

        {:noreply,
         socket
         |> assign(uploading: false)
         |> put_flash(:error, "Erro ao iniciar processamento: #{inspect(reason)}")}
    end
  end

  defp handle_upload_result({:error, :insufficient_credits}, _user, socket) do
    {:noreply,
     socket
     |> assign(uploading: false)
     |> put_flash(
       :error,
       "Você não tem créditos suficientes. Adquira mais créditos para continuar."
     )}
  end

  defp handle_upload_result({:error, :no_file_uploaded}, _user, socket) do
    {:noreply,
     socket
     |> assign(uploading: false)
     |> put_flash(:error, "Selecione um arquivo para continuar.")}
  end

  defp handle_upload_result({:error, reason}, _user, socket) do
    require Logger
    Logger.error("Upload error: #{inspect(reason)}")

    {:noreply,
     socket
     |> assign(uploading: false)
     |> put_flash(:error, "Erro ao criar aula: #{inspect(reason)}")}
  end

  defp finish_upload_success(socket, lesson, updated_lesson) do
    {:noreply,
     socket
     |> assign(uploading: false)
     |> assign(
       form: to_form(%{"title" => lesson.title, "subject" => lesson.subject}, as: :lesson)
     )
     |> assign(lesson: updated_lesson)
     |> assign(step: :details)
     |> put_flash(:info, "Upload concluído! Preencha os detalhes enquanto processamos.")}
  end

  @impl true
  def handle_info({"transcription_progress", %{progress: progress}}, socket) do
    {:noreply, assign(socket, transcription_progress: progress)}
  end

  @impl true
  def handle_info({"transcription_complete", _payload}, socket) do
    # You might want to auto-advance or just show 100%
    {:noreply, assign(socket, transcription_progress: 100)}
  end

  @impl true
  def handle_info({"transcription_failed", %{error: error}}, socket) do
    {:noreply, put_flash(socket, :error, "Transcrição falhou: #{error}")}
  end

  @impl true
  def handle_info({"analysis_quick_update", payload}, socket) do
    urgency = payload.urgency || "BAIXA"

    message =
      case urgency do
        "ALTA" -> "⚠️ Atenção! Detectamos pontos de urgência. Finalizando análise..."
        _ -> "✅ Análise preliminar positiva! Gerando relatório completo..."
      end

    {:noreply,
     socket
     |> put_flash(:info, message)
     |> assign(transcription_progress: 100)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp upload_and_create_lesson(socket, user, params) do
    require Logger

    # Server-side upload: consume_uploaded_entries receives the temp file path
    uploaded_files =
      consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
        lesson_id = Ecto.UUID.generate()
        key = Storage.lesson_key(lesson_id, entry.client_name)

        Logger.info("Uploading file: #{entry.client_name} to key: #{key}")

        case Storage.upload_file(key, path, content_type: entry.client_type) do
          {:ok, url} ->
            Logger.info("Upload successful: #{url}")

            {:ok,
             %{
               key: key,
               url: url,
               filename: entry.client_name,
               lesson_id: lesson_id
             }}

          {:error, reason} ->
            Logger.error("Upload failed: #{inspect(reason)}")
            {:postpone, reason}
        end
      end)

    case uploaded_files do
      [%{url: url, key: key, filename: filename, lesson_id: lesson_id}] ->
        title =
          case params["title"] do
            nil -> filename
            "" -> filename
            t -> t
          end

        lesson_attrs = %{
          "id" => lesson_id,
          "title" => title,
          "subject" => params["subject"],
          "audio_url" => url,
          "audio_key" => key,
          "original_filename" => filename,
          "status" => "pending"
        }

        Lessons.create_lesson(user, lesson_attrs)

      [] ->
        {:error, :no_file_uploaded}

      errors when is_list(errors) ->
        {:error, List.first(errors)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8 animate-fade-in">
      <div class="max-w-4xl mx-auto">
        <%!-- Header --%>
        <div class="mb-10 text-center">
          <div class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-teal-100/80 dark:bg-teal-900/30 mb-4">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-teal-400 opacity-75">
              </span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-teal-500"></span>
            </span>
            <span class="text-sm font-medium text-teal-700 dark:text-teal-300">
              <%= if @step == :upload, do: "Nova Aula", else: "Processando..." %>
            </span>
          </div>
          <h1 class="text-3xl sm:text-4xl font-bold text-slate-900 dark:text-white tracking-tight mb-3">
            <%= if @step == :upload, do: "Envie sua gravação", else: "Detalhes da Aula" %>
          </h1>
          <p class="text-base sm:text-lg text-slate-500 dark:text-slate-400">
            <%= if @step == :upload,
              do: "Comece enviando o arquivo para análise",
              else: "Preencha as informações enquanto a IA analisa o áudio" %>
          </p>
        </div>

        <%!-- Step 1: Upload --%>
        <div :if={@step == :upload} class="relative">
          <form phx-submit="submit" phx-change="validate" class="space-y-6">
            <%!-- Hidden file input --%>
            <.live_file_input upload={@uploads.media} class="sr-only" />

            <%!-- Drop Zone --%>
            <div
              :if={@uploads.media.entries == [] && !@uploading}
              class="upload-container relative w-full mb-8"
              phx-drop-target={@uploads.media.ref}
              id="upload-drop-zone"
            >
              <label
                for={@uploads.media.ref}
                class="absolute inset-0 w-full h-full cursor-pointer z-50"
                title="Clique para selecionar ou arraste um arquivo"
              >
              </label>

              <div class="upload-card bg-white dark:bg-slate-800 rounded-2xl shadow-card border-2 border-dashed border-slate-300 dark:border-slate-600 p-10 sm:p-16 transition-all duration-300 hover:shadow-elevated hover:border-teal-400 dark:hover:border-teal-500 hover:bg-teal-50/30 dark:hover:bg-teal-900/10 relative z-10 pointer-events-none group">
                <div class="flex justify-center mb-8">
                  <div class="relative">
                    <div class="absolute inset-0 bg-teal-500/20 rounded-full blur-2xl animate-pulse-glow">
                    </div>
                    <div class="relative bg-gradient-to-br from-teal-500 to-cyan-500 rounded-2xl p-6 sm:p-8 shadow-lg shadow-teal-500/30 group-hover:scale-110 transition-transform duration-300">
                      <.icon name="hero-cloud-arrow-up" class="h-12 w-12 sm:h-16 sm:w-16 text-white" />
                    </div>
                  </div>
                </div>

                <div class="text-center space-y-3">
                  <h2 class="text-xl sm:text-2xl font-semibold text-slate-900 dark:text-white">
                    Arraste seu arquivo aqui
                  </h2>
                  <p class="text-sm sm:text-base text-slate-500 dark:text-slate-400">
                    ou
                    <span class="text-teal-600 dark:text-teal-400 font-semibold cursor-pointer hover:underline">
                      clique para selecionar
                    </span>
                  </p>
                </div>

                <div class="mt-10 pt-8 border-t border-slate-200/50 dark:border-slate-700/50">
                  <div class="flex flex-col sm:flex-row items-center justify-center gap-4 sm:gap-8">
                    <div class="flex items-center gap-3 px-4 py-2 rounded-xl bg-slate-100/50 dark:bg-slate-700/30">
                      <span class="text-sm text-slate-600 dark:text-slate-400">MP4, MP3, WAV...</span>
                    </div>
                    <div class="flex items-center gap-3 px-4 py-2 rounded-xl bg-slate-100/50 dark:bg-slate-700/30">
                      <span class="text-sm text-slate-600 dark:text-slate-400">Ate 500MB</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <%!-- File Selected Preview --%>
            <div
              :if={@uploads.media.entries != [] && !@uploading}
              class="space-y-6 animate-fade-in-up"
            >
              <div
                :for={entry <- @uploads.media.entries}
                class="bg-white dark:bg-slate-800 rounded-2xl shadow-card border border-slate-200/50 dark:border-slate-700/50 overflow-hidden p-6 sm:p-8"
              >
                <div class="flex items-start gap-4 sm:gap-6">
                  <div class="flex-shrink-0">
                    <.icon name="hero-film" class="h-10 w-10 text-teal-600 dark:text-teal-400" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <h3 class="text-lg sm:text-xl font-semibold text-slate-900 dark:text-white truncate">
                      <%= entry.client_name %>
                    </h3>
                    <p class="text-sm text-slate-500"><%= format_filesize(entry.client_size) %></p>
                    <%!-- Progress --%>
                    <div :if={entry.progress > 0} class="mt-4">
                      <div class="h-2 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden">
                        <div
                          class="h-full bg-teal-500 transition-all duration-300"
                          style={"width: #{entry.progress}%"}
                        >
                        </div>
                      </div>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    class="text-slate-400 hover:text-red-500"
                  >
                    <.icon name="hero-x-mark" class="h-6 w-6" />
                  </button>
                </div>
              </div>

              <%!-- Start Button --%>
              <div class="flex justify-center">
                <button
                  type="submit"
                  disabled={@uploading}
                  class="group relative px-8 py-4 bg-gradient-to-r from-teal-600 to-cyan-600 text-white font-semibold rounded-xl shadow-lg shadow-teal-500/30 hover:shadow-xl hover:shadow-teal-500/40 transition-all duration-300 hover:scale-[1.02]"
                >
                  <span class="flex items-center justify-center gap-2">
                    <%= if @uploading do %>
                      <.spinner size="sm" />
                      <span>Enviando...</span>
                    <% else %>
                      <.icon name="hero-play" class="h-5 w-5" />
                      <span>Começar Análise</span>
                    <% end %>
                  </span>
                </button>
              </div>
            </div>
          </form>
        </div>

        <%!-- Step 2: Details --%>
        <div :if={@step == :details} class="animate-fade-in">
          <div class="bg-white dark:bg-slate-800 rounded-2xl shadow-card border border-slate-200/50 dark:border-slate-700/50 p-6 sm:p-8 mb-6">
            <div class="flex items-center gap-4 mb-4">
              <div class="flex-1">
                <h3 class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-2 flex justify-between">
                  <span>Progresso da Transcrição</span>
                  <span><%= @transcription_progress %>%</span>
                </h3>
                <div class="h-2 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden">
                  <div
                    class="h-full bg-teal-500 transition-all duration-500 ease-out"
                    style={"width: #{@transcription_progress}%"}
                  >
                  </div>
                </div>
              </div>
            </div>
            <p class="text-sm text-slate-500 dark:text-slate-400">
              Sua aula já está sendo processada. Aproveite para preencher os detalhes abaixo.
            </p>
          </div>

          <form phx-submit="submit" phx-change="validate" class="space-y-6">
            <div class="bg-white dark:bg-slate-800 rounded-2xl shadow-card border border-slate-200/50 dark:border-slate-700/50 p-6 sm:p-8">
              <div class="space-y-5">
                <div>
                  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                    Titulo
                  </label>
                  <input
                    type="text"
                    name="lesson[title]"
                    value={@form[:title].value}
                    class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-600 rounded-xl focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 text-slate-900 dark:text-white"
                  />
                </div>

                <div>
                  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                    Disciplina
                  </label>
                  <div class="relative">
                    <select
                      name="lesson[subject]"
                      class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-600 rounded-xl appearance-none pr-10 text-slate-900 dark:text-white"
                    >
                      <option value="">Selecione...</option>
                      <%= for {label, value} <- subject_options() do %>
                        <option value={value} selected={@form[:subject].value == value}>
                          <%= label %>
                        </option>
                      <% end %>
                    </select>
                    <div class="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
                      <.icon name="hero-chevron-down" class="h-5 w-5 text-slate-400" />
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="flex justify-end">
              <button
                type="submit"
                class="px-8 py-4 bg-teal-600 text-white font-semibold rounded-xl shadow-lg hover:bg-teal-700 transition-colors"
              >
                Salvar e Visualizar Aula
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp subject_options do
    [
      {"Língua Portuguesa", "lingua_portuguesa"},
      {"Matemática", "matematica"},
      {"Ciências", "ciencias"},
      {"História", "historia"},
      {"Geografia", "geografia"},
      {"Arte", "arte"},
      {"Educação Física", "educacao_fisica"},
      {"Inglês", "ingles"},
      {"Outra", "outra"}
    ]
  end

  defp format_filesize(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} bytes"
    end
  end

  defp format_filesize(_), do: "0 bytes"
end
