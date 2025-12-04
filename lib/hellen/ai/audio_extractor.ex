defmodule Hellen.AI.AudioExtractor do
  @moduledoc """
  Optimized audio extraction from video files using FFmpeg.

  Uses stream copy when possible (10x faster, no quality loss),
  falls back to re-encoding only when necessary.
  """

  require Logger

  @video_extensions ~w(.mp4 .mkv .avi .mov .webm .flv .wmv .m4v)
  @audio_extensions ~w(.mp3 .wav .m4a .aac .ogg .flac .opus)

  # Codecs that Groq Whisper API accepts natively
  @groq_compatible_codecs ~w(aac mp3 opus flac vorbis pcm_s16le pcm_s24le)

  @doc """
  Processes a media file for transcription.

  If it's a video file, extracts audio using the fastest method available.
  If it's already audio, returns it directly (or converts if needed).

  Returns {:ok, audio_binary, content_type} or {:error, reason}
  """
  def process_for_transcription(file_binary, original_filename) do
    ext = Path.extname(original_filename) |> String.downcase()

    cond do
      ext in @audio_extensions ->
        # Already audio - return as-is (Groq handles most formats)
        Logger.info("File is already audio (#{ext}), skipping extraction")
        {:ok, file_binary, guess_content_type(ext)}

      ext in @video_extensions ->
        # Video file - extract audio
        Logger.info("Video file detected (#{ext}), extracting audio...")
        extract_audio_from_video(file_binary, ext)

      true ->
        Logger.warning("Unknown file extension: #{ext}, attempting as video")
        extract_audio_from_video(file_binary, ext)
    end
  end

  @doc """
  Extracts audio from video binary using FFmpeg.

  Strategy:
  1. Probe the video to detect audio codec
  2. If codec is Groq-compatible, use stream copy (ultra-fast)
  3. Otherwise, re-encode to MP3 (slower but compatible)
  """
  def extract_audio_from_video(video_binary, ext \\ ".mp4") do
    # Create temp files
    temp_dir = System.tmp_dir!()
    input_path = Path.join(temp_dir, "input_#{:erlang.unique_integer([:positive])}#{ext}")

    try do
      # Write video to temp file
      File.write!(input_path, video_binary)

      # Detect audio codec
      case detect_audio_codec(input_path) do
        {:ok, codec} ->
          Logger.info("Detected audio codec: #{codec}")
          extract_with_strategy(input_path, codec)

        {:error, reason} ->
          Logger.error("Failed to detect codec: #{inspect(reason)}")
          {:error, :codec_detection_failed}
      end
    after
      # Cleanup input file
      File.rm(input_path)
    end
  end

  @doc """
  Detects the audio codec of a video file using ffprobe.
  """
  def detect_audio_codec(file_path) do
    args = [
      "-v",
      "quiet",
      "-select_streams",
      "a:0",
      "-show_entries",
      "stream=codec_name",
      "-of",
      "csv=p=0",
      file_path
    ]

    case System.cmd("ffprobe", args, stderr_to_stdout: true) do
      {output, 0} ->
        codec = output |> String.trim() |> String.downcase()
        if codec == "", do: {:error, :no_audio_stream}, else: {:ok, codec}

      {error, _} ->
        {:error, {:ffprobe_failed, error}}
    end
  end

  # Choose extraction strategy based on codec
  defp extract_with_strategy(input_path, codec) do
    if codec in @groq_compatible_codecs do
      # Stream copy - 10x faster, no quality loss
      Logger.info("Using STREAM COPY (fast path) for codec: #{codec}")
      extract_with_stream_copy(input_path, codec)
    else
      # Re-encode to MP3 - slower but guaranteed compatible
      Logger.info("Using RE-ENCODE (slow path) for codec: #{codec}")
      extract_with_reencode(input_path)
    end
  end

  @doc """
  Extracts audio using stream copy (no re-encoding).
  This is ~10x faster and preserves original quality.
  """
  def extract_with_stream_copy(input_path, codec) do
    temp_dir = System.tmp_dir!()
    output_ext = codec_to_extension(codec)

    output_path =
      Path.join(temp_dir, "audio_#{:erlang.unique_integer([:positive])}.#{output_ext}")

    args = [
      "-i",
      input_path,
      # No video
      "-vn",
      # Stream copy (no re-encoding)
      "-acodec",
      "copy",
      # Overwrite
      "-y",
      output_path
    ]

    start_time = System.monotonic_time(:millisecond)

    try do
      case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
        {_output, 0} ->
          elapsed = System.monotonic_time(:millisecond) - start_time
          audio_binary = File.read!(output_path)
          audio_size = byte_size(audio_binary)

          Logger.info(
            "Stream copy extraction completed in #{elapsed}ms, output size: #{format_bytes(audio_size)}"
          )

          content_type = extension_to_content_type(output_ext)
          {:ok, audio_binary, content_type}

        {error, code} ->
          Logger.error("FFmpeg stream copy failed (code #{code}): #{String.slice(error, 0, 500)}")
          # Fallback to re-encode
          Logger.info("Falling back to re-encode...")
          extract_with_reencode(input_path)
      end
    after
      File.rm(output_path)
    end
  end

  @doc """
  Extracts and re-encodes audio to MP3.
  Slower but guaranteed to work with any input.
  """
  def extract_with_reencode(input_path) do
    temp_dir = System.tmp_dir!()
    output_path = Path.join(temp_dir, "audio_#{:erlang.unique_integer([:positive])}.mp3")

    args = [
      "-i",
      input_path,
      # No video
      "-vn",
      # MP3 encoder
      "-acodec",
      "libmp3lame",
      # 128kbps (good balance for speech)
      "-b:a",
      "128k",
      # 16kHz (optimal for ASR)
      "-ar",
      "16000",
      # Mono (ASR doesn't need stereo)
      "-ac",
      "1",
      # Use all CPU cores
      "-threads",
      "0",
      # Overwrite
      "-y",
      output_path
    ]

    start_time = System.monotonic_time(:millisecond)

    try do
      case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
        {_output, 0} ->
          elapsed = System.monotonic_time(:millisecond) - start_time
          audio_binary = File.read!(output_path)
          audio_size = byte_size(audio_binary)

          Logger.info(
            "Re-encode extraction completed in #{elapsed}ms, output size: #{format_bytes(audio_size)}"
          )

          {:ok, audio_binary, "audio/mpeg"}

        {error, code} ->
          Logger.error("FFmpeg re-encode failed (code #{code}): #{String.slice(error, 0, 500)}")
          {:error, :ffmpeg_failed}
      end
    after
      File.rm(output_path)
    end
  end

  @doc """
  Gets file info using ffprobe.
  """
  def get_media_info(file_path) do
    args = [
      "-v",
      "quiet",
      "-print_format",
      "json",
      "-show_format",
      "-show_streams",
      file_path
    ]

    case System.cmd("ffprobe", args, stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, info} -> {:ok, info}
          {:error, _} -> {:error, :json_parse_failed}
        end

      {error, _} ->
        {:error, {:ffprobe_failed, error}}
    end
  end

  # Helpers

  defp codec_to_extension("aac"), do: "aac"
  defp codec_to_extension("mp3"), do: "mp3"
  defp codec_to_extension("opus"), do: "opus"
  defp codec_to_extension("flac"), do: "flac"
  defp codec_to_extension("vorbis"), do: "ogg"
  defp codec_to_extension("pcm_s16le"), do: "wav"
  defp codec_to_extension("pcm_s24le"), do: "wav"
  defp codec_to_extension(_), do: "mp3"

  defp extension_to_content_type("aac"), do: "audio/aac"
  defp extension_to_content_type("m4a"), do: "audio/mp4"
  defp extension_to_content_type("mp3"), do: "audio/mpeg"
  defp extension_to_content_type("opus"), do: "audio/opus"
  defp extension_to_content_type("flac"), do: "audio/flac"
  defp extension_to_content_type("ogg"), do: "audio/ogg"
  defp extension_to_content_type("wav"), do: "audio/wav"
  defp extension_to_content_type(_), do: "audio/mpeg"

  defp guess_content_type(".mp3"), do: "audio/mpeg"
  defp guess_content_type(".wav"), do: "audio/wav"
  defp guess_content_type(".m4a"), do: "audio/mp4"
  defp guess_content_type(".aac"), do: "audio/aac"
  defp guess_content_type(".ogg"), do: "audio/ogg"
  defp guess_content_type(".flac"), do: "audio/flac"
  defp guess_content_type(".opus"), do: "audio/opus"
  defp guess_content_type(_), do: "audio/mpeg"

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
