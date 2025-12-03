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
end
