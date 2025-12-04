defmodule Hellen.Notifications do
  @moduledoc """
  Context for managing notifications.

  Handles creating, listing, and managing notifications for users.
  Supports both in-app (PubSub) and email notifications.
  """
  import Ecto.Query

  alias Hellen.Accounts
  alias Hellen.Accounts.User
  alias Hellen.Notifications.{Emails, Mailer, Notification, Preference}
  alias Hellen.Repo
  alias Hellen.Workers.NotificationJob

  # ============================================================================
  # Notification CRUD
  # ============================================================================

  @doc "Get a notification by ID"
  def get_notification!(id), do: Repo.get!(Notification, id)

  @doc "Get a notification by ID with user preloaded"
  def get_notification_with_user!(id) do
    Notification
    |> Repo.get!(id)
    |> Repo.preload(:user)
  end

  @doc "List notifications for a user"
  def list_user_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    unread_only = Keyword.get(opts, :unread_only, false)

    query =
      from n in Notification,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at],
        limit: ^limit,
        offset: ^offset

    query =
      if unread_only do
        from n in query, where: is_nil(n.read_at)
      else
        query
      end

    Repo.all(query)
  end

  @doc "Count unread notifications for a user"
  def count_unread(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      select: count(n.id)
    )
    |> Repo.one()
  end

  @doc "Mark a notification as read"
  def mark_as_read(notification_id) do
    notification = get_notification!(notification_id)

    notification
    |> Notification.mark_read_changeset()
    |> Repo.update()
  end

  @doc "Mark all notifications as read for a user"
  def mark_all_as_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at)
    )
    |> Repo.update_all(set: [read_at: now])
  end

  @doc "Mark notification email as sent"
  def mark_email_sent(%Notification{} = notification) do
    notification
    |> Notification.mark_email_sent_changeset()
    |> Repo.update()
  end

  @doc "Create a notification"
  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  # ============================================================================
  # Preferences
  # ============================================================================

  @doc "Get or create notification preferences for a user"
  def get_or_create_preferences(user_id) do
    case Repo.get_by(Preference, user_id: user_id) do
      nil ->
        %Preference{}
        |> Preference.changeset(%{user_id: user_id})
        |> Repo.insert()

      preference ->
        {:ok, preference}
    end
  end

  @doc "Update notification preferences"
  def update_preferences(user_id, attrs) do
    {:ok, preference} = get_or_create_preferences(user_id)

    preference
    |> Preference.changeset(attrs)
    |> Repo.update()
  end

  @doc "Check if user should receive email for notification type"
  def should_send_email?(user_id, notification_type) do
    case get_or_create_preferences(user_id) do
      {:ok, pref} -> Preference.should_email?(pref, notification_type)
      _ -> false
    end
  end

  # ============================================================================
  # Notification Triggers
  # ============================================================================

  @doc """
  Notify about a bullying alert.
  Creates notifications for the lesson owner and coordinators (for high/critical).
  """
  def notify_alert(alert, opts \\ []) do
    alert = Repo.preload(alert, analysis: [lesson: [:user, :institution]])
    lesson = alert.analysis.lesson
    teacher = lesson.user
    institution_id = lesson.institution_id

    notification_type = alert_type_to_notification_type(alert.severity)

    # Build notification data
    notification_data = %{
      "alert_id" => alert.id,
      "alert_type" => alert.alert_type,
      "severity" => alert.severity,
      "lesson_id" => lesson.id,
      "lesson_title" => lesson.title,
      "evidence_text" => String.slice(alert.evidence_text || "", 0, 200),
      "alert_url" => Keyword.get(opts, :base_url, "") <> "/lessons/#{lesson.id}/analysis"
    }

    # Notify the teacher (lesson owner)
    {:ok, teacher_notification} =
      create_and_broadcast_notification(teacher, %{
        type: notification_type,
        title: alert_title(alert.severity),
        message: alert_message(alert),
        data: notification_data,
        institution_id: institution_id
      })

    # Enqueue email for high/critical alerts
    if alert.severity in ["high", "critical"] do
      enqueue_email(teacher_notification)
    end

    # For high/critical alerts, also notify coordinators
    if alert.severity in ["high", "critical"] do
      notify_coordinators(institution_id, notification_type, notification_data, alert)
    end

    {:ok, teacher_notification}
  end

  @doc """
  Notify about analysis completion.
  Creates notification for the lesson owner.
  """
  def notify_analysis_complete(analysis, opts \\ []) do
    analysis = Repo.preload(analysis, lesson: [:user, :institution])
    lesson = analysis.lesson
    teacher = lesson.user
    institution_id = lesson.institution_id

    notification_data = %{
      "analysis_id" => analysis.id,
      "lesson_id" => lesson.id,
      "lesson_title" => lesson.title,
      "score" => analysis.score,
      "analysis_url" => Keyword.get(opts, :base_url, "") <> "/lessons/#{lesson.id}/analysis"
    }

    {:ok, notification} =
      create_and_broadcast_notification(teacher, %{
        type: "analysis_complete",
        title: "Analise Concluida",
        message:
          "A analise da aula \"#{lesson.title}\" foi concluida com score #{analysis.score}.",
        data: notification_data,
        institution_id: institution_id
      })

    # Optionally enqueue email based on preferences
    if should_send_email?(teacher.id, "analysis_complete") do
      enqueue_email(notification)
    end

    {:ok, notification}
  end

  # ============================================================================
  # Email
  # ============================================================================

  @doc "Enqueue email notification to be sent via Oban"
  def enqueue_email(%Notification{} = notification) do
    %{notification_id: notification.id, type: "send_email"}
    |> NotificationJob.new()
    |> Oban.insert()
  end

  @doc "Send email for a notification"
  def send_notification_email(%Notification{} = notification) do
    user = Accounts.get_user!(notification.user_id)

    case Emails.build_email(notification, user) do
      nil ->
        {:ok, :skipped}

      email ->
        case Mailer.deliver(email) do
          {:ok, _} ->
            mark_email_sent(notification)
            {:ok, :sent}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp create_and_broadcast_notification(%User{} = user, attrs) do
    attrs = Map.put(attrs, :user_id, user.id)

    with {:ok, notification} <- create_notification(attrs) do
      # Broadcast via PubSub for real-time updates
      broadcast_notification(user.id, notification)
      {:ok, notification}
    end
  end

  defp broadcast_notification(user_id, notification) do
    Phoenix.PubSub.broadcast(
      Hellen.PubSub,
      "user:#{user_id}:notifications",
      {:new_notification, notification}
    )
  end

  defp notify_coordinators(institution_id, notification_type, notification_data, alert) do
    coordinators = list_coordinators(institution_id)

    Enum.each(coordinators, fn coordinator ->
      {:ok, notification} =
        create_and_broadcast_notification(coordinator, %{
          type: notification_type,
          title: alert_title(alert.severity) <> " (Coordenador)",
          message: alert_message(alert),
          data: notification_data,
          institution_id: institution_id
        })

      enqueue_email(notification)
    end)
  end

  defp list_coordinators(institution_id) do
    from(u in User,
      where: u.institution_id == ^institution_id and u.role in ["coordinator", "admin"]
    )
    |> Repo.all()
  end

  defp alert_type_to_notification_type("critical"), do: "alert_critical"
  defp alert_type_to_notification_type("high"), do: "alert_high"
  defp alert_type_to_notification_type("medium"), do: "alert_medium"
  defp alert_type_to_notification_type(_), do: "alert_low"

  defp alert_title("critical"), do: "Alerta Critico Detectado"
  defp alert_title("high"), do: "Alerta de Alta Severidade"
  defp alert_title("medium"), do: "Alerta Detectado"
  defp alert_title(_), do: "Alerta de Baixa Severidade"

  defp alert_message(alert) do
    type_label = alert_type_label(alert.alert_type)
    "Foi detectado um alerta de #{type_label} durante a aula."
  end

  defp alert_type_label("verbal_aggression"), do: "agressao verbal"
  defp alert_type_label("exclusion"), do: "exclusao"
  defp alert_type_label("intimidation"), do: "intimidacao"
  defp alert_type_label("mockery"), do: "zombaria"
  defp alert_type_label("discrimination"), do: "discriminacao"
  defp alert_type_label("threat"), do: "ameaca"
  defp alert_type_label("inappropriate_language"), do: "linguagem inapropriada"
  defp alert_type_label(_), do: "comportamento inadequado"
end
