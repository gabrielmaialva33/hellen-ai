defmodule HellenWeb.LessonChannel do
  @moduledoc """
  Channel for real-time lesson processing updates via WebSocket.
  """
  use HellenWeb, :channel

  @impl true
  def join("lesson:" <> lesson_id, _params, socket) do
    # Subscribe to lesson updates
    Phoenix.PubSub.subscribe(Hellen.PubSub, "lesson:#{lesson_id}")
    {:ok, assign(socket, :lesson_id, lesson_id)}
  end

  @impl true
  def handle_info({event, payload}, socket) do
    push(socket, to_string(event), payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{message: "pong"}}, socket}
  end
end
