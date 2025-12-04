defmodule Hellen.Accounts.Invitation do
  @moduledoc """
  Schema for team invitations.
  Invitations allow coordinators to invite teachers to their institution.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @token_bytes 32
  @expires_in_days 7

  schema "invitations" do
    field :email, :string
    field :name, :string
    field :token, :string
    field :expires_at, :utc_datetime
    field :accepted_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :role, :string, default: "teacher"

    belongs_to :invited_by, Hellen.Accounts.User
    belongs_to :institution, Hellen.Accounts.Institution
    belongs_to :user, Hellen.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :name, :role, :invited_by_id, :institution_id])
    |> validate_required([:email, :institution_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have @ sign and no spaces")
    |> validate_inclusion(:role, ["teacher", "coordinator"])
    |> put_token()
    |> put_expires_at()
  end

  @doc false
  def accept_changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:user_id, :accepted_at])
    |> validate_required([:user_id, :accepted_at])
  end

  @doc false
  def revoke_changeset(invitation) do
    invitation
    |> change(revoked_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp put_token(changeset) do
    if get_field(changeset, :token) do
      changeset
    else
      token =
        :crypto.strong_rand_bytes(@token_bytes)
        |> Base.url_encode64(padding: false)

      put_change(changeset, :token, token)
    end
  end

  defp put_expires_at(changeset) do
    if get_field(changeset, :expires_at) do
      changeset
    else
      expires_at =
        DateTime.utc_now()
        |> DateTime.add(@expires_in_days, :day)
        |> DateTime.truncate(:second)

      put_change(changeset, :expires_at, expires_at)
    end
  end

  @doc """
  Checks if the invitation is valid (not expired, not revoked, not accepted).
  """
  def valid?(%__MODULE__{} = invitation) do
    now = DateTime.utc_now()

    is_nil(invitation.revoked_at) and
      is_nil(invitation.accepted_at) and
      DateTime.compare(invitation.expires_at, now) == :gt
  end

  @doc """
  Checks if the invitation is expired.
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end
end
