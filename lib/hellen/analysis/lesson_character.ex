defmodule Hellen.Analysis.LessonCharacter do
  @moduledoc """
  Schema for identified speakers/characters in lesson transcriptions.

  Stores information about each distinct speaker detected during analysis,
  including their role (teacher/student), speech patterns, engagement level,
  and representative quotes.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "lesson_characters" do
    field :identifier, :string
    field :role, :string
    field :speech_count, :integer
    field :word_count, :integer
    field :characteristics, {:array, :string}
    field :speech_patterns, :string
    field :key_quotes, {:array, :string}
    field :sentiment, :string
    field :engagement_level, :string

    belongs_to :analysis, Hellen.Analysis.Analysis

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @roles ["teacher", "student", "assistant", "guest", "other"]
  @sentiments ["positive", "neutral", "negative", "mixed"]
  @engagement_levels ["high", "medium", "low"]

  @doc false
  def changeset(lesson_character, attrs) do
    lesson_character
    |> cast(attrs, [
      :identifier,
      :role,
      :speech_count,
      :word_count,
      :characteristics,
      :speech_patterns,
      :key_quotes,
      :sentiment,
      :engagement_level,
      :analysis_id
    ])
    |> validate_required([:identifier, :role, :analysis_id])
    |> validate_inclusion(:role, @roles)
    |> validate_inclusion(:sentiment, @sentiments ++ [nil])
    |> validate_inclusion(:engagement_level, @engagement_levels ++ [nil])
    |> validate_number(:speech_count, greater_than_or_equal_to: 0)
    |> validate_number(:word_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:analysis_id)
  end
end
