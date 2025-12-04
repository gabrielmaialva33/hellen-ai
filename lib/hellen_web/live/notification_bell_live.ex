defmodule HellenWeb.NotificationBellLive do
  @moduledoc """
  LiveView component for the notification bell in the sidebar.
  Shows unread notification count and a dropdown with recent notifications.
  Subscribes to PubSub for real-time updates.
  """
  use HellenWeb, :live_component

  alias Hellen.Notifications

  @impl true
  def mount(socket) do
    {:ok, assign(socket, open: false, notifications: [], unread_count: 0)}
  end

  @impl true
  def update(%{current_user: user} = assigns, socket) do
    if connected?(socket) && user do
      # Subscribe to user's notification channel
      Phoenix.PubSub.subscribe(Hellen.PubSub, "user:#{user.id}:notifications")

      # Load initial data
      notifications = Notifications.list_user_notifications(user.id, limit: 5)
      unread_count = Notifications.count_unread(user.id)

      {:ok,
       socket
       |> assign(assigns)
       |> assign(notifications: notifications)
       |> assign(unread_count: unread_count)}
    else
      {:ok, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    {:noreply, assign(socket, open: !socket.assigns.open)}
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, open: false)}
  end

  @impl true
  def handle_event("mark_read", %{"id" => id}, socket) do
    Notifications.mark_as_read(id)

    notifications =
      Enum.map(socket.assigns.notifications, fn n ->
        if n.id == id, do: %{n | read_at: DateTime.utc_now()}, else: n
      end)

    unread_count = max(socket.assigns.unread_count - 1, 0)

    {:noreply,
     socket
     |> assign(notifications: notifications)
     |> assign(unread_count: unread_count)}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    user = socket.assigns.current_user
    Notifications.mark_all_as_read(user.id)

    notifications =
      Enum.map(socket.assigns.notifications, fn n ->
        %{n | read_at: DateTime.utc_now()}
      end)

    {:noreply,
     socket
     |> assign(notifications: notifications)
     |> assign(unread_count: 0)}
  end

  # Handle new notification from PubSub
  def handle_info({:new_notification, notification}, socket) do
    notifications = [notification | Enum.take(socket.assigns.notifications, 4)]
    unread_count = socket.assigns.unread_count + 1

    {:noreply,
     socket
     |> assign(notifications: notifications)
     |> assign(unread_count: unread_count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative" id={"notification-bell-#{@id}"} phx-click-away="close" phx-target={@myself}>
      <button
        type="button"
        phx-click="toggle"
        phx-target={@myself}
        class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors relative"
        title="Notificacoes"
      >
        <.icon name="hero-bell" class="h-5 w-5 text-gray-500 dark:text-gray-400" />
        <span
          :if={@unread_count > 0}
          class="absolute -top-1 -right-1 w-5 h-5 bg-red-500 rounded-full text-white text-xs font-bold flex items-center justify-center"
        >
          <%= if @unread_count > 9, do: "9+", else: @unread_count %>
        </span>
      </button>

      <div
        :if={@open}
        class="absolute bottom-full left-0 mb-2 w-80 bg-white dark:bg-slate-800 rounded-xl shadow-xl border border-gray-200 dark:border-slate-700 overflow-hidden z-50"
      >
        <div class="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-slate-700">
          <h3 class="font-semibold text-gray-900 dark:text-white">Notificacoes</h3>
          <button
            :if={@unread_count > 0}
            type="button"
            phx-click="mark_all_read"
            phx-target={@myself}
            class="text-xs text-indigo-600 dark:text-indigo-400 hover:underline"
          >
            Marcar todas como lidas
          </button>
        </div>

        <div class="max-h-80 overflow-y-auto">
          <%= if Enum.empty?(@notifications) do %>
            <div class="p-6 text-center text-gray-500 dark:text-gray-400">
              <.icon name="hero-bell-slash" class="h-8 w-8 mx-auto mb-2 opacity-50" />
              <p class="text-sm">Nenhuma notificacao</p>
            </div>
          <% else %>
            <div class="divide-y divide-gray-100 dark:divide-slate-700">
              <%= for notification <- @notifications do %>
                <.notification_item notification={notification} myself={@myself} />
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp notification_item(assigns) do
    ~H"""
    <div
      class={[
        "px-4 py-3 hover:bg-gray-50 dark:hover:bg-slate-700/50 cursor-pointer transition-colors",
        is_nil(@notification.read_at) && "bg-indigo-50/50 dark:bg-indigo-900/20"
      ]}
      phx-click="mark_read"
      phx-value-id={@notification.id}
      phx-target={@myself}
    >
      <div class="flex items-start gap-3">
        <div class={[
          "w-2 h-2 rounded-full mt-2 flex-shrink-0",
          notification_dot_color(@notification.type),
          !is_nil(@notification.read_at) && "opacity-30"
        ]}>
        </div>
        <div class="flex-1 min-w-0">
          <p class={[
            "text-sm font-medium truncate",
            is_nil(@notification.read_at) && "text-gray-900 dark:text-white",
            !is_nil(@notification.read_at) && "text-gray-500 dark:text-gray-400"
          ]}>
            <%= @notification.title %>
          </p>
          <p class="text-xs text-gray-500 dark:text-gray-400 line-clamp-2">
            <%= @notification.message %>
          </p>
          <p class="text-xs text-gray-400 dark:text-gray-500 mt-1">
            <%= relative_time(@notification.inserted_at) %>
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp notification_dot_color("alert_critical"), do: "bg-red-500"
  defp notification_dot_color("alert_high"), do: "bg-orange-500"
  defp notification_dot_color("alert_medium"), do: "bg-yellow-500"
  defp notification_dot_color("alert_low"), do: "bg-gray-500"
  defp notification_dot_color("analysis_complete"), do: "bg-green-500"
  defp notification_dot_color(_), do: "bg-indigo-500"

  defp relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "agora"
      diff < 3600 -> "ha #{div(diff, 60)} min"
      diff < 86_400 -> "ha #{div(diff, 3600)} h"
      diff < 604_800 -> "ha #{div(diff, 86_400)} d"
      true -> Calendar.strftime(datetime, "%d/%m")
    end
  end
end
