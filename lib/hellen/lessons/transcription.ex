defmodule Hellen.Lessons.Transcription do
  @moduledoc """
  Schema for lesson transcriptions with full text, segments, and confidence score.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transcriptions" do
    field :full_text, :string
    field :language, :string, default: "pt-BR"
    field :confidence_score, :float
    field :word_count, :integer
    field :segments, {:array, :map}, default: []

    belongs_to :lesson, Hellen.Lessons.Lesson

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(transcription, attrs) do
    transcription
    |> cast(attrs, [:full_text, :language, :confidence_score, :word_count, :segments, :lesson_id])
    |> validate_required([:lesson_id])
    |> unique_constraint(:lesson_id)
    |> foreign_key_constraint(:lesson_id)
    |> compute_word_count()
  end

  defp compute_word_count(changeset) do
    case get_change(changeset, :full_text) do
      nil -> changeset
      text -> put_change(changeset, :word_count, text |> String.split() |> length())
    end
  end
end
