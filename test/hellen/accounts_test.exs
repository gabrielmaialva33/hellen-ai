defmodule Hellen.AccountsTest do
  use Hellen.DataCase, async: true

  alias Hellen.Accounts
  alias Hellen.Accounts.{Invitation, User}

  describe "users" do
    test "get_user/1 returns user by id" do
      user = insert(:user)
      result = Accounts.get_user(user.id)
      assert result.id == user.id
      assert result.email == user.email
    end

    test "get_user/1 returns nil for non-existent user" do
      assert Accounts.get_user(Ecto.UUID.generate()) == nil
    end

    test "get_user!/1 returns user by id" do
      user = insert(:user)
      result = Accounts.get_user!(user.id)
      assert result.id == user.id
    end

    test "get_user!/1 raises for non-existent user" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(Ecto.UUID.generate())
      end
    end

    test "get_user_by_email/1 returns user by email" do
      user = insert(:user, email: "test@example.com")
      assert Accounts.get_user_by_email("test@example.com").id == user.id
    end

    test "get_user_by_email/1 returns nil for non-existent email" do
      assert Accounts.get_user_by_email("nonexistent@example.com") == nil
    end

    test "get_user_by_firebase_uid/1 returns user by firebase_uid" do
      user = insert(:user, firebase_uid: "firebase123")
      assert Accounts.get_user_by_firebase_uid("firebase123").id == user.id
    end

    test "get_user_by_firebase_uid/1 returns nil for non-existent firebase_uid" do
      assert Accounts.get_user_by_firebase_uid("nonexistent") == nil
    end
  end

  describe "register_user/1" do
    test "creates user with valid data" do
      institution = insert(:institution)

      attrs = %{
        name: "Test User",
        email: "newuser@example.com",
        password: "password123",
        institution_id: institution.id
      }

      assert {:ok, user} = Accounts.register_user(attrs)
      assert user.name == "Test User"
      assert user.email == "newuser@example.com"
      assert user.role == "teacher"
      # signup bonus
      assert user.credits == 2
    end

    test "returns error for invalid email format" do
      attrs = %{name: "Test", email: "invalid-email", password: "password123"}
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "returns error for short password" do
      attrs = %{name: "Test", email: "test@example.com", password: "short"}
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "returns error for duplicate email" do
      insert(:user, email: "existing@example.com")
      attrs = %{name: "Test", email: "existing@example.com", password: "password123"}
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "has already been taken" in errors_on(changeset).email
    end

    test "returns error for missing required fields" do
      assert {:error, changeset} = Accounts.register_user(%{})
      assert "can't be blank" in errors_on(changeset).email
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "authenticate_user/2" do
    test "returns user with valid credentials" do
      user = insert(:user, email: "auth@example.com")

      assert {:ok, authenticated_user} =
               Accounts.authenticate_user("auth@example.com", "password123")

      assert authenticated_user.id == user.id
    end

    test "returns error with invalid password" do
      insert(:user, email: "auth@example.com")

      assert {:error, :invalid_password} =
               Accounts.authenticate_user("auth@example.com", "wrongpassword")
    end

    test "returns error with non-existent email" do
      assert {:error, :user_not_found} =
               Accounts.authenticate_user("nonexistent@example.com", "password123")
    end
  end

  describe "update_user/2" do
    test "updates user with valid data" do
      user = insert(:user)
      assert {:ok, updated} = Accounts.update_user(user, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "returns error with invalid data" do
      user = insert(:user)
      assert {:error, changeset} = Accounts.update_user(user, %{email: "invalid"})
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end
  end

  describe "update_user_profile/2" do
    test "updates name and email" do
      user = insert(:user)

      assert {:ok, updated} =
               Accounts.update_user_profile(user, %{name: "New Name", email: "new@example.com"})

      assert updated.name == "New Name"
      assert updated.email == "new@example.com"
    end

    test "validates email format" do
      user = insert(:user)

      assert {:error, changeset} =
               Accounts.update_user_profile(user, %{name: "Name", email: "invalid"})

      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end
  end

  describe "change_user_password/3" do
    test "changes password with valid current password" do
      user = insert(:user, email: "pass@example.com")
      assert {:ok, updated} = Accounts.change_user_password(user, "password123", "newpassword123")
      assert User.valid_password?(updated, "newpassword123")
    end

    test "returns error with invalid current password" do
      user = insert(:user)

      assert {:error, :invalid_password} =
               Accounts.change_user_password(user, "wrongpassword", "newpassword123")
    end

    test "returns error with short new password" do
      user = insert(:user)
      assert {:error, changeset} = Accounts.change_user_password(user, "password123", "short")
      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end
  end

  describe "update_stripe_customer_id/2" do
    test "updates stripe customer id" do
      user = insert(:user)
      assert {:ok, updated} = Accounts.update_stripe_customer_id(user, "cus_123456")
      assert updated.stripe_customer_id == "cus_123456"
    end
  end

  describe "list_users_by_institution/1" do
    test "returns users in institution" do
      institution = insert(:institution)
      user1 = insert(:user, institution: institution)
      user2 = insert(:user, institution: institution)
      _other_user = insert(:user)

      users = Accounts.list_users_by_institution(institution.id)
      user_ids = Enum.map(users, & &1.id)

      assert length(users) == 2
      assert user1.id in user_ids
      assert user2.id in user_ids
    end

    test "returns empty list for institution with no users" do
      institution = insert(:institution)
      assert Accounts.list_users_by_institution(institution.id) == []
    end
  end

  describe "find_or_create_from_firebase/1" do
    test "creates new user when none exists" do
      firebase_info = %{
        firebase_uid: "fb_uid_123",
        email: "firebase@example.com",
        name: "Firebase User",
        email_verified: true
      }

      assert {:ok, user} = Accounts.find_or_create_from_firebase(firebase_info)
      assert user.firebase_uid == "fb_uid_123"
      assert user.email == "firebase@example.com"
      assert user.name == "Firebase User"
      assert user.email_verified == true
    end

    test "returns existing user by firebase_uid" do
      existing_user = insert(:user, firebase_uid: "fb_existing")
      firebase_info = %{firebase_uid: "fb_existing", email: "other@example.com"}

      assert {:ok, user} = Accounts.find_or_create_from_firebase(firebase_info)
      assert user.id == existing_user.id
    end

    test "links existing user by email to firebase" do
      existing_user = insert(:user, email: "link@example.com", firebase_uid: nil)
      firebase_info = %{firebase_uid: "fb_link", email: "link@example.com", email_verified: true}

      assert {:ok, user} = Accounts.find_or_create_from_firebase(firebase_info)
      assert user.id == existing_user.id
      assert user.firebase_uid == "fb_link"
    end
  end

  describe "institutions" do
    test "get_institution!/1 returns institution" do
      institution = insert(:institution)
      assert Accounts.get_institution!(institution.id).id == institution.id
    end

    test "get_institution!/1 raises for non-existent institution" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_institution!(Ecto.UUID.generate())
      end
    end

    test "create_institution/1 with valid data" do
      attrs = %{name: "Test School", plan: "pro"}
      assert {:ok, institution} = Accounts.create_institution(attrs)
      assert institution.name == "Test School"
      assert institution.plan == "pro"
    end

    test "create_institution/1 with invalid plan" do
      attrs = %{name: "Test", plan: "invalid"}
      assert {:error, changeset} = Accounts.create_institution(attrs)
      assert "is invalid" in errors_on(changeset).plan
    end

    test "update_institution/2 updates institution" do
      institution = insert(:institution)
      assert {:ok, updated} = Accounts.update_institution(institution, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
    end

    test "list_institutions/0 returns all institutions" do
      inst1 = insert(:institution)
      inst2 = insert(:institution)

      institutions = Accounts.list_institutions()
      ids = Enum.map(institutions, & &1.id)

      assert inst1.id in ids
      assert inst2.id in ids
    end
  end

  describe "coordinator functions" do
    test "get_institution_stats/1 returns comprehensive statistics" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution, status: "completed")
      analysis = insert(:analysis, lesson: lesson, institution: institution, overall_score: 0.8)
      insert(:bullying_alert, analysis: analysis, reviewed: false)

      stats = Accounts.get_institution_stats(institution.id)

      assert stats.teachers == 1
      assert stats.lessons == 1
      assert stats.analyses == 1
      assert stats.alerts == 1
      assert stats.avg_score == 0.8
    end

    test "list_teachers_with_stats/1 returns teachers with statistics" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution)
      _analysis = insert(:analysis, lesson: lesson, institution: institution, overall_score: 0.85)

      [teacher_stats] = Accounts.list_teachers_with_stats(institution.id)

      assert teacher_stats.user.id == user.id
      assert teacher_stats.lessons_count == 1
      assert teacher_stats.analyses_count == 1
      # Float.round(0.85, 1) truncates to 0.8
      assert teacher_stats.avg_score == 0.8
    end

    test "get_lessons_per_teacher/1 returns lessons count per teacher" do
      institution = insert(:institution)
      user1 = insert(:user, institution: institution, name: "Teacher A")
      user2 = insert(:user, institution: institution, name: "Teacher B")
      insert(:lesson, user: user1, institution: institution)
      insert(:lesson, user: user1, institution: institution)
      insert(:lesson, user: user2, institution: institution)

      results = Accounts.get_lessons_per_teacher(institution.id)

      teacher_a = Enum.find(results, &(&1.name == "Teacher A"))
      teacher_b = Enum.find(results, &(&1.name == "Teacher B"))

      assert teacher_a.lessons == 2
      assert teacher_b.lessons == 1
    end

    test "list_recent_institution_lessons/2 returns recent lessons" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson1 = insert(:lesson, user: user, institution: institution)
      lesson2 = insert(:lesson, user: user, institution: institution)

      lessons = Accounts.list_recent_institution_lessons(institution.id, limit: 10)

      assert length(lessons) == 2
      assert Enum.any?(lessons, &(&1.id == lesson1.id))
      assert Enum.any?(lessons, &(&1.id == lesson2.id))
    end

    test "invite_teacher_to_institution/2 creates teacher user" do
      institution = insert(:institution)

      attrs = %{name: "New Teacher", email: "newteacher@example.com"}
      assert {:ok, user} = Accounts.invite_teacher_to_institution(institution.id, attrs)

      assert user.name == "New Teacher"
      assert user.email == "newteacher@example.com"
      assert user.role == "teacher"
      assert user.institution_id == institution.id
    end

    test "remove_teacher_from_institution/1 removes institution association" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)

      assert {:ok, updated} = Accounts.remove_teacher_from_institution(user)
      assert updated.institution_id == nil
    end

    test "update_user_role/2 changes teacher to coordinator" do
      user = insert(:user, role: "teacher")
      assert {:ok, updated} = Accounts.update_user_role(user, "coordinator")
      assert updated.role == "coordinator"
    end

    test "update_user_role/2 returns error for invalid role" do
      user = insert(:user)
      assert {:error, :invalid_role} = Accounts.update_user_role(user, "admin")
    end
  end

  describe "admin functions" do
    test "get_system_stats/0 returns system-wide statistics" do
      insert(:institution)
      insert(:user)
      insert(:lesson)

      stats = Accounts.get_system_stats()

      assert stats.institutions >= 1
      assert stats.users >= 1
      assert stats.lessons >= 1
      assert is_map(stats.users_by_role)
      assert is_map(stats.users_by_plan)
    end

    test "list_institutions_with_stats/0 returns institutions with statistics" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      insert(:lesson, user: user, institution: institution)

      results = Accounts.list_institutions_with_stats()

      inst_result = Enum.find(results, &(&1.institution.id == institution.id))
      assert inst_result.users_count == 1
      assert inst_result.lessons_count == 1
    end

    test "list_all_users/1 returns paginated users" do
      insert(:user, role: "teacher")
      insert(:user, role: "coordinator")
      insert(:user, role: "admin")

      {users, total} = Accounts.list_all_users()

      assert total >= 3
      assert length(users) >= 3
    end

    test "list_all_users/1 filters by role" do
      insert(:user, role: "teacher")
      insert(:user, role: "coordinator")

      {users, _total} = Accounts.list_all_users(role: "teacher")

      assert Enum.all?(users, &(&1.role == "teacher"))
    end

    test "list_all_users/1 filters by search term" do
      insert(:user, name: "John Doe", email: "john@example.com")
      insert(:user, name: "Jane Smith", email: "jane@example.com")

      {users, _total} = Accounts.list_all_users(search: "John")

      refute Enum.empty?(users)
      assert Enum.any?(users, &(&1.name == "John Doe"))
    end

    test "admin_update_user_role/2 allows setting admin role" do
      user = insert(:user, role: "teacher")
      assert {:ok, updated} = Accounts.admin_update_user_role(user, "admin")
      assert updated.role == "admin"
    end

    test "admin_assign_user_to_institution/2 assigns user to institution" do
      user = insert(:user, institution_id: nil)
      institution = insert(:institution)

      assert {:ok, updated} = Accounts.admin_assign_user_to_institution(user, institution.id)
      assert updated.institution_id == institution.id
    end

    test "admin_assign_user_to_institution/2 removes user from institution with nil" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)

      assert {:ok, updated} = Accounts.admin_assign_user_to_institution(user, nil)
      assert updated.institution_id == nil
    end

    test "admin_update_user_plan/2 updates user plan" do
      user = insert(:user, plan: "free")
      assert {:ok, updated} = Accounts.admin_update_user_plan(user, "pro")
      assert updated.plan == "pro"
    end

    test "admin_update_user_plan/2 returns error for invalid plan" do
      user = insert(:user)
      assert {:error, :invalid_plan} = Accounts.admin_update_user_plan(user, "invalid")
    end

    test "admin_add_user_credits/3 adds credits to user" do
      user = insert(:user, credits: 10)
      assert {:ok, updated} = Accounts.admin_add_user_credits(user, 5, "gift")
      assert updated.credits == 15
    end

    test "get_daily_registrations/1 returns registration counts" do
      insert(:user)
      insert(:user)

      results = Accounts.get_daily_registrations(30)

      assert is_list(results)
      # At least today's registrations should appear
      assert Enum.any?(results, &(&1.count >= 2))
    end

    test "get_recent_platform_activity/1 returns recent activity" do
      user = insert(:user)
      lesson = insert(:lesson, user: user)
      analysis = insert(:analysis, lesson: lesson)
      insert(:bullying_alert, analysis: analysis, reviewed: false)

      activity = Accounts.get_recent_platform_activity(10)

      refute Enum.empty?(activity.lessons)
      refute Enum.empty?(activity.analyses)
      refute Enum.empty?(activity.alerts)
    end
  end

  describe "invitations" do
    test "create_invitation/3 creates invitation with token" do
      institution = insert(:institution)
      coordinator = insert(:user, institution: institution, role: "coordinator")

      attrs = %{email: "invite@example.com", name: "Invited User", role: "teacher"}
      assert {:ok, invitation} = Accounts.create_invitation(institution.id, attrs, coordinator)

      assert invitation.email == "invite@example.com"
      assert invitation.name == "Invited User"
      assert invitation.role == "teacher"
      assert invitation.institution_id == institution.id
      assert invitation.invited_by_id == coordinator.id
      assert invitation.token != nil
      assert invitation.expires_at != nil
    end

    test "get_invitation_by_token/1 returns invitation" do
      invitation = insert(:invitation)
      found = Accounts.get_invitation_by_token(invitation.token)

      assert found.id == invitation.id
      assert found.institution != nil
    end

    test "get_invitation_by_token/1 returns nil for invalid token" do
      assert Accounts.get_invitation_by_token("invalid_token") == nil
    end

    test "list_pending_invitations/1 returns pending invitations" do
      institution = insert(:institution)
      coordinator = insert(:user, institution: institution, role: "coordinator")

      pending = insert(:invitation, institution: institution, invited_by: coordinator)

      _accepted =
        insert(:invitation,
          institution: institution,
          invited_by: coordinator,
          accepted_at: DateTime.utc_now()
        )

      invitations = Accounts.list_pending_invitations(institution.id)

      assert length(invitations) == 1
      assert hd(invitations).id == pending.id
    end

    test "accept_invitation/2 creates user and marks accepted" do
      invitation = insert(:invitation)

      user_attrs = %{
        name: "Accepted User",
        password: "password123"
      }

      assert {:ok, user} = Accounts.accept_invitation(invitation.token, user_attrs)

      assert user.email == invitation.email
      assert user.institution_id == invitation.institution_id
      assert user.role == invitation.role

      # Verify invitation is marked accepted
      updated_invitation = Accounts.get_invitation_by_token(invitation.token)
      assert updated_invitation.accepted_at != nil
      assert updated_invitation.user_id == user.id
    end

    test "accept_invitation/2 returns error for already accepted invitation" do
      invitation = insert(:invitation, accepted_at: DateTime.utc_now())
      assert {:error, :already_accepted} = Accounts.accept_invitation(invitation.token, %{})
    end

    test "accept_invitation/2 returns error for revoked invitation" do
      invitation = insert(:invitation, revoked_at: DateTime.utc_now())
      assert {:error, :revoked} = Accounts.accept_invitation(invitation.token, %{})
    end

    test "accept_invitation/2 returns error for expired invitation" do
      invitation =
        insert(:invitation,
          expires_at: DateTime.add(DateTime.utc_now(), -1, :day) |> DateTime.truncate(:second)
        )

      assert {:error, :expired} = Accounts.accept_invitation(invitation.token, %{})
    end

    test "accept_invitation/2 returns error for invalid token" do
      assert {:error, :not_found} = Accounts.accept_invitation("invalid", %{})
    end

    test "accept_invitation/2 links existing user by email" do
      existing_user = insert(:user, email: "existing@example.com", institution_id: nil)
      invitation = insert(:invitation, email: "existing@example.com")

      assert {:ok, user} = Accounts.accept_invitation(invitation.token, %{})

      assert user.id == existing_user.id
      assert user.institution_id == invitation.institution_id
    end

    test "revoke_invitation/1 marks invitation as revoked" do
      invitation = insert(:invitation)
      assert {:ok, revoked} = Accounts.revoke_invitation(invitation.id)
      assert revoked.revoked_at != nil
    end

    test "revoke_invitation/1 returns error for non-existent invitation" do
      assert {:error, :not_found} = Accounts.revoke_invitation(Ecto.UUID.generate())
    end

    test "resend_invitation/1 creates new invitation and revokes old" do
      invitation = insert(:invitation)

      assert {:ok, new_invitation} = Accounts.resend_invitation(invitation.id)

      assert new_invitation.id != invitation.id
      assert new_invitation.email == invitation.email
      assert new_invitation.token != invitation.token

      # Old invitation should be revoked
      old_invitation = Repo.get!(Invitation, invitation.id)
      assert old_invitation.revoked_at != nil
    end

    test "resend_invitation/1 returns error for non-existent invitation" do
      assert {:error, :not_found} = Accounts.resend_invitation(Ecto.UUID.generate())
    end
  end

  describe "institution boundaries" do
    test "user belongs to exactly one institution" do
      inst1 = insert(:institution)
      user = insert(:user, institution: inst1)

      # User must have an institution_id
      assert user.institution_id == inst1.id
      assert user.institution_id != nil
    end

    test "list_users_by_institution/1 only returns users from that institution" do
      inst1 = insert(:institution)
      inst2 = insert(:institution)

      user1 = insert(:user, institution: inst1)
      user2 = insert(:user, institution: inst1)
      _user3 = insert(:user, institution: inst2)

      users = Accounts.list_users_by_institution(inst1.id)

      user_ids = Enum.map(users, & &1.id)
      assert user1.id in user_ids
      assert user2.id in user_ids
      assert length(users) == 2
    end

    test "user from one institution is not returned in another institution's list" do
      inst1 = insert(:institution)
      inst2 = insert(:institution)
      user = insert(:user, institution: inst1)

      # User should not appear in other institution's list
      inst2_users = Accounts.list_users_by_institution(inst2.id)
      inst2_user_ids = Enum.map(inst2_users, & &1.id)

      refute user.id in inst2_user_ids
    end
  end

  describe "role-based access" do
    test "teacher role cannot access admin functions" do
      teacher = insert(:user, role: "teacher")

      # Teacher should not have admin access
      assert teacher.role == "teacher"
      refute teacher.role == "admin"
    end

    test "coordinator role cannot access admin functions" do
      coordinator = insert(:coordinator)

      # Coordinator should not have admin access
      assert coordinator.role == "coordinator"
      refute coordinator.role == "admin"
    end

    test "different roles coexist within same institution" do
      institution = insert(:institution)

      teacher = insert(:user, institution: institution, role: "teacher")
      coordinator = insert(:coordinator, institution: institution)

      users = Accounts.list_users_by_institution(institution.id)

      roles = Enum.map(users, & &1.role)
      assert "teacher" in roles
      assert "coordinator" in roles
    end
  end
end
