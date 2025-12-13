defmodule Hellen.Storage do
  @moduledoc """
  Storage module for Cloudflare R2.

  Handles file uploads, downloads, and URL generation for
  lesson audio/video files.
  """

  @doc """
  Uploads a file to R2 storage.

  ## Options
    * `:content_type` - MIME type of the file (auto-detected if not provided)
    * `:acl` - Access control (default: :public_read)

  ## Examples

      iex> Storage.upload("lessons/uuid/audio.mp3", binary_data)
      {:ok, "https://pub-xxx.r2.dev/lessons/uuid/audio.mp3"}

      iex> Storage.upload("lessons/uuid/video.mp4", binary_data, content_type: "video/mp4")
      {:ok, "https://pub-xxx.r2.dev/lessons/uuid/video.mp4"}
  """
  def upload(key, binary, opts \\ []) do
    bucket = get_bucket()
    content_type = opts[:content_type] || guess_content_type(key)

    # Note: R2 doesn't support x-amz-acl headers (public-read, etc.)
    # Public access is configured at the bucket level in Cloudflare dashboard
    request =
      ExAws.S3.put_object(bucket, key, binary, content_type: content_type)

    case ExAws.request(request) do
      {:ok, _response} ->
        {:ok, public_url(key)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Uploads a file from a local path to R2 storage.

  ## Examples

      iex> Storage.upload_file("lessons/uuid/audio.mp3", "/tmp/upload.mp3")
      {:ok, "https://pub-xxx.r2.dev/lessons/uuid/audio.mp3"}
  """
  def upload_file(key, local_path, opts \\ []) do
    case File.read(local_path) do
      {:ok, binary} ->
        upload(key, binary, opts)

      {:error, reason} ->
        {:error, {:file_read_error, reason}}
    end
  end

  @doc """
  Uploads a file from a Phoenix LiveView upload entry.

  ## Examples

      iex> Storage.upload_entry(socket, entry, "lessons/uuid")
      {:ok, "https://pub-xxx.r2.dev/lessons/uuid/filename.mp3"}
  """
  def upload_entry(socket, entry, key_prefix) do
    key = "#{key_prefix}/#{entry.client_name}"
    content_type = entry.client_type

    Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn %{path: path} ->
      case File.read(path) do
        {:ok, binary} ->
          upload(key, binary, content_type: content_type)

        {:error, reason} ->
          {:error, {:file_read_error, reason}}
      end
    end)
  end

  @doc """
  Deletes a file from R2 storage.

  ## Examples

      iex> Storage.delete("lessons/uuid/audio.mp3")
      :ok
  """
  def delete(key) do
    bucket = get_bucket()
    request = ExAws.S3.delete_object(bucket, key)

    case ExAws.request(request) do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the public URL for a stored file.

  ## Examples

      iex> Storage.public_url("lessons/uuid/audio.mp3")
      "https://pub-xxx.r2.dev/lessons/uuid/audio.mp3"
  """
  def public_url(key) do
    base_url = get_public_url()
    "#{base_url}/#{key}"
  end

  @doc """
  Generates a unique key for a lesson file.

  ## Examples

      iex> Storage.lesson_key(lesson_id, "audio.mp3")
      "lessons/abc123/audio.mp3"
  """
  def lesson_key(lesson_id, filename) do
    sanitized = sanitize_filename(filename)
    "lessons/#{lesson_id}/#{sanitized}"
  end

  @doc """
  Checks if the storage is properly configured.
  """
  def configured? do
    config = Application.get_env(:hellen, :r2, [])
    config[:bucket] != nil && config[:public_url] != nil
  end

  @doc """
  Generates a presigned URL for direct browser upload to R2.

  This enables External Uploads in Phoenix LiveView, allowing the browser
  to upload directly to R2 without going through the Phoenix server.

  ## Options
    * `:content_type` - MIME type of the file (default: "application/octet-stream")
    * `:expires_in` - URL expiration in seconds (default: 3600)

  ## Examples

      iex> Storage.presigned_put_url("lessons/uuid/audio.mp3", content_type: "audio/mpeg")
      {:ok, "https://...r2.cloudflarestorage.com/...?X-Amz-Signature=..."}
  """
  def presigned_put_url(key, opts \\ []) do
    bucket = get_bucket()
    content_type = opts[:content_type] || "application/octet-stream"
    expires_in = opts[:expires_in] || 3600

    config = ExAws.Config.new(:s3)

    ExAws.S3.presigned_url(config, :put, bucket, key,
      expires_in: expires_in,
      query_params: [{"Content-Type", content_type}]
    )
  end

  # Private functions

  defp get_bucket do
    config = Application.get_env(:hellen, :r2, [])
    config[:bucket] || raise "R2 bucket not configured"
  end

  defp get_public_url do
    config = Application.get_env(:hellen, :r2, [])
    config[:public_url] || raise "R2 public URL not configured"
  end

  defp sanitize_filename(filename) do
    filename
    |> String.replace(~r/[^\w\.\-]/, "_")
    |> String.downcase()
  end

  @content_types %{
    ".mp3" => "audio/mpeg",
    ".mp4" => "video/mp4",
    ".m4a" => "audio/mp4",
    ".wav" => "audio/wav",
    ".webm" => "video/webm",
    ".ogg" => "audio/ogg",
    ".flac" => "audio/flac",
    ".mov" => "video/quicktime",
    ".avi" => "video/x-msvideo",
    ".mkv" => "video/x-matroska"
  }

  defp guess_content_type(key) do
    Map.get(@content_types, Path.extname(key), "application/octet-stream")
  end
end
