defmodule Hellen.Accounts do
  @moduledoc """
  The Accounts context - manages users and institutions.
  """

  import Ecto.Query, warn: false

  alias Hellen.Accounts.{Institution, User}
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
end
