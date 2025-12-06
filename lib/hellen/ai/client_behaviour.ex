defmodule Hellen.AI.ClientBehaviour do
  @moduledoc """
  Behaviour for AI client implementations.
  Allows mocking AI services in tests.
  """

  @doc "Transcribe audio to text"
  @callback transcribe(audio_url :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @doc "Analyze transcription for pedagogical insights"
  @callback analyze_pedagogy(transcription :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
