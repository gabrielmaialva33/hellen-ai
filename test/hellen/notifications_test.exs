defmodule Hellen.NotificationsTest do
  use Hellen.DataCase, async: true

  alias Hellen.Notifications

  describe "notification CRUD" do
    test "get_notification!/1 returns notification by id" do
      notification = insert(:notification)
      result = Notifications.get_notification!(notification.id)
      assert result.id == notification.id
    end

    test "get_notification!/1 raises for non-existent notification" do
      assert_raise Ecto.NoResultsError, fn ->
        Notifications.get_notification!(Ecto.UUID.generate())
      end
    end

    test "get_notification_with_user!/1 returns notification with user preloaded" do
      notification = insert(:notification)
      result = Notifications.get_notification_with_user!(notification.id)
      assert result.id == notification.id
      assert result.user != nil
    end

    test "list_user_notifications/2 returns notifications for user" do
      user = insert(:user)
      insert(:notification, user: user)
      insert(:notification, user: user)
      # Different user
      insert(:notification)

      notifications = Notifications.list_user_notifications(user.id)
      assert length(notifications) == 2
    end

    test "list_user_notifications/2 orders by inserted_at desc" do
      user = insert(:user)
      insert(:notification, user: user, title: "First")
      # Need to sleep at least 1 second since inserted_at is truncated to seconds
      :timer.sleep(1100)
      insert(:notification, user: user, title: "Second")

      [first, second] = Notifications.list_user_notifications(user.id)
      assert first.title == "Second"
      assert second.title == "First"
    end

    test "list_user_notifications/2 respects limit and offset" do
      user = insert(:user)
      for i <- 1..5, do: insert(:notification, user: user, title: "Notification #{i}")

      notifications = Notifications.list_user_notifications(user.id, limit: 2, offset: 1)
      assert length(notifications) == 2
    end

    test "list_user_notifications/2 can filter to unread only" do
      user = insert(:user)
      insert(:notification, user: user, read_at: nil)
      insert(:notification, user: user, read_at: nil)
      insert(:notification, user: user, read_at: DateTime.utc_now())

      unread = Notifications.list_user_notifications(user.id, unread_only: true)
      assert length(unread) == 2
    end

    test "count_unread/1 returns count of unread notifications" do
      user = insert(:user)
      insert(:notification, user: user, read_at: nil)
      insert(:notification, user: user, read_at: nil)
      insert(:notification, user: user, read_at: DateTime.utc_now())

      assert Notifications.count_unread(user.id) == 2
    end

    test "mark_as_read/1 marks notification as read" do
      notification = insert(:notification, read_at: nil)
      assert {:ok, read_notification} = Notifications.mark_as_read(notification.id)
      assert read_notification.read_at != nil
    end

    test "mark_all_as_read/1 marks all notifications as read for user" do
      user = insert(:user)
      insert(:notification, user: user, read_at: nil)
      insert(:notification, user: user, read_at: nil)
      insert(:notification, user: user, read_at: nil)

      {count, _} = Notifications.mark_all_as_read(user.id)
      assert count == 3

      assert Notifications.count_unread(user.id) == 0
    end

    test "create_notification/1 creates notification with valid data" do
      user = insert(:user)
      institution = user.institution

      attrs = %{
        user_id: user.id,
        institution_id: institution.id,
        type: "analysis_complete",
        title: "Test Notification",
        message: "Test message",
        data: %{"lesson_id" => Ecto.UUID.generate()}
      }

      assert {:ok, notification} = Notifications.create_notification(attrs)
      assert notification.title == "Test Notification"
      assert notification.type == "analysis_complete"
    end
  end

  describe "preferences" do
    test "get_or_create_preferences/1 creates preferences if not exists" do
      user = insert(:user)

      assert {:ok, preference} = Notifications.get_or_create_preferences(user.id)
      assert preference.user_id == user.id
      # Check default values
      assert preference.email_critical_alerts == true
    end

    test "get_or_create_preferences/1 returns existing preferences" do
      preference = insert(:notification_preference)

      assert {:ok, result} = Notifications.get_or_create_preferences(preference.user_id)
      assert result.id == preference.id
    end

    test "update_preferences/2 updates preferences" do
      preference = insert(:notification_preference, email_analysis_complete: false)

      assert {:ok, updated} =
               Notifications.update_preferences(
                 preference.user_id,
                 %{email_analysis_complete: true}
               )

      assert updated.email_analysis_complete == true
    end

    test "should_send_email?/2 checks preference for notification type" do
      preference =
        insert(:notification_preference,
          email_critical_alerts: true,
          email_analysis_complete: false
        )

      assert Notifications.should_send_email?(preference.user_id, "alert_critical") == true
      assert Notifications.should_send_email?(preference.user_id, "analysis_complete") == false
    end
  end

  describe "email" do
    test "mark_email_sent/1 marks notification email as sent" do
      notification = insert(:notification, email_sent_at: nil)

      assert {:ok, updated} = Notifications.mark_email_sent(notification)
      assert updated.email_sent_at != nil
    end
  end
end
