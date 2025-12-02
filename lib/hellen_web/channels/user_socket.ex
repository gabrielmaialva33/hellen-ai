defmodule HellenWeb.UserSocket do
  use Phoenix.Socket

  channel "lesson:*", HellenWeb.LessonChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    # Verify JWT token and assign user_id to socket
    case verify_token(token) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  # Placeholder until Guardian is configured.
  # Will validate JWT tokens for WebSocket authentication.
  defp verify_token(_token) do
    {:ok, "user_id"}
  end
end
