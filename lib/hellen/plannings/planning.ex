defmodule Hellen.Plannings.Planning do
  @moduledoc """
  Schema for lesson plannings.

  Plannings can be created manually or generated from lesson transcriptions using AI.
  They include objectives, BNCC alignments, methodology, and assessment criteria.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Hellen.Accounts.{Institution, User}
  alias Hellen.Lessons.Lesson

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(draft published archived)
  @subjects ~w(
    portugues matematica ciencias historia geografia
    arte educacao_fisica ingles espanhol
    ensino_religioso educacao_infantil
  )
  @grade_levels ~w(
    infantil_1 infantil_2 infantil_3 infantil_4 infantil_5
    1_ano 2_ano 3_ano 4_ano 5_ano
    6_ano 7_ano 8_ano 9_ano
    1_em 2_em 3_em
    eja_fundamental eja_medio
  )

  schema "plannings" do
    field :title, :string
    field :description, :string
    field :subject, :string
    field :grade_level, :string
    field :duration_minutes, :integer
    field :objectives, {:array, :string}, default: []
    field :bncc_codes, {:array, :string}, default: []
    field :content, :map, default: %{}
    field :materials, {:array, :string}, default: []
    field :methodology, :string
    field :assessment_criteria, :string
    field :status, :string, default: "draft"
    field :generated_by_ai, :boolean, default: false
    field :embeddings_indexed, :boolean, default: false
    field :metadata, :map, default: %{}

    belongs_to :user, User
    belongs_to :institution, Institution
    belongs_to :source_lesson, Lesson

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(title subject grade_level user_id)a
  @optional_fields ~w(
    description duration_minutes objectives bncc_codes content
    materials methodology assessment_criteria status generated_by_ai
    embeddings_indexed metadata institution_id source_lesson_id
  )a

  def changeset(planning, attrs) do
    planning
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:subject, @subjects)
    |> validate_inclusion(:grade_level, @grade_levels)
    |> validate_number(:duration_minutes, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:institution_id)
    |> foreign_key_constraint(:source_lesson_id)
  end

  def create_changeset(planning, attrs) do
    planning
    |> changeset(attrs)
    |> put_change(:status, "draft")
  end

  def publish_changeset(planning) do
    planning
    |> change(%{status: "published"})
  end

  def archive_changeset(planning) do
    planning
    |> change(%{status: "archived"})
  end

  def mark_indexed_changeset(planning) do
    planning
    |> change(%{embeddings_indexed: true})
  end

  # Content structure for AI-generated plannings
  @doc """
  Expected content structure:
  %{
    "introduction" => "Contextualização inicial...",
    "development" => [
      %{"step" => 1, "activity" => "...", "duration_minutes" => 10},
      %{"step" => 2, "activity" => "...", "duration_minutes" => 15}
    ],
    "closure" => "Atividade de encerramento...",
    "homework" => "Tarefa para casa...",
    "adaptations" => "Adaptações para alunos com necessidades especiais...",
    "cross_curricular" => ["Arte", "Ciências"]
  }
  """
  def content_template do
    %{
      "introduction" => "",
      "development" => [],
      "closure" => "",
      "homework" => "",
      "adaptations" => "",
      "cross_curricular" => []
    }
  end

  # Helper functions
  def statuses, do: @statuses
  def subjects, do: @subjects
  def grade_levels, do: @grade_levels

  def subject_label(subject) do
    %{
      "portugues" => "Língua Portuguesa",
      "matematica" => "Matemática",
      "ciencias" => "Ciências",
      "historia" => "História",
      "geografia" => "Geografia",
      "arte" => "Arte",
      "educacao_fisica" => "Educação Física",
      "ingles" => "Língua Inglesa",
      "espanhol" => "Língua Espanhola",
      "ensino_religioso" => "Ensino Religioso",
      "educacao_infantil" => "Educação Infantil"
    }[subject] || subject
  end

  def grade_level_label(level) do
    %{
      "infantil_1" => "Infantil 1",
      "infantil_2" => "Infantil 2",
      "infantil_3" => "Infantil 3",
      "infantil_4" => "Infantil 4",
      "infantil_5" => "Infantil 5",
      "1_ano" => "1º Ano",
      "2_ano" => "2º Ano",
      "3_ano" => "3º Ano",
      "4_ano" => "4º Ano",
      "5_ano" => "5º Ano",
      "6_ano" => "6º Ano",
      "7_ano" => "7º Ano",
      "8_ano" => "8º Ano",
      "9_ano" => "9º Ano",
      "1_em" => "1º Médio",
      "2_em" => "2º Médio",
      "3_em" => "3º Médio",
      "eja_fundamental" => "EJA Fundamental",
      "eja_medio" => "EJA Médio"
    }[level] || level
  end

  def status_label(status) do
    %{
      "draft" => "Rascunho",
      "published" => "Publicado",
      "archived" => "Arquivado"
    }[status] || status
  end
end
