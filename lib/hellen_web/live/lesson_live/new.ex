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

  @impl true
  def handle_event("submit", %{"lesson" => params}, socket) do
    user = socket.assigns.current_user

    # Start upload process
    socket = assign(socket, uploading: true)

    # Upload files to R2 and create lesson
    case upload_and_create_lesson(socket, user, params) do
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
        {:noreply,
         socket
         |> assign(uploading: false)
         |> put_flash(:error, "Erro ao criar aula: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  defp upload_and_create_lesson(socket, user, params) do
    # Server-side upload: consume_uploaded_entries receives the temp file path
    uploaded_files =
      consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
        lesson_id = Ecto.UUID.generate()
        key = Storage.lesson_key(lesson_id, entry.client_name)

        case Storage.upload_file(key, path, content_type: entry.client_type) do
          {:ok, url} ->
            {:ok,
             %{
               key: key,
               url: url,
               filename: entry.client_name,
               lesson_id: lesson_id
             }}

          {:error, reason} ->
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
    <div class="space-y-8">
      <div class="max-w-4xl mx-auto">
        <%!-- Header Minimalista --%>
        <div class="mb-12 text-center">
          <h1 class="text-4xl font-light text-gray-900 dark:text-white tracking-tight mb-3">
            Nova Aula
          </h1>
          <p class="text-lg text-gray-500 dark:text-gray-400 font-light">
            Envie sua gravação e deixe a IA fazer o resto
          </p>
        </div>

        <%!-- Main Content Area - Adaptativo --%>
        <div class="relative">
          <%!-- Estado 1: Empty State --%>
          <div
            :if={@uploads.media.entries == [] && !@uploading}
            class="upload-container relative w-full"
            phx-drop-target={@uploads.media.ref}
            phx-hook="UploadDragDrop"
            id="upload-drop-zone"
          >
            <%!-- Input Overlay (Invisible but clickable/droppable) --%>
            <.live_file_input
              upload={@uploads.media}
              class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-20"
              title="Clique para selecionar ou arraste um arquivo"
            />

            <%!-- Card Visual (Background) --%>
            <div class="upload-card bg-white dark:bg-slate-800 rounded-3xl shadow-sm border border-gray-200 dark:border-slate-700 p-16 transition-all duration-300 hover:shadow-xl hover:border-indigo-300 dark:hover:border-indigo-600 hover:scale-[1.02] relative z-10 pointer-events-none">
              <%!-- Ícone Central --%>
              <div class="flex justify-center mb-8">
                <div class="relative">
                  <div class="absolute inset-0 bg-indigo-500/20 rounded-full blur-2xl"></div>
                  <div class="relative bg-gradient-to-br from-indigo-500 to-purple-600 rounded-full p-8">
                    <.icon name="hero-cloud-arrow-up" class="h-16 w-16 text-white" />
                  </div>
                </div>
              </div>

              <%!-- Texto Principal --%>
              <div class="text-center space-y-4">
                <h2 class="text-2xl font-medium text-gray-900 dark:text-white">
                  Arraste seu arquivo aqui
                </h2>
                <p class="text-base text-gray-500 dark:text-gray-400">
                  ou
                  <span class="text-indigo-600 dark:text-indigo-400 font-medium">
                    clique para selecionar
                  </span>
                </p>
              </div>

              <%!-- Info Secundária --%>
              <div class="mt-12 pt-8 border-t border-gray-100 dark:border-slate-700">
                <div class="flex items-center justify-center gap-8 text-sm text-gray-400 dark:text-gray-500">
                  <div class="flex items-center gap-2">
                    <.icon name="hero-document" class="h-4 w-4" />
                    <span>MP4, MP3, WAV, M4A</span>
                  </div>
                  <div class="flex items-center gap-2">
                    <.icon name="hero-arrow-up-tray" class="h-4 w-4" />
                    <span>Até 500MB</span>
                  </div>
                </div>
              </div>

              <%!-- Overlay de Drag (Visual only) --%>
              <div class="upload-drag-overlay absolute inset-0 bg-gradient-to-br from-indigo-500/10 to-purple-500/10 dark:from-indigo-500/20 dark:to-purple-500/20 backdrop-blur-sm rounded-3xl opacity-0 transition-opacity duration-300 flex items-center justify-center border-2 border-indigo-500 border-dashed z-30">
                <div class="text-center">
                  <.icon
                    name="hero-arrow-down-tray"
                    class="h-16 w-16 text-indigo-600 dark:text-indigo-400 mx-auto mb-4"
                  />
                  <p class="text-xl font-medium text-indigo-700 dark:text-indigo-300">Solte aqui</p>
                </div>
              </div>
            </div>

            <%!-- Erros de Upload --%>
            <div :if={upload_errors(@uploads.media) != []} class="mt-6 relative z-20">
              <div class="bg-red-50 border border-red-200 rounded-2xl p-4">
                <.error :for={err <- upload_errors(@uploads.media)}>
                  <div class="flex items-center gap-3 text-red-800">
                    <.icon name="hero-exclamation-circle" class="h-5 w-5" />
                    <span><%= error_message(err) %></span>
                  </div>
                </.error>
              </div>
            </div>
          </div>

          <%!-- Estado 2: File Selected + Form --%>
          <div :if={@uploads.media.entries != [] && !@uploading} class="space-y-6">
            <%!-- Preview do Arquivo --%>
            <div
              :for={entry <- @uploads.media.entries}
              class="bg-white dark:bg-slate-800 rounded-3xl shadow-sm border border-gray-200 dark:border-slate-700 overflow-hidden"
            >
              <div class="p-8">
                <div class="flex items-start gap-6">
                  <%!-- Ícone do Arquivo --%>
                  <div class="flex-shrink-0">
                    <div class="relative">
                      <div class="absolute inset-0 bg-indigo-500/10 dark:bg-indigo-500/20 rounded-2xl blur">
                      </div>
                      <div class="relative bg-gradient-to-br from-indigo-50 to-purple-50 dark:from-indigo-900/50 dark:to-purple-900/50 rounded-2xl p-5 border border-indigo-100 dark:border-indigo-800">
                        <.icon
                          name="hero-film"
                          class="h-10 w-10 text-indigo-600 dark:text-indigo-400"
                        />
                      </div>
                    </div>
                  </div>

                  <%!-- Info do Arquivo --%>
                  <div class="flex-1 min-w-0">
                    <h3 class="text-xl font-medium text-gray-900 dark:text-white truncate mb-2">
                      <%= entry.client_name %>
                    </h3>
                    <p class="text-base text-gray-500 dark:text-gray-400">
                      <%= format_filesize(entry.client_size) %>
                    </p>

                    <%!-- Progress Bar --%>
                    <div :if={entry.progress > 0} class="mt-6">
                      <div class="flex items-center justify-between mb-3">
                        <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
                          <%= if entry.progress < 100, do: "Enviando...", else: "Pronto!" %>
                        </span>
                        <span class="text-sm text-gray-500 dark:text-gray-400">
                          <%= entry.progress %>%
                        </span>
                      </div>
                      <div class="h-2 bg-gray-100 dark:bg-slate-700 rounded-full overflow-hidden">
                        <div
                          class="h-full bg-gradient-to-r from-indigo-500 to-purple-600 rounded-full transition-all duration-500 ease-out"
                          style={"width: #{entry.progress}%"}
                        >
                        </div>
                      </div>
                    </div>

                    <%!-- Erros do Entry --%>
                    <div :if={upload_errors(@uploads.media, entry) != []} class="mt-4">
                      <.error :for={err <- upload_errors(@uploads.media, entry)}>
                        <div class="flex items-center gap-2 text-red-600">
                          <.icon name="hero-exclamation-circle" class="h-4 w-4" />
                          <span class="text-sm"><%= error_message(err) %></span>
                        </div>
                      </.error>
                    </div>
                  </div>

                  <%!-- Botão Remover --%>
                  <button
                    type="button"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    class="flex-shrink-0 p-3 text-gray-400 dark:text-gray-500 hover:text-red-600 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-xl transition-all duration-200"
                    aria-label="Remover arquivo"
                  >
                    <.icon name="hero-x-mark" class="h-6 w-6" />
                  </button>
                </div>
              </div>
            </div>

            <%!-- Formulário de Metadados --%>
            <form phx-submit="submit" phx-change="validate" class="space-y-6">
              <div class="bg-white dark:bg-slate-800 rounded-3xl shadow-sm border border-gray-200 dark:border-slate-700 p-8">
                <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-6">
                  Detalhes da Aula
                </h3>

                <div class="space-y-6">
                  <%!-- Título --%>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                      Título (opcional)
                    </label>
                    <input
                      type="text"
                      name="lesson[title]"
                      value={@form[:title].value}
                      placeholder="Ex: Aula de Matemática - Frações"
                      class="w-full px-4 py-3 bg-gray-50 dark:bg-slate-700 border border-gray-200 dark:border-slate-600 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200 text-base text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500"
                    />
                  </div>

                  <%!-- Disciplina --%>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                      Disciplina
                    </label>
                    <select
                      name="lesson[subject]"
                      class="w-full px-4 py-3 bg-gray-50 dark:bg-slate-700 border border-gray-200 dark:border-slate-600 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200 text-base text-gray-900 dark:text-white appearance-none cursor-pointer"
                    >
                      <option value="">Selecione uma disciplina</option>
                      <%= for {label, value} <- subject_options() do %>
                        <option value={value} selected={@form[:subject].value == value}>
                          <%= label %>
                        </option>
                      <% end %>
                    </select>
                  </div>
                </div>
              </div>

              <%!-- Actions --%>
              <div class="flex items-center justify-between gap-4">
                <.link
                  navigate={~p"/"}
                  class="px-6 py-3 text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white font-medium transition-colors duration-200"
                >
                  Cancelar
                </.link>

                <button
                  type="submit"
                  disabled={
                    @uploading || @uploads.media.entries == [] ||
                      Enum.any?(@uploads.media.entries, &(!&1.done?))
                  }
                  class="group relative px-8 py-4 bg-gradient-to-r from-indigo-600 to-purple-600 text-white font-medium rounded-xl shadow-lg shadow-indigo-500/30 hover:shadow-xl hover:shadow-indigo-500/40 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:shadow-lg transition-all duration-300 hover:scale-105 disabled:hover:scale-100"
                >
                  <span class="flex items-center gap-2">
                    <%= cond do %>
                      <% @uploading -> %>
                        <.icon name="hero-arrow-path" class="h-5 w-5 animate-spin" /> Processando...
                      <% @uploads.media.entries != [] and Enum.any?(@uploads.media.entries, &(!&1.done?)) -> %>
                        <.icon name="hero-arrow-up-tray" class="h-5 w-5" />
                        Carregando <%= Enum.at(@uploads.media.entries, 0).progress %>%
                      <% true -> %>
                        <.icon name="hero-sparkles" class="h-5 w-5" /> Processar Aula
                    <% end %>
                  </span>
                </button>
              </div>
            </form>
          </div>

          <%!-- Estado 3: Success (será um flash message antes do redirect) --%>
          <%!-- Já tratado pelo put_flash + push_navigate --%>
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
