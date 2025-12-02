defmodule Hellen.Accounts.Institution do
  @moduledoc """
  Schema for educational institutions with plan and settings.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "institutions" do
    field :name, :string
    field :plan, :string, default: "free"
    field :settings, :map, default: %{}

    has_many :users, Hellen.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(institution, attrs) do
    institution
    |> cast(attrs, [:name, :plan, :settings])
    |> validate_required([:name])
    |> validate_inclusion(:plan, ["free", "pro", "enterprise"])
  end
end
