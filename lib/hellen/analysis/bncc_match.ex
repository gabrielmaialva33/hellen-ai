defmodule Hellen.Analysis.BnccMatch do
  @moduledoc """
  Schema for BNCC competency matches found during lesson analysis.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "bncc_matches" do
    field :competencia_code, :string
    field :competencia_name, :string
    field :match_score, :float
    field :evidence_text, :string
    field :evidence_timestamp_start, :float
    field :evidence_timestamp_end, :float

    belongs_to :analysis, Hellen.Analysis.Analysis

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(bncc_match, attrs) do
    bncc_match
    |> cast(attrs, [
      :competencia_code,
      :competencia_name,
      :match_score,
      :evidence_text,
      :evidence_timestamp_start,
      :evidence_timestamp_end,
      :analysis_id
    ])
    |> validate_required([:competencia_code, :analysis_id])
    |> validate_number(:match_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> foreign_key_constraint(:analysis_id)
  end
end
