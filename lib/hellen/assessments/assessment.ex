defmodule Hellen.Assessments.Assessment do
  @moduledoc """
  Schema for assessments (provas, atividades, simulados).

  Supports multiple question types:
  - multiple_choice: Multiple choice with options
  - true_false: True/False statements
  - short_answer: Short text response
  - essay: Long-form written response
  - matching: Match items between columns
  - fill_blank: Fill in the blank
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Hellen.Plannings.Planning

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "assessments" do
    field :title, :string
    field :description, :string
    field :subject, :string
    field :grade_level, :string
    field :assessment_type, :string, default: "prova"
    field :difficulty_level, :string, default: "medio"
    field :duration_minutes, :integer
    field :total_points, :decimal
    field :instructions, :string
    field :bncc_codes, {:array, :string}, default: []
    field :questions, {:array, :map}, default: []
    field :answer_key, :map, default: %{}
    field :rubrics, :map, default: %{}
    field :status, :string, default: "draft"
    field :generated_by_ai, :boolean, default: false
    field :embeddings_indexed, :boolean, default: false
    field :metadata, :map, default: %{}

    belongs_to :user, Hellen.Accounts.User
    belongs_to :institution, Hellen.Accounts.Institution
    belongs_to :source_planning, Hellen.Plannings.Planning

    timestamps(type: :utc_datetime)
  end

  @doc "Valid assessment types"
  def assessment_types do
    ~w(prova atividade simulado exercicio trabalho quiz)
  end

  @doc "Valid difficulty levels"
  def difficulty_levels do
    ~w(facil medio dificil misto)
  end

  @doc "Valid statuses"
  def statuses do
    ~w(draft published archived)
  end

  @doc "Valid question types"
  def question_types do
    ~w(multiple_choice true_false short_answer essay matching fill_blank)
  end

  @doc "Same subjects as plannings"
  def subjects do
    Planning.subjects()
  end

  @doc "Same grade levels as plannings"
  def grade_levels do
    Planning.grade_levels()
  end

  @doc "Human-readable labels for assessment types"
  def assessment_type_label("prova"), do: "Prova"
  def assessment_type_label("atividade"), do: "Atividade"
  def assessment_type_label("simulado"), do: "Simulado"
  def assessment_type_label("exercicio"), do: "Exercício"
  def assessment_type_label("trabalho"), do: "Trabalho"
  def assessment_type_label("quiz"), do: "Quiz"
  def assessment_type_label(_), do: "Avaliação"

  @doc "Human-readable labels for difficulty levels"
  def difficulty_label("facil"), do: "Fácil"
  def difficulty_label("medio"), do: "Médio"
  def difficulty_label("dificil"), do: "Difícil"
  def difficulty_label("misto"), do: "Misto"
  def difficulty_label(_), do: "Médio"

  @doc "Use planning labels"
  defdelegate subject_label(subject), to: Hellen.Plannings.Planning
  defdelegate grade_level_label(level), to: Hellen.Plannings.Planning
  defdelegate status_label(status), to: Hellen.Plannings.Planning

  @doc "Question type labels"
  def question_type_label("multiple_choice"), do: "Múltipla Escolha"
  def question_type_label("true_false"), do: "Verdadeiro/Falso"
  def question_type_label("short_answer"), do: "Resposta Curta"
  def question_type_label("essay"), do: "Dissertativa"
  def question_type_label("matching"), do: "Associação"
  def question_type_label("fill_blank"), do: "Preencher Lacunas"
  def question_type_label(_), do: "Questão"

  @doc false
  def changeset(assessment, attrs) do
    assessment
    |> cast(attrs, [
      :title,
      :description,
      :subject,
      :grade_level,
      :assessment_type,
      :difficulty_level,
      :duration_minutes,
      :total_points,
      :instructions,
      :bncc_codes,
      :questions,
      :answer_key,
      :rubrics,
      :status,
      :generated_by_ai,
      :embeddings_indexed,
      :metadata,
      :user_id,
      :institution_id,
      :source_planning_id
    ])
    |> validate_required([:title, :subject, :grade_level, :user_id])
    |> validate_inclusion(:subject, subjects())
    |> validate_inclusion(:grade_level, grade_levels())
    |> validate_inclusion(:assessment_type, assessment_types())
    |> validate_inclusion(:difficulty_level, difficulty_levels())
    |> validate_inclusion(:status, statuses())
    |> validate_number(:duration_minutes, greater_than: 0, less_than_or_equal_to: 480)
    |> validate_number(:total_points, greater_than: 0)
    |> validate_questions()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:institution_id)
    |> foreign_key_constraint(:source_planning_id)
  end

  @doc "Changeset for creating from AI generation"
  def ai_changeset(assessment, attrs) do
    assessment
    |> changeset(attrs)
    |> put_change(:generated_by_ai, true)
  end

  @doc "Changeset for publishing"
  def publish_changeset(assessment) do
    assessment
    |> change()
    |> put_change(:status, "published")
    |> validate_questions_for_publish()
  end

  @doc "Changeset for archiving"
  def archive_changeset(assessment) do
    assessment
    |> change()
    |> put_change(:status, "archived")
  end

  defp validate_questions(changeset) do
    case get_change(changeset, :questions) do
      nil ->
        changeset

      questions when is_list(questions) ->
        if Enum.all?(questions, &valid_question?/1) do
          changeset
        else
          add_error(changeset, :questions, "contém questões com formato inválido")
        end

      _ ->
        add_error(changeset, :questions, "deve ser uma lista de questões")
    end
  end

  defp validate_questions_for_publish(changeset) do
    assessment = changeset.data
    questions = assessment.questions || []

    if Enum.empty?(questions) do
      add_error(changeset, :questions, "deve ter pelo menos uma questão para publicar")
    else
      changeset
    end
  end

  defp valid_question?(question) when is_map(question) do
    Map.has_key?(question, "type") and
      Map.has_key?(question, "text") and
      question["type"] in question_types()
  end

  defp valid_question?(_), do: false
end
