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
    require Logger
    Logger.info("Submit event received with params: #{inspect(params)}")

    user = socket.assigns.current_user
    Logger.info("Current user: #{inspect(user && user.email)}")

    lesson_params = Map.get(params, "lesson", %{})

    # Start upload process
    socket = assign(socket, uploading: true)

    # Upload files to R2 and create lesson
    try do
      case upload_and_create_lesson(socket, user, lesson_params) do
        {:ok, lesson} ->
          {:noreply,
           socket
           |> put_flash(:info, "Aula criada com sucesso! O processamento começará em breve.")
           |> push_navigate(to: ~p"/lessons/#{lesson.id}")}

        {:error, :insufficient_credits} ->
          {:noreply,
           socket
           |> assign(uploading: false)
           |> put_flash(
             :error,
             "Você não tem créditos suficientes. Adquira mais créditos para continuar."
           )}

        {:error, reason} ->
          Logger.error("Upload error: #{inspect(reason)}")

          {:noreply,
           socket
           |> assign(uploading: false)
           |> put_flash(:error, "Erro ao criar aula: #{inspect(reason)}")}
      end
    rescue
      e ->
        Logger.error("Exception in submit: #{inspect(e)}")
        Logger.error("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")

        {:noreply,
         socket
         |> assign(uploading: false)
         |> put_flash(:error, "Erro inesperado: #{inspect(e)}")}
    end
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  @impl true
  def handle_event("online", _params, socket) do
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
        <%!-- Header com Design 2025 --%>
        <div class="mb-10 text-center">
          <div class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-teal-100/80 dark:bg-teal-900/30 mb-4">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-teal-400 opacity-75">
              </span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-teal-500"></span>
            </span>
            <span class="text-sm font-medium text-teal-700 dark:text-teal-300">Analise com IA</span>
          </div>
          <h1 class="text-3xl sm:text-4xl font-bold text-slate-900 dark:text-white tracking-tight mb-3">
            Nova Aula
          </h1>
          <p class="text-base sm:text-lg text-slate-500 dark:text-slate-400">
            Envie sua gravacao e deixe a IA fazer o resto
          </p>
        </div>

        <%!-- Main Content Area --%>
        <div class="relative">
          <form phx-submit="submit" phx-change="validate" class="space-y-6">
            <%!-- Hidden file input - must stay in DOM for upload to work --%>
            <.live_file_input upload={@uploads.media} class="sr-only" />

            <%!-- Estado 1: Empty State - Drop Zone --%>
            <div
              :if={@uploads.media.entries == [] && !@uploading}
              class="upload-container relative w-full mb-8"
              phx-drop-target={@uploads.media.ref}
              id="upload-drop-zone"
            >
              <%!-- Clickable overlay to trigger file input --%>
              <label
                for={@uploads.media.ref}
                class="absolute inset-0 w-full h-full cursor-pointer z-50"
                title="Clique para selecionar ou arraste um arquivo"
              >
              </label>

              <%!-- Card Visual (Background) --%>
              <div class="upload-card bg-white dark:bg-slate-800 rounded-2xl shadow-card border-2 border-dashed border-slate-300 dark:border-slate-600 p-10 sm:p-16 transition-all duration-300 hover:shadow-elevated hover:border-teal-400 dark:hover:border-teal-500 hover:bg-teal-50/30 dark:hover:bg-teal-900/10 relative z-10 pointer-events-none group">
                <%!-- Icone Central com animacao --%>
                <div class="flex justify-center mb-8">
                  <div class="relative">
                    <div class="absolute inset-0 bg-teal-500/20 rounded-full blur-2xl animate-pulse-glow">
                    </div>
                    <div class="relative bg-gradient-to-br from-teal-500 to-cyan-500 rounded-2xl p-6 sm:p-8 shadow-lg shadow-teal-500/30 group-hover:scale-110 transition-transform duration-300">
                      <.icon name="hero-cloud-arrow-up" class="h-12 w-12 sm:h-16 sm:w-16 text-white" />
                    </div>
                  </div>
                </div>

                <%!-- Texto Principal --%>
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

                <%!-- Info Cards --%>
                <div class="mt-10 pt-8 border-t border-slate-200/50 dark:border-slate-700/50">
                  <div class="flex flex-col sm:flex-row items-center justify-center gap-4 sm:gap-8">
                    <div class="flex items-center gap-3 px-4 py-2 rounded-xl bg-slate-100/50 dark:bg-slate-700/30">
                      <div class="w-8 h-8 rounded-lg bg-teal-500/10 dark:bg-teal-500/20 flex items-center justify-center">
                        <.icon
                          name="hero-musical-note"
                          class="h-4 w-4 text-teal-600 dark:text-teal-400"
                        />
                      </div>
                      <span class="text-sm text-slate-600 dark:text-slate-400">
                        MP4, MP3, WAV, M4A
                      </span>
                    </div>
                    <div class="flex items-center gap-3 px-4 py-2 rounded-xl bg-slate-100/50 dark:bg-slate-700/30">
                      <div class="w-8 h-8 rounded-lg bg-cyan-500/10 dark:bg-cyan-500/20 flex items-center justify-center">
                        <.icon
                          name="hero-arrow-up-tray"
                          class="h-4 w-4 text-cyan-600 dark:text-cyan-400"
                        />
                      </div>
                      <span class="text-sm text-slate-600 dark:text-slate-400">Ate 500MB</span>
                    </div>
                  </div>
                </div>

                <%!-- Overlay de Drag --%>
                <div class="upload-drag-overlay absolute inset-0 bg-gradient-to-br from-teal-500/10 to-cyan-500/10 dark:from-teal-500/20 dark:to-cyan-500/20 backdrop-blur-sm rounded-2xl opacity-0 transition-all duration-300 flex items-center justify-center border-2 border-teal-500 border-dashed z-30">
                  <div class="text-center animate-bounce-subtle">
                    <div class="w-20 h-20 mx-auto mb-4 rounded-2xl bg-teal-500 flex items-center justify-center shadow-lg shadow-teal-500/30">
                      <.icon name="hero-arrow-down-tray" class="h-10 w-10 text-white" />
                    </div>
                    <p class="text-xl font-semibold text-teal-700 dark:text-teal-300">Solte aqui</p>
                  </div>
                </div>
              </div>

              <%!-- Erros de Upload --%>
              <div
                :if={upload_errors(@uploads.media) != []}
                class="mt-6 relative z-20 animate-fade-in"
              >
                <div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/50 rounded-xl p-4">
                  <.error :for={err <- upload_errors(@uploads.media)}>
                    <div class="flex items-center gap-3 text-red-700 dark:text-red-400">
                      <.icon name="hero-exclamation-circle" class="h-5 w-5" />
                      <span><%= error_message(err) %></span>
                    </div>
                  </.error>
                </div>
              </div>
            </div>

            <%!-- Estado 2: File Selected + Form --%>
            <div
              :if={@uploads.media.entries != [] && !@uploading}
              class="space-y-6 animate-fade-in-up"
            >
              <%!-- Preview do Arquivo --%>
              <div
                :for={entry <- @uploads.media.entries}
                class="bg-white dark:bg-slate-800 rounded-2xl shadow-card border border-slate-200/50 dark:border-slate-700/50 overflow-hidden"
              >
                <div class="p-6 sm:p-8">
                  <div class="flex items-start gap-4 sm:gap-6">
                    <%!-- Icone do Arquivo --%>
                    <div class="flex-shrink-0">
                      <div class="relative">
                        <div class="absolute inset-0 bg-teal-500/10 dark:bg-teal-500/20 rounded-xl blur">
                        </div>
                        <div class="relative bg-gradient-to-br from-teal-50 to-cyan-50 dark:from-teal-900/50 dark:to-cyan-900/50 rounded-xl p-4 sm:p-5 border border-teal-100 dark:border-teal-800">
                          <.icon
                            name="hero-film"
                            class="h-8 w-8 sm:h-10 sm:w-10 text-teal-600 dark:text-teal-400"
                          />
                        </div>
                      </div>
                    </div>

                    <%!-- Info do Arquivo --%>
                    <div class="flex-1 min-w-0">
                      <h3 class="text-lg sm:text-xl font-semibold text-slate-900 dark:text-white truncate mb-1">
                        <%= entry.client_name %>
                      </h3>
                      <p class="text-sm sm:text-base text-slate-500 dark:text-slate-400">
                        <%= format_filesize(entry.client_size) %>
                      </p>

                      <%!-- Progress Bar --%>
                      <div :if={entry.progress > 0} class="mt-4 sm:mt-6">
                        <div class="flex items-center justify-between mb-2">
                          <span class={[
                            "text-sm font-medium",
                            entry.progress < 100 && "text-teal-600 dark:text-teal-400",
                            entry.progress >= 100 && "text-emerald-600 dark:text-emerald-400"
                          ]}>
                            <%= if entry.progress < 100, do: "Enviando...", else: "Pronto!" %>
                          </span>
                          <span class="text-sm font-bold text-slate-700 dark:text-slate-300 tabular-nums">
                            <%= entry.progress %>%
                          </span>
                        </div>
                        <div class="h-2 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden">
                          <div
                            class={[
                              "h-full rounded-full transition-all duration-500 ease-out",
                              entry.progress < 100 && "bg-gradient-to-r from-teal-500 to-cyan-500",
                              entry.progress >= 100 && "bg-gradient-to-r from-emerald-500 to-teal-500"
                            ]}
                            style={"width: #{entry.progress}%"}
                          >
                          </div>
                        </div>
                      </div>

                      <%!-- Erros do Entry --%>
                      <div :if={upload_errors(@uploads.media, entry) != []} class="mt-4">
                        <.error :for={err <- upload_errors(@uploads.media, entry)}>
                          <div class="flex items-center gap-2 text-red-600 dark:text-red-400">
                            <.icon name="hero-exclamation-circle" class="h-4 w-4" />
                            <span class="text-sm"><%= error_message(err) %></span>
                          </div>
                        </.error>
                      </div>
                    </div>

                    <%!-- Botao Remover --%>
                    <button
                      type="button"
                      phx-click="cancel-upload"
                      phx-value-ref={entry.ref}
                      class="flex-shrink-0 p-2.5 sm:p-3 text-slate-400 dark:text-slate-500 hover:text-red-600 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-xl transition-all duration-200"
                      aria-label="Remover arquivo"
                    >
                      <.icon name="hero-x-mark" class="h-5 w-5 sm:h-6 sm:w-6" />
                    </button>
                  </div>
                </div>
              </div>

              <%!-- Formulario de Metadados --%>
              <div class="bg-white dark:bg-slate-800 rounded-2xl shadow-card border border-slate-200/50 dark:border-slate-700/50 p-6 sm:p-8">
                <div class="flex items-center gap-3 mb-6">
                  <div class="w-10 h-10 rounded-xl bg-teal-500/10 dark:bg-teal-500/20 flex items-center justify-center">
                    <.icon name="hero-document-text" class="h-5 w-5 text-teal-600 dark:text-teal-400" />
                  </div>
                  <h3 class="text-lg font-semibold text-slate-900 dark:text-white">
                    Detalhes da Aula
                  </h3>
                </div>

                <div class="space-y-5">
                  <%!-- Titulo --%>
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                      Titulo <span class="text-slate-400">(opcional)</span>
                    </label>
                    <input
                      type="text"
                      name="lesson[title]"
                      value={@form[:title].value}
                      placeholder="Ex: Aula de Matematica - Fracoes"
                      class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-600 rounded-xl focus:outline-none focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-all duration-200 text-base text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500"
                    />
                  </div>

                  <%!-- Disciplina --%>
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                      Disciplina
                    </label>
                    <div class="relative">
                      <select
                        name="lesson[subject]"
                        class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-600 rounded-xl focus:outline-none focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-all duration-200 text-base text-slate-900 dark:text-white appearance-none cursor-pointer pr-10"
                      >
                        <option value="">Selecione uma disciplina</option>
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

              <%!-- Actions --%>
              <div class="flex flex-col-reverse sm:flex-row items-center justify-between gap-4">
                <.link
                  navigate={~p"/dashboard"}
                  class="w-full sm:w-auto text-center px-6 py-3 text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white font-medium transition-colors duration-200"
                >
                  Cancelar
                </.link>

                <button
                  type="submit"
                  disabled={@uploading || @uploads.media.entries == []}
                  class="w-full sm:w-auto group relative px-8 py-4 bg-gradient-to-r from-teal-600 to-cyan-600 text-white font-semibold rounded-xl shadow-lg shadow-teal-500/30 hover:shadow-xl hover:shadow-teal-500/40 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:shadow-lg transition-all duration-300 hover:scale-[1.02] disabled:hover:scale-100"
                >
                  <span class="flex items-center justify-center gap-2">
                    <%= if @uploading do %>
                      <.spinner size="sm" />
                      <span>Enviando...</span>
                    <% else %>
                      <.icon name="hero-sparkles" class="h-5 w-5" />
                      <span>Processar Aula</span>
                    <% end %>
                  </span>
                </button>
              </div>
            </div>
          </form>

          <%!-- Estado 3: Uploading --%>
          <div :if={@uploading} class="animate-fade-in">
            <div class="bg-white dark:bg-slate-800 rounded-2xl shadow-card border border-slate-200/50 dark:border-slate-700/50 p-10 sm:p-16 text-center">
              <div class="w-20 h-20 mx-auto mb-6 rounded-2xl bg-gradient-to-br from-teal-500 to-cyan-500 flex items-center justify-center animate-pulse">
                <.icon name="hero-arrow-path" class="h-10 w-10 text-white animate-spin" />
              </div>
              <h3 class="text-xl font-semibold text-slate-900 dark:text-white mb-2">
                Processando sua aula...
              </h3>
              <p class="text-slate-500 dark:text-slate-400">
                Aguarde enquanto preparamos tudo
              </p>
            </div>
          </div>
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

  defp error_message(:too_large), do: "Arquivo muito grande (máximo 500MB)"
  defp error_message(:too_many_files), do: "Apenas um arquivo por vez"
  defp error_message(:not_accepted), do: "Tipo de arquivo não suportado"
  defp error_message(err), do: "Erro: #{inspect(err)}"
end
