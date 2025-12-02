defmodule Hellen.Lessons.Lesson do
  @moduledoc """
  Schema for recorded lessons with audio/video URLs and processing status.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "lessons" do
    field :title, :string
    field :description, :string
    field :video_url, :string
    field :audio_url, :string
    field :duration_seconds, :integer
    field :grade_level, :string
    field :subject, :string
    field :status, :string, default: "pending"
    field :metadata, :map, default: %{}

    belongs_to :user, Hellen.Accounts.User
    has_one :transcription, Hellen.Lessons.Transcription
    has_many :analyses, Hellen.Analysis.Analysis

    timestamps(type: :utc_datetime)
  end

  @statuses ["pending", "uploading", "transcribing", "analyzing", "completed", "failed"]

  @doc false
  def changeset(lesson, attrs) do
    lesson
    |> cast(attrs, [
      :title,
      :description,
      :video_url,
      :audio_url,
      :duration_seconds,
      :grade_level,
      :subject,
      :status,
      :metadata,
      :user_id
    ])
    |> validate_required([:title, :user_id])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:user_id)
  end

  def status_changeset(lesson, status) do
    lesson
    |> change(status: status)
    |> validate_inclusion(:status, @statuses)
  end
end
