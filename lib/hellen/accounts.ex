defmodule Hellen.Accounts do
  @moduledoc """
  The Accounts context - manages users and institutions.
  """

  import Ecto.Query, warn: false

  alias Hellen.Accounts.{Institution, Invitation, User}
  alias Hellen.Billing
  alias Hellen.Repo

  ## User

  def get_user(id), do: Repo.get(User, id)

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_firebase_uid(firebase_uid) when is_binary(firebase_uid) do
    Repo.get_by(User, firebase_uid: firebase_uid)
  end

  @doc """
  Finds or creates a user from Firebase authentication.
  If user exists (by firebase_uid or email), updates and returns it.
  Otherwise, creates a new user.
  """
  def find_or_create_from_firebase(firebase_info) do
    %{firebase_uid: firebase_uid, email: email} = firebase_info

    case get_user_by_firebase_uid(firebase_uid) do
      %User{} = user ->
        # Update user info from Firebase
        update_from_firebase(user, firebase_info)

      nil ->
        # Check if user exists by email
        case get_user_by_email(email) do
          %User{} = user ->
            # Link existing user to Firebase
            update_from_firebase(user, firebase_info)

          nil ->
            # Create new user
            create_from_firebase(firebase_info)
        end
    end
  end

  defp update_from_firebase(user, firebase_info) do
    attrs = %{
      firebase_uid: firebase_info.firebase_uid,
      name: firebase_info[:name] || user.name,
      email_verified: firebase_info[:email_verified] || false
    }

    update_user(user, attrs)
  end

  defp create_from_firebase(firebase_info) do
    attrs = %{
      firebase_uid: firebase_info.firebase_uid,
      email: firebase_info.email,
      name: firebase_info[:name] || "User",
      email_verified: firebase_info[:email_verified] || false,
      role: "teacher",
      plan: "free",
      # Generate random password for Firebase-only users
      password: :crypto.strong_rand_bytes(32) |> Base.encode64()
    }

    register_user(attrs)
  end

  def register_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        # Grant signup bonus
        Billing.grant_signup_bonus(user)
        {:ok, user}

      error ->
        error
    end
  end

  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && User.valid_password?(user, password) ->
        {:ok, user}

      user ->
        {:error, :invalid_password}

      true ->
        {:error, :user_not_found}
    end
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Update user profile (name and email only).
  """
  @spec update_user_profile(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Change user password after verifying current password.
  Returns {:error, :invalid_password} if current password doesn't match.
  """
  @spec change_user_password(User.t(), String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :invalid_password | Ecto.Changeset.t()}
  def change_user_password(%User{} = user, current_password, new_password) do
    if User.valid_password?(user, current_password) do
      user
      |> User.password_changeset(%{password: new_password})
      |> Repo.update()
    else
      {:error, :invalid_password}
    end
  end

  def list_users_by_institution(institution_id) do
    User
    |> where([u], u.institution_id == ^institution_id)
    |> Repo.all()
  end

  ## Institution

  def get_institution!(id), do: Repo.get!(Institution, id)

  def create_institution(attrs \\ %{}) do
    %Institution{}
    |> Institution.changeset(attrs)
    |> Repo.insert()
  end

  def update_institution(%Institution{} = institution, attrs) do
    institution
    |> Institution.changeset(attrs)
    |> Repo.update()
  end

  def list_institutions do
    Repo.all(Institution)
  end

  ## Coordinator Functions

  @doc """
  Get comprehensive statistics for an institution.
  Used by the coordinator dashboard.
  """
  @spec get_institution_stats(binary()) :: map()
  def get_institution_stats(institution_id) do
    teachers_count =
      User
      |> where([u], u.institution_id == ^institution_id)
      |> Repo.aggregate(:count)

    lessons_count =
      Hellen.Lessons.Lesson
      |> where([l], l.institution_id == ^institution_id)
      |> Repo.aggregate(:count)

    analyses_count =
      Hellen.Analysis.Analysis
      |> where([a], a.institution_id == ^institution_id)
      |> Repo.aggregate(:count)

    alerts_count =
      Hellen.Analysis.BullyingAlert
      |> join(:inner, [b], a in assoc(b, :analysis))
      |> where([b, a], a.institution_id == ^institution_id and b.reviewed == false)
      |> Repo.aggregate(:count)

    avg_score =
      Hellen.Analysis.Analysis
      |> where([a], a.institution_id == ^institution_id and not is_nil(a.overall_score))
      |> Repo.aggregate(:avg, :overall_score)

    %{
      teachers: teachers_count,
      lessons: lessons_count,
      analyses: analyses_count,
      alerts: alerts_count,
      avg_score: avg_score && Float.round(avg_score, 1)
    }
  end

  @doc """
  List all teachers in an institution with their statistics.
  Includes lessons count, analyses count, and average score.
  """
  @spec list_teachers_with_stats(binary()) :: [map()]
  def list_teachers_with_stats(institution_id) do
    users =
      User
      |> where([u], u.institution_id == ^institution_id)
      |> order_by([u], desc: u.inserted_at)
      |> Repo.all()

    Enum.map(users, fn user ->
      lessons_query =
        Hellen.Lessons.Lesson
        |> where([l], l.user_id == ^user.id)

      lessons_count = Repo.aggregate(lessons_query, :count)

      last_lesson =
        lessons_query
        |> order_by([l], desc: l.inserted_at)
        |> limit(1)
        |> Repo.one()

      analyses_count =
        Hellen.Analysis.Analysis
        |> join(:inner, [a], l in assoc(a, :lesson))
        |> where([a, l], l.user_id == ^user.id)
        |> Repo.aggregate(:count)

      avg_score =
        Hellen.Analysis.Analysis
        |> join(:inner, [a], l in assoc(a, :lesson))
        |> where([a, l], l.user_id == ^user.id and not is_nil(a.overall_score))
        |> Repo.aggregate(:avg, :overall_score)

      %{
        user: user,
        lessons_count: lessons_count,
        analyses_count: analyses_count,
        avg_score: avg_score && Float.round(avg_score, 1),
        last_activity: last_lesson && last_lesson.inserted_at
      }
    end)
  end

  @doc """
  Get lessons per teacher for chart visualization.
  Returns list of %{name: string, lessons: integer}
  """
  @spec get_lessons_per_teacher(binary()) :: [map()]
  def get_lessons_per_teacher(institution_id) do
    User
    |> where([u], u.institution_id == ^institution_id)
    |> join(:left, [u], l in Hellen.Lessons.Lesson, on: l.user_id == u.id)
    |> group_by([u, l], [u.id, u.name])
    |> select([u, l], %{name: u.name, lessons: count(l.id)})
    |> order_by([u, l], desc: count(l.id))
    |> limit(10)
    |> Repo.all()
  end

  @doc """
  Get recent lessons for an institution.
  Used by coordinator dashboard activity feed.
  """
  @spec list_recent_institution_lessons(binary(), keyword()) :: [Hellen.Lessons.Lesson.t()]
  def list_recent_institution_lessons(institution_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    Hellen.Lessons.Lesson
    |> where([l], l.institution_id == ^institution_id)
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Invite a teacher to an institution.
  Creates a new user with a temporary password.
  """
  @spec invite_teacher_to_institution(binary(), map()) :: {:ok, User.t()} | {:error, term()}
  def invite_teacher_to_institution(institution_id, attrs) do
    # Generate a secure temporary password
    temp_password = :crypto.strong_rand_bytes(16) |> Base.url_encode64()

    user_attrs =
      attrs
      |> Map.put(:institution_id, institution_id)
      |> Map.put(:role, "teacher")
      |> Map.put(:password, temp_password)
      |> Map.put(:plan, "free")

    register_user(user_attrs)
  end

  @doc """
  Remove a teacher from an institution.
  Sets their institution_id to nil.
  """
  @spec remove_teacher_from_institution(User.t()) :: {:ok, User.t()} | {:error, term()}
  def remove_teacher_from_institution(%User{} = user) do
    user
    |> User.changeset(%{institution_id: nil})
    |> Repo.update()
  end

  @doc """
  Update a user's role.
  Only allows teacher <-> coordinator transitions.
  """
  @spec update_user_role(User.t(), String.t()) :: {:ok, User.t()} | {:error, term()}
  def update_user_role(%User{} = user, new_role) when new_role in ["teacher", "coordinator"] do
    user
    |> User.changeset(%{role: new_role})
    |> Repo.update()
  end

  def update_user_role(_user, _role), do: {:error, :invalid_role}

  ## Admin Functions

  @doc """
  Get system-wide statistics for admin dashboard.
  Returns counts for institutions, users, lessons, analyses, and pending alerts.
  """
  @spec get_system_stats() :: map()
  def get_system_stats do
    institutions_count = Repo.aggregate(Institution, :count)
    users_count = Repo.aggregate(User, :count)

    lessons_count = Repo.aggregate(Hellen.Lessons.Lesson, :count)
    analyses_count = Repo.aggregate(Hellen.Analysis.Analysis, :count)

    pending_alerts =
      Hellen.Analysis.BullyingAlert
      |> where([b], b.reviewed == false)
      |> Repo.aggregate(:count)

    users_by_role =
      User
      |> group_by([u], u.role)
      |> select([u], {u.role, count(u.id)})
      |> Repo.all()
      |> Map.new()

    users_by_plan =
      User
      |> group_by([u], u.plan)
      |> select([u], {u.plan, count(u.id)})
      |> Repo.all()
      |> Map.new()

    %{
      institutions: institutions_count,
      users: users_count,
      lessons: lessons_count,
      analyses: analyses_count,
      pending_alerts: pending_alerts,
      users_by_role: users_by_role,
      users_by_plan: users_by_plan
    }
  end

  @doc """
  List all institutions with their statistics.
  """
  @spec list_institutions_with_stats() :: [map()]
  def list_institutions_with_stats do
    institutions = Repo.all(from i in Institution, order_by: [desc: i.inserted_at])

    Enum.map(institutions, fn institution ->
      users_count =
        User
        |> where([u], u.institution_id == ^institution.id)
        |> Repo.aggregate(:count)

      lessons_count =
        Hellen.Lessons.Lesson
        |> where([l], l.institution_id == ^institution.id)
        |> Repo.aggregate(:count)

      analyses_count =
        Hellen.Analysis.Analysis
        |> where([a], a.institution_id == ^institution.id)
        |> Repo.aggregate(:count)

      %{
        institution: institution,
        users_count: users_count,
        lessons_count: lessons_count,
        analyses_count: analyses_count
      }
    end)
  end

  @doc """
  List all users with optional filters.
  Supports: role, plan, institution_id, search (name/email), pagination.
  """
  @spec list_all_users(keyword()) :: {[User.t()], integer()}
  def list_all_users(opts \\ []) do
    role = Keyword.get(opts, :role)
    plan = Keyword.get(opts, :plan)
    institution_id = Keyword.get(opts, :institution_id)
    search = Keyword.get(opts, :search)
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)

    query =
      User
      |> order_by([u], desc: u.inserted_at)

    query =
      if role do
        where(query, [u], u.role == ^role)
      else
        query
      end

    query =
      if plan do
        where(query, [u], u.plan == ^plan)
      else
        query
      end

    query =
      if institution_id do
        where(query, [u], u.institution_id == ^institution_id)
      else
        query
      end

    query =
      if search && search != "" do
        search_term = "%#{search}%"
        where(query, [u], ilike(u.name, ^search_term) or ilike(u.email, ^search_term))
      else
        query
      end

    total = Repo.aggregate(query, :count)

    users =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> preload(:institution)
      |> Repo.all()

    {users, total}
  end

  @doc """
  Admin function to update any user's role.
  Allows all role transitions including admin.
  """
  @spec admin_update_user_role(User.t(), String.t()) :: {:ok, User.t()} | {:error, term()}
  def admin_update_user_role(%User{} = user, new_role)
      when new_role in ["teacher", "coordinator", "admin"] do
    user
    |> User.changeset(%{role: new_role})
    |> Repo.update()
  end

  def admin_update_user_role(_user, _role), do: {:error, :invalid_role}

  @doc """
  Admin function to assign a user to an institution.
  Pass nil to remove from institution.
  """
  @spec admin_assign_user_to_institution(User.t(), binary() | nil) ::
          {:ok, User.t()} | {:error, term()}
  def admin_assign_user_to_institution(%User{} = user, institution_id) do
    user
    |> User.changeset(%{institution_id: institution_id})
    |> Repo.update()
  end

  @doc """
  Admin function to update a user's plan.
  """
  @spec admin_update_user_plan(User.t(), String.t()) :: {:ok, User.t()} | {:error, term()}
  def admin_update_user_plan(%User{} = user, new_plan)
      when new_plan in ["free", "pro", "enterprise"] do
    user
    |> User.changeset(%{plan: new_plan})
    |> Repo.update()
  end

  def admin_update_user_plan(_user, _plan), do: {:error, :invalid_plan}

  @doc """
  Admin function to add credits to a user.
  """
  @spec admin_add_user_credits(User.t(), integer(), String.t()) ::
          {:ok, User.t()} | {:error, term()}
  def admin_add_user_credits(%User{} = user, amount, reason \\ "admin_grant") when amount > 0 do
    Hellen.Billing.add_credits(user, amount, reason)
  end

  @doc """
  Get daily user registrations for the last N days.
  Used for admin dashboard chart.
  """
  @spec get_daily_registrations(integer()) :: [map()]
  def get_daily_registrations(days \\ 30) do
    start_date = Date.utc_today() |> Date.add(-days)

    User
    |> where([u], fragment("?::date", u.inserted_at) >= ^start_date)
    |> group_by([u], fragment("?::date", u.inserted_at))
    |> select([u], %{date: fragment("?::date", u.inserted_at), count: count(u.id)})
    |> order_by([u], fragment("?::date", u.inserted_at))
    |> Repo.all()
  end

  @doc """
  Get recent activity across the platform.
  Returns recent lessons, analyses, and alerts.
  """
  @spec get_recent_platform_activity(integer()) :: map()
  def get_recent_platform_activity(limit \\ 10) do
    recent_lessons =
      Hellen.Lessons.Lesson
      |> order_by([l], desc: l.inserted_at)
      |> limit(^limit)
      |> preload([:user, :institution])
      |> Repo.all()

    recent_analyses =
      Hellen.Analysis.Analysis
      |> order_by([a], desc: a.inserted_at)
      |> limit(^limit)
      |> preload(lesson: [:user, :institution])
      |> Repo.all()

    recent_alerts =
      Hellen.Analysis.BullyingAlert
      |> where([b], b.reviewed == false)
      |> order_by([b], desc: b.inserted_at)
      |> limit(^limit)
      |> preload(analysis: [lesson: [:user, :institution]])
      |> Repo.all()

    %{
      lessons: recent_lessons,
      analyses: recent_analyses,
      alerts: recent_alerts
    }
  end

  ## Invitation Functions

  @doc """
  Creates an invitation to join an institution.
  """
  @spec create_invitation(binary(), map(), User.t()) ::
          {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()}
  def create_invitation(institution_id, attrs, invited_by) do
    attrs =
      attrs
      |> Map.put(:institution_id, institution_id)
      |> Map.put(:invited_by_id, invited_by.id)

    %Invitation{}
    |> Invitation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an invitation by token.
  """
  @spec get_invitation_by_token(String.t()) :: Invitation.t() | nil
  def get_invitation_by_token(token) when is_binary(token) do
    Invitation
    |> where([i], i.token == ^token)
    |> preload([:institution, :invited_by])
    |> Repo.one()
  end

  @doc """
  Lists pending invitations for an institution.
  """
  @spec list_pending_invitations(binary()) :: [Invitation.t()]
  def list_pending_invitations(institution_id) do
    now = DateTime.utc_now()

    Invitation
    |> where([i], i.institution_id == ^institution_id)
    |> where([i], is_nil(i.accepted_at) and is_nil(i.revoked_at))
    |> where([i], i.expires_at > ^now)
    |> order_by([i], desc: i.inserted_at)
    |> preload(:invited_by)
    |> Repo.all()
  end

  @doc """
  Accepts an invitation and creates/updates the user.
  """
  @spec accept_invitation(String.t(), map()) ::
          {:ok, User.t()} | {:error, atom() | Ecto.Changeset.t()}
  def accept_invitation(token, user_attrs) do
    case get_invitation_by_token(token) do
      nil ->
        {:error, :not_found}

      invitation ->
        if Invitation.valid?(invitation) do
          do_accept_invitation(invitation, user_attrs)
        else
          cond do
            invitation.accepted_at -> {:error, :already_accepted}
            invitation.revoked_at -> {:error, :revoked}
            Invitation.expired?(invitation) -> {:error, :expired}
            true -> {:error, :invalid}
          end
        end
    end
  end

  defp do_accept_invitation(invitation, user_attrs) do
    user_attrs =
      user_attrs
      |> Map.put(:institution_id, invitation.institution_id)
      |> Map.put(:role, invitation.role)
      |> Map.put_new(:name, invitation.name)
      |> Map.put_new(:email, invitation.email)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:user, fn _repo, _changes ->
      case get_user_by_email(invitation.email) do
        nil ->
          register_user(user_attrs)

        existing_user ->
          update_user(existing_user, %{
            institution_id: invitation.institution_id,
            role: invitation.role
          })
      end
    end)
    |> Ecto.Multi.update(:invitation, fn %{user: user} ->
      Invitation.accept_changeset(invitation, %{
        user_id: user.id,
        accepted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, _op, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Revokes an invitation.
  """
  @spec revoke_invitation(binary()) :: {:ok, Invitation.t()} | {:error, term()}
  def revoke_invitation(invitation_id) do
    case Repo.get(Invitation, invitation_id) do
      nil ->
        {:error, :not_found}

      invitation ->
        invitation
        |> Invitation.revoke_changeset()
        |> Repo.update()
    end
  end

  @doc """
  Resends an invitation by revoking the old one and creating a new one.
  """
  @spec resend_invitation(binary()) :: {:ok, Invitation.t()} | {:error, term()}
  def resend_invitation(invitation_id) do
    case Repo.get(Invitation, invitation_id) |> Repo.preload(:invited_by) do
      nil ->
        {:error, :not_found}

      invitation ->
        Ecto.Multi.new()
        |> Ecto.Multi.update(:revoke, Invitation.revoke_changeset(invitation))
        |> Ecto.Multi.insert(:new_invitation, fn _changes ->
          %Invitation{}
          |> Invitation.changeset(%{
            email: invitation.email,
            name: invitation.name,
            role: invitation.role,
            institution_id: invitation.institution_id,
            invited_by_id: invitation.invited_by_id
          })
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{new_invitation: new_invitation}} -> {:ok, new_invitation}
          {:error, _op, changeset, _changes} -> {:error, changeset}
        end
    end
  end
end
