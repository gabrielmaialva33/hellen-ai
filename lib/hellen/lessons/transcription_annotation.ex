defmodule Hellen.Lessons.TranscriptionAnnotation do
  @moduledoc """
  Schema for user annotations on lesson transcriptions.

  Allows teachers to highlight and comment on specific text selections
  within a transcription for review and reference.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @derive {Jason.Encoder,
           only: [:id, :content, :selection_start, :selection_end, :selection_text, :lesson_id]}

  schema "transcription_annotations" do
    field :content, :string
    field :selection_start, :integer
    field :selection_end, :integer
    field :selection_text, :string
    field :lesson_id, :binary_id
    field :user_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transcription_annotation, attrs) do
    transcription_annotation
    |> cast(attrs, [
      :content,
      :selection_start,
      :selection_end,
      :selection_text,
      :lesson_id,
      :user_id
    ])
    |> validate_required([:content, :selection_start, :selection_end, :selection_text])
    |> foreign_key_constraint(:lesson_id)
    |> foreign_key_constraint(:user_id)
  end
end
