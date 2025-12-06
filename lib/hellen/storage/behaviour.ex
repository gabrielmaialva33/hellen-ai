defmodule Hellen.Storage.Behaviour do
  @moduledoc """
  Behaviour for storage implementations.
  Allows mocking file storage in tests.
  """

  @doc "Upload a file to storage"
  @callback upload(path :: String.t(), content :: binary(), opts :: keyword()) ::
              {:ok, url :: String.t()} | {:error, term()}

  @doc "Download a file from storage"
  @callback download(url :: String.t()) ::
              {:ok, binary()} | {:error, term()}

  @doc "Delete a file from storage"
  @callback delete(url :: String.t()) ::
              :ok | {:error, term()}

  @doc "Generate a presigned URL for upload"
  @callback presigned_url(path :: String.t(), opts :: keyword()) ::
              {:ok, url :: String.t()} | {:error, term()}
end
