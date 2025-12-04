defmodule Hellen.Accounts.User do
  @moduledoc """
  Schema for users (teachers, coordinators, admins) with authentication and credits.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @signup_bonus 2

  schema "users" do
    field :email, :string
    field :name, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :role, :string, default: "teacher"
    field :credits, :integer, default: @signup_bonus
    field :plan, :string, default: "free"

    # Firebase Auth fields
    field :firebase_uid, :string
    field :email_verified, :boolean, default: false

    # Stripe fields
    field :stripe_customer_id, :string

    belongs_to :institution, Hellen.Accounts.Institution
    has_many :lessons, Hellen.Lessons.Lesson
    has_many :credit_transactions, Hellen.Billing.CreditTransaction

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :name,
      :role,
      :credits,
      :plan,
      :institution_id,
      :firebase_uid,
      :email_verified,
      :stripe_customer_id
    ])
    |> validate_required([:email, :name])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
    |> unique_constraint(:firebase_uid)
    |> validate_inclusion(:role, ["teacher", "coordinator", "admin"])
    |> validate_inclusion(:plan, ["free", "pro", "enterprise"])
    |> validate_number(:credits, greater_than_or_equal_to: 0)
  end

  @doc false
  def registration_changeset(user, attrs) do
    user
    |> changeset(attrs)
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> hash_password()
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    end
  end

  @doc "Changeset for updating user password"
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> hash_password()
  end

  @doc "Changeset for updating profile (name, email only)"
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
  end

  def valid_password?(%__MODULE__{password_hash: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
