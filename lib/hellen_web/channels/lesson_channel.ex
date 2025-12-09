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
    # Convert payload to JSON-safe format (string keys, serializable values)
    json_payload = serialize_payload(payload)
    push(socket, to_string(event), json_payload)
    {:noreply, socket}
  end

  # Convert atom keys to strings and handle complex structs
  defp serialize_payload(payload) when is_map(payload) do
    payload
    |> Map.new(fn {k, v} -> {to_string(k), serialize_value(v)} end)
  end

  defp serialize_value(%{__struct__: _} = struct) do
    # For Ecto schemas, extract only essential fields
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> Map.new(fn {k, v} -> {to_string(k), serialize_value(v)} end)
  end

  defp serialize_value(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {to_string(k), serialize_value(v)} end)
  end

  defp serialize_value(value) when is_list(value) do
    Enum.map(value, &serialize_value/1)
  end

  defp serialize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp serialize_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp serialize_value(%Date{} = d), do: Date.to_iso8601(d)
  defp serialize_value(value), do: value

  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{message: "pong"}}, socket}
  end
end
