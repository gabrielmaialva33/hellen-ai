defmodule Hellen.Analysis.Analysis do
  @moduledoc """
  Schema for pedagogical analyses with overall score, BNCC matches, and bullying alerts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "analyses" do
    field :analysis_type, :string
    field :model_used, :string
    field :raw_response, :map
    field :result, :map
    field :overall_score, :float
    field :processing_time_ms, :integer
    field :tokens_used, :integer

    belongs_to :lesson, Hellen.Lessons.Lesson
    belongs_to :institution, Hellen.Accounts.Institution
    has_many :bncc_matches, Hellen.Analysis.BnccMatch
    has_many :bullying_alerts, Hellen.Analysis.BullyingAlert
    has_many :lesson_characters, Hellen.Analysis.LessonCharacter

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @analysis_types ["full", "bncc", "bullying", "engagement", "time_management"]

  @doc false
  def changeset(analysis, attrs) do
    analysis
    |> cast(attrs, [
      :analysis_type,
      :model_used,
      :raw_response,
      :result,
      :overall_score,
      :processing_time_ms,
      :tokens_used,
      :lesson_id,
      :institution_id
    ])
    |> validate_required([:analysis_type, :lesson_id])
    |> validate_inclusion(:analysis_type, @analysis_types)
    |> validate_number(:overall_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> foreign_key_constraint(:lesson_id)
    |> foreign_key_constraint(:institution_id)
  end
end
