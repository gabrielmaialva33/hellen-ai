defmodule Hellen.Gamification.UserAchievement do
  @moduledoc """
  Schema for tracking user achievements (badges unlocked).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_achievements" do
    field :achievement_key, :string
    field :unlocked_at, :utc_datetime

    belongs_to :user, Hellen.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_achievement, attrs) do
    user_achievement
    |> cast(attrs, [:user_id, :achievement_key, :unlocked_at])
    |> validate_required([:user_id, :achievement_key, :unlocked_at])
    |> unique_constraint([:user_id, :achievement_key])
    |> foreign_key_constraint(:user_id)
  end
end
