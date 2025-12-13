defmodule Hellen.MoxHelpers do
  @moduledoc """
  Helper functions for setting up Mox expectations in tests.

  Provides convenient wrappers for common mock scenarios with sensible defaults.

  ## Usage

      # In tests
      setup :verify_on_exit!

      test "transcribes audio" do
        expect_transcription()
        # ... test code
      end

      test "handles transcription failure" do
        expect_transcription({:error, :api_timeout})
        # ... test code
      end
  """
  import Mox

  @doc """
  Sets up standard AI client mock expectations for transcription.

  ## Options
    * `result` - Override the default response (default: successful transcription)

  ## Examples

      # Default success response
      expect_transcription()

      # Custom response
      expect_transcription({:ok, %{text: "Custom text", segments: [], language: "pt"}})

      # Error response
      expect_transcription({:error, :api_timeout})
  """
  def expect_transcription(result \\ nil) do
    response = result || default_transcription()

    expect(Hellen.AI.ClientMock, :transcribe, fn _url, _opts -> response end)
  end

  @doc """
  Sets up standard AI client mock expectations for pedagogical analysis.

  ## Options
    * `result` - Override the default response (default: successful analysis)

  ## Examples

      # Default success response
      expect_analysis()

      # Custom response with specific score
      expect_analysis({:ok, %{overall_score: 0.95, ...}})

      # Error response
      expect_analysis({:error, :rate_limit_exceeded})
  """
  def expect_analysis(result \\ nil) do
    response = result || default_analysis()

    expect(Hellen.AI.ClientMock, :analyze_pedagogy, fn _text, _opts -> response end)
  end

  @doc """
  Sets up standard storage mock for file uploads.

  ## Options
    * `url` - The URL to return (default: "https://storage.example.com/test.mp3")

  ## Examples

      expect_upload()
      expect_upload("https://custom-storage.com/file.mp3")
  """
  def expect_upload(url \\ "https://storage.example.com/test.mp3") do
    expect(Hellen.Storage.Mock, :upload, fn _path, _content, _opts ->
      {:ok, url}
    end)
  end

  @doc """
  Sets up standard storage mock for file downloads.

  ## Options
    * `content` - The binary content to return (default: sample audio bytes)

  ## Examples

      expect_download()
      expect_download(<<1, 2, 3, 4, 5>>)
  """
  def expect_download(content \\ sample_audio_bytes()) do
    expect(Hellen.Storage.Mock, :download, fn _url -> {:ok, content} end)
  end

  @doc """
  Sets up standard storage mock for file deletion.

  ## Examples

      expect_delete()
      expect_delete({:error, :not_found})
  """
  def expect_delete(result \\ :ok) do
    expect(Hellen.Storage.Mock, :delete, fn _url -> result end)
  end

  @doc """
  Sets up standard storage mock for presigned URL generation.

  ## Options
    * `url` - The presigned URL to return

  ## Examples

      expect_presigned_url()
      expect_presigned_url("https://signed-url.example.com/upload?token=abc")
  """
  def expect_presigned_url(url \\ "https://storage.example.com/upload?presigned=true") do
    expect(Hellen.Storage.Mock, :presigned_url, fn _path, _opts ->
      {:ok, url}
    end)
  end

  @doc """
  Sets up a complete mock scenario for lesson processing (transcription + analysis).

  Useful for integration-style tests that need the full pipeline mocked.

  ## Examples

      expect_full_processing()
      expect_full_processing(transcription_result: {:error, :timeout})
  """
  def expect_full_processing(opts \\ []) do
    transcription_result = Keyword.get(opts, :transcription_result)
    analysis_result = Keyword.get(opts, :analysis_result)

    expect_transcription(transcription_result)
    expect_analysis(analysis_result)
  end

  # ===========================================================================
  # Default Mock Responses
  # ===========================================================================

  defp default_transcription do
    {:ok,
     %{
       text:
         "Esta e uma transcricao de teste da aula de matematica. " <>
           "Hoje vamos aprender sobre fracoes. Voces sabem o que sao fracoes?",
       segments: [
         %{"start" => 0.0, "end" => 5.0, "text" => "Esta e uma transcricao de teste."},
         %{"start" => 5.0, "end" => 10.0, "text" => "Hoje vamos aprender sobre fracoes."},
         %{"start" => 10.0, "end" => 14.0, "text" => "Voces sabem o que sao fracoes?"}
       ],
       language: "pt",
       duration: 2700,
       processing_time_ms: 5000
     }}
  end

  defp default_analysis do
    {:ok,
     %{
       model: "qwen3-8b",
       raw: %{"analysis" => "test"},
       structured: %{
         "summary" => "Good lesson with clear explanations",
         "strengths" => ["Clear introduction", "Good pacing"],
         "improvements" => ["More student interaction"],
         "overall_score" => 0.85,
         "bncc_matches" => [
           %{
             "code" => "EF05MA01",
             "name" => "Resolver problemas de adicao",
             "score" => 0.90,
             "evidence" => "Hoje vamos aprender sobre fracoes"
           }
         ],
         "bullying_alerts" => [],
         "lesson_characters" => [
           %{
             "identifier" => "Professor",
             "role" => "teacher",
             "speech_count" => 15,
             "word_count" => 350,
             "engagement_level" => "high"
           }
         ]
       },
       overall_score: 0.85,
       tokens_used: 500,
       processing_time_ms: 2000
     }}
  end

  defp sample_audio_bytes do
    # Minimal valid MP3 header bytes
    <<0xFF, 0xFB, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00>>
  end
end
