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
     |> allow_upload(:media,
       accept: @accepted_types,
       max_entries: 1,
       max_file_size: @max_file_size,
       auto_upload: true,
       external: &presign_upload/2
     )}
  end

  # Generate presigned URL for direct R2 upload
  defp presign_upload(entry, socket) do
    require Logger
    Logger.info("presign_upload called for: #{entry.client_name}")

    lesson_id = Ecto.UUID.generate()
    key = Storage.lesson_key(lesson_id, entry.client_name)

    case Storage.presigned_put_url(key, content_type: entry.client_type) do
      {:ok, url} ->
        meta = %{
          uploader: "S3",
          key: key,
          url: url,
          lesson_id: lesson_id
        }

        {:ok, meta, socket}

      {:error, reason} ->
        {:error, reason}
    end
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
    # With external uploads, consume_uploaded_entries receives the meta we returned
    # from presign_upload/2 instead of a file path
    uploaded_files =
      consume_uploaded_entries(socket, :media, fn meta, entry ->
        # meta contains: %{key: key, url: url, lesson_id: lesson_id}
        # The file was already uploaded directly to R2 by the browser
        {:ok,
         %{
           key: meta.key,
           url: Storage.public_url(meta.key),
           filename: entry.client_name,
           lesson_id: meta.lesson_id
         }}
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
    <div class="max-w-2xl mx-auto">
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-gray-900">Nova Aula</h1>
        <p class="mt-1 text-sm text-gray-500">
          Envie um arquivo de áudio ou vídeo da sua aula para análise
        </p>
      </div>

      <.card>
        <form phx-submit="submit" phx-change="validate" class="space-y-6">
          <div>
            <.input
              field={@form[:title]}
              label="Título da aula (opcional)"
              placeholder="Ex: Aula de Matemática - Frações"
            />
          </div>

          <div>
            <.input
              field={@form[:subject]}
              type="select"
              label="Disciplina"
              prompt="Selecione uma disciplina"
              options={subject_options()}
            />
          </div>

          <div>
            <span class="block text-sm font-medium text-gray-700 mb-2">
              Arquivo de mídia
            </span>
            <%!-- CRITICAL: Keep file input ALWAYS in DOM for LiveView external upload preflight --%>
            <.live_file_input upload={@uploads.media} class="sr-only peer" id="media-upload-input" />
            <label
              :if={@uploads.media.entries == []}
              for="media-upload-input"
              phx-drop-target={@uploads.media.ref}
              class="relative block border-2 border-dashed border-gray-300 rounded-lg p-8 text-center transition-colors duration-200 hover:border-indigo-400 hover:bg-indigo-50 cursor-pointer"
            >
              <.icon name="hero-cloud-arrow-up" class="mx-auto h-12 w-12 text-gray-400" />
              <div class="mt-4 text-sm text-gray-600">
                <span class="font-semibold text-indigo-600 hover:text-indigo-500">
                  Clique para selecionar
                </span>
                ou arraste e solte
              </div>
              <p class="mt-2 text-xs text-gray-500">
                MP3, MP4, WAV, M4A, WebM, OGG, FLAC, MOV, AVI, MKV até 500MB
              </p>
            </label>
            <div :for={entry <- @uploads.media.entries} class="mt-4 p-4 bg-gray-50 rounded-lg">
              <div class="flex items-center justify-between">
                <div class="flex items-center min-w-0">
                  <.icon name="hero-document" class="h-8 w-8 text-gray-400 flex-shrink-0" />
                  <div class="ml-3 min-w-0">
                    <p class="text-sm font-medium text-gray-900 truncate"><%= entry.client_name %></p>
                    <p class="text-xs text-gray-500"><%= format_filesize(entry.client_size) %></p>
                  </div>
                </div>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  class="ml-4 text-gray-400 hover:text-gray-500"
                  aria-label="Remover arquivo"
                >
                  <.icon name="hero-x-mark" class="h-5 w-5" />
                </button>
              </div>

              <div :if={entry.progress > 0} class="mt-3">
                <.progress value={entry.progress} />
                <p class="mt-1 text-xs text-gray-500 text-right"><%= entry.progress %>%</p>
              </div>

              <.error :for={err <- upload_errors(@uploads.media, entry)}>
                <%= error_message(err) %>
              </.error>
            </div>

            <.error :for={err <- upload_errors(@uploads.media)}>
              <%= error_message(err) %>
            </.error>
          </div>

          <div class="flex items-center justify-end gap-4 pt-4 border-t">
            <.link navigate={~p"/"}>
              <.button type="button" variant="secondary">Cancelar</.button>
            </.link>
            <.button
              type="submit"
              disabled={
                @uploading || @uploads.media.entries == [] ||
                  Enum.any?(@uploads.media.entries, &(!&1.done?))
              }
              phx-disable-with="Enviando..."
            >
              <%= cond do %>
                <% @uploading -> %>
                  Enviando...
                <% @uploads.media.entries != [] and Enum.any?(@uploads.media.entries, &(!&1.done?)) -> %>
                  Carregando... <%= Enum.at(@uploads.media.entries, 0).progress %>%
                <% true -> %>
                  Enviar Aula
              <% end %>
            </.button>
          </div>
        </form>
      </.card>
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
