defmodule Hellen.Workers.TranscriptionJob do
  @moduledoc """
  Oban worker for transcribing lesson audio.
  """

  use Oban.Worker,
    queue: :transcription,
    max_attempts: 3,
    unique: [period: 300, keys: [:lesson_id]]

  alias Hellen.AI.NvidiaClient
  alias Hellen.Billing
  alias Hellen.Lessons
  alias Hellen.Workers.AnalysisJob

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"lesson_id" => lesson_id}}) do
    Logger.info("Starting transcription for lesson #{lesson_id}")

    lesson = Lessons.get_lesson!(lesson_id)

    with {:ok, lesson} <- Lessons.update_lesson_status(lesson, "transcribing"),
         {:ok, result} <- transcribe_audio(lesson),
         {:ok, _transcription} <- save_transcription(lesson, result),
         {:ok, lesson} <- Lessons.update_lesson_status(lesson, "analyzing"),
         {:ok, _job} <- enqueue_analysis(lesson) do
      Logger.info("Transcription completed for lesson #{lesson_id}")
      broadcast_progress(lesson_id, "transcription_complete", %{})
      :ok
    else
      {:error, reason} ->
        Logger.error("Transcription failed for lesson #{lesson_id}: #{inspect(reason)}")
        handle_failure(lesson, reason)
    end
  end

  defp transcribe_audio(%{audio_url: nil, video_url: video_url}) when is_binary(video_url) do
    # Video files are sent directly; NVIDIA API handles audio extraction
    NvidiaClient.transcribe(video_url)
  end

  defp transcribe_audio(%{audio_url: audio_url}) when is_binary(audio_url) do
    NvidiaClient.transcribe(audio_url)
  end

  defp transcribe_audio(_lesson) do
    {:error, :no_audio_source}
  end

  defp save_transcription(lesson, result) do
    Lessons.create_transcription(lesson.id, %{
      full_text: result.text,
      segments: result.segments,
      language: result.language,
      confidence_score: nil
    })
  end

  defp enqueue_analysis(lesson) do
    %{lesson_id: lesson.id}
    |> AnalysisJob.new()
    |> Oban.insert()
  end

  defp handle_failure(lesson, reason) do
    Lessons.update_lesson_status(lesson, "failed")

    # Refund credit on failure
    user = Hellen.Accounts.get_user!(lesson.user_id)
    Billing.refund_credit(user, lesson.id)

    broadcast_progress(lesson.id, "transcription_failed", %{error: inspect(reason)})
    {:error, reason}
  end

  defp broadcast_progress(lesson_id, event, payload) do
    Phoenix.PubSub.broadcast(
      Hellen.PubSub,
      "lesson:#{lesson_id}",
      {event, Map.put(payload, :lesson_id, lesson_id)}
    )
  end
end
