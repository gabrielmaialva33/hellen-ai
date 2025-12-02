defmodule Hellen.Accounts do
  @moduledoc """
  The Accounts context - manages users and institutions.
  """

  import Ecto.Query, warn: false

  alias Hellen.Accounts.{Institution, User}
  alias Hellen.Billing
  alias Hellen.Repo

  ## User

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
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
