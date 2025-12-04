defmodule Hellen.Reports do
  @moduledoc """
  Context for generating PDF reports using ChromicPDF.

  Supports three report types:
  - Monthly Institution Report: Overview of metrics, teacher rankings, alerts
  - Individual Teacher Report: Performance history and statistics
  - Analysis Export: Detailed export of a single analysis
  """

  import Ecto.Query, warn: false

  alias Hellen.Accounts
  alias Hellen.Accounts.User
  alias Hellen.Analysis, as: AnalysisContext
  alias Hellen.Analysis.{Analysis, BnccMatch, BullyingAlert}
  alias Hellen.Lessons.Lesson
  alias Hellen.Repo

  @templates_path "lib/hellen/reports/templates"

  # ============================================
  # Monthly Institution Report
  # ============================================

  @doc """
  Generate a monthly report PDF for an institution.

  Options:
    - month: Integer (1-12), defaults to current month
    - year: Integer, defaults to current year

  Returns {:ok, pdf_binary} or {:error, reason}
  """
  @spec generate_monthly_report(binary(), keyword()) :: {:ok, binary()} | {:error, term()}
  def generate_monthly_report(institution_id, opts \\ []) do
    {month, year} = get_period(opts)
    institution = Accounts.get_institution!(institution_id)

    data = %{
      institution: institution,
      period: format_period(month, year),
      generated_at: DateTime.utc_now(),
      stats: get_monthly_stats(institution_id, month, year),
      teachers_ranking: get_teachers_ranking(institution_id, month, year),
      alerts_summary: get_alerts_summary(institution_id, month, year),
      bncc_coverage: get_institution_bncc_coverage(institution_id, month, year)
    }

    render_pdf("monthly_report.html.eex", data)
  end

  defp get_monthly_stats(institution_id, month, year) do
    {start_date, end_date} = month_range(month, year)

    teachers_count =
      User
      |> where([u], u.institution_id == ^institution_id)
      |> Repo.aggregate(:count)

    lessons_count =
      Lesson
      |> where([l], l.institution_id == ^institution_id)
      |> where([l], l.inserted_at >= ^start_date and l.inserted_at < ^end_date)
      |> Repo.aggregate(:count)

    analyses_count =
      Analysis
      |> where([a], a.institution_id == ^institution_id)
      |> where([a], a.inserted_at >= ^start_date and a.inserted_at < ^end_date)
      |> Repo.aggregate(:count)

    alerts_count =
      BullyingAlert
      |> join(:inner, [b], a in assoc(b, :analysis))
      |> where([b, a], a.institution_id == ^institution_id)
      |> where([b], b.inserted_at >= ^start_date and b.inserted_at < ^end_date)
      |> Repo.aggregate(:count)

    avg_score =
      Analysis
      |> where([a], a.institution_id == ^institution_id)
      |> where([a], a.inserted_at >= ^start_date and a.inserted_at < ^end_date)
      |> where([a], not is_nil(a.overall_score))
      |> Repo.aggregate(:avg, :overall_score)

    %{
      teachers: teachers_count,
      lessons: lessons_count,
      analyses: analyses_count,
      alerts: alerts_count,
      avg_score: avg_score && Float.round(avg_score, 1)
    }
  end

  defp get_teachers_ranking(institution_id, month, year) do
    {start_date, end_date} = month_range(month, year)

    User
    |> where([u], u.institution_id == ^institution_id)
    |> join(:left, [u], l in Lesson,
      on: l.user_id == u.id and l.inserted_at >= ^start_date and l.inserted_at < ^end_date
    )
    |> join(:left, [u, l], a in Analysis, on: a.lesson_id == l.id)
    |> group_by([u, l, a], [u.id, u.name])
    |> select([u, l, a], %{
      name: u.name,
      lessons: count(l.id, :distinct),
      analyses: count(a.id),
      avg_score: avg(a.overall_score)
    })
    |> order_by([u, l, a], desc: count(l.id, :distinct))
    |> limit(10)
    |> Repo.all()
    |> Enum.map(fn row ->
      %{row | avg_score: row.avg_score && Float.round(row.avg_score, 1)}
    end)
  end

  defp get_alerts_summary(institution_id, month, year) do
    {start_date, end_date} = month_range(month, year)

    query =
      BullyingAlert
      |> join(:inner, [b], a in assoc(b, :analysis))
      |> where([b, a], a.institution_id == ^institution_id)
      |> where([b], b.inserted_at >= ^start_date and b.inserted_at < ^end_date)

    by_severity =
      query
      |> group_by([b], b.severity)
      |> select([b], {b.severity, count(b.id)})
      |> Repo.all()
      |> Map.new()

    by_type =
      query
      |> group_by([b], b.alert_type)
      |> select([b], {b.alert_type, count(b.id)})
      |> Repo.all()
      |> Map.new()

    %{by_severity: by_severity, by_type: by_type}
  end

  defp get_institution_bncc_coverage(institution_id, month, year) do
    {start_date, end_date} = month_range(month, year)

    BnccMatch
    |> join(:inner, [m], a in assoc(m, :analysis))
    |> where([m, a], a.institution_id == ^institution_id)
    |> where([m, a], a.inserted_at >= ^start_date and a.inserted_at < ^end_date)
    |> group_by([m], [m.competencia_code, m.competencia_name])
    |> select([m], %{
      code: m.competencia_code,
      name: m.competencia_name,
      count: count(m.id)
    })
    |> order_by([m], desc: count(m.id))
    |> limit(15)
    |> Repo.all()
  end

  # ============================================
  # Teacher Report
  # ============================================

  @doc """
  Generate a performance report PDF for an individual teacher.

  Options:
    - month: Integer (1-12), defaults to current month
    - year: Integer, defaults to current year

  Returns {:ok, pdf_binary} or {:error, reason}
  """
  @spec generate_teacher_report(binary(), keyword()) :: {:ok, binary()} | {:error, term()}
  def generate_teacher_report(user_id, opts \\ []) do
    {month, year} = get_period(opts)
    user = Accounts.get_user!(user_id)

    institution =
      if user.institution_id do
        Accounts.get_institution!(user.institution_id)
      else
        nil
      end

    data = %{
      teacher: user,
      institution: institution,
      period: format_period(month, year),
      generated_at: DateTime.utc_now(),
      stats: get_teacher_stats(user_id, month, year),
      score_history: get_teacher_score_history(user_id, month, year),
      bncc_coverage: get_teacher_bncc_coverage(user_id, month, year),
      recent_lessons: get_teacher_recent_lessons(user_id, month, year)
    }

    render_pdf("teacher_report.html.eex", data)
  end

  defp get_teacher_stats(user_id, month, year) do
    {start_date, end_date} = month_range(month, year)

    lessons_count =
      Lesson
      |> where([l], l.user_id == ^user_id)
      |> where([l], l.inserted_at >= ^start_date and l.inserted_at < ^end_date)
      |> Repo.aggregate(:count)

    analyses_count =
      Analysis
      |> join(:inner, [a], l in assoc(a, :lesson))
      |> where([a, l], l.user_id == ^user_id)
      |> where([a], a.inserted_at >= ^start_date and a.inserted_at < ^end_date)
      |> Repo.aggregate(:count)

    avg_score =
      Analysis
      |> join(:inner, [a], l in assoc(a, :lesson))
      |> where([a, l], l.user_id == ^user_id)
      |> where([a], a.inserted_at >= ^start_date and a.inserted_at < ^end_date)
      |> where([a], not is_nil(a.overall_score))
      |> Repo.aggregate(:avg, :overall_score)

    {trend, _change} = AnalysisContext.get_user_trend(user_id)

    %{
      lessons: lessons_count,
      analyses: analyses_count,
      avg_score: avg_score && Float.round(avg_score, 1),
      trend: trend
    }
  end

  defp get_teacher_score_history(user_id, month, year) do
    {start_date, end_date} = month_range(month, year)

    Analysis
    |> join(:inner, [a], l in assoc(a, :lesson))
    |> where([a, l], l.user_id == ^user_id)
    |> where([a], a.inserted_at >= ^start_date and a.inserted_at < ^end_date)
    |> where([a], not is_nil(a.overall_score))
    |> order_by([a], asc: a.inserted_at)
    |> select([a, l], %{
      date: a.inserted_at,
      score: a.overall_score,
      lesson_title: l.title
    })
    |> Repo.all()
  end

  defp get_teacher_bncc_coverage(user_id, month, year) do
    {start_date, end_date} = month_range(month, year)

    BnccMatch
    |> join(:inner, [m], a in assoc(m, :analysis))
    |> join(:inner, [m, a], l in assoc(a, :lesson))
    |> where([m, a, l], l.user_id == ^user_id)
    |> where([m, a], a.inserted_at >= ^start_date and a.inserted_at < ^end_date)
    |> group_by([m], [m.competencia_code, m.competencia_name])
    |> select([m], %{
      code: m.competencia_code,
      name: m.competencia_name,
      count: count(m.id),
      avg_score: avg(m.match_score)
    })
    |> order_by([m], desc: count(m.id))
    |> limit(10)
    |> Repo.all()
    |> Enum.map(fn row ->
      %{row | avg_score: row.avg_score && Float.round(row.avg_score, 1)}
    end)
  end

  defp get_teacher_recent_lessons(user_id, month, year) do
    {start_date, end_date} = month_range(month, year)

    Lesson
    |> where([l], l.user_id == ^user_id)
    |> where([l], l.inserted_at >= ^start_date and l.inserted_at < ^end_date)
    |> order_by([l], desc: l.inserted_at)
    |> limit(10)
    |> preload(:analyses)
    |> Repo.all()
    |> Enum.map(fn lesson ->
      latest_analysis = Enum.max_by(lesson.analyses, & &1.inserted_at, fn -> nil end)

      %{
        title: lesson.title || "Aula sem titulo",
        date: lesson.inserted_at,
        status: lesson.status,
        score: latest_analysis && latest_analysis.overall_score
      }
    end)
  end

  # ============================================
  # Analysis Export
  # ============================================

  @doc """
  Generate a PDF export for a single analysis.
  Includes full analysis details, BNCC matches, and bullying alerts.

  Returns {:ok, pdf_binary} or {:error, reason}
  """
  @spec generate_analysis_export(binary()) :: {:ok, binary()} | {:error, term()}
  def generate_analysis_export(analysis_id) do
    analysis =
      Analysis
      |> Repo.get!(analysis_id)
      |> Repo.preload([:bncc_matches, :bullying_alerts, lesson: :user])

    data = %{
      analysis: analysis,
      lesson: analysis.lesson,
      teacher: analysis.lesson.user,
      generated_at: DateTime.utc_now(),
      bncc_matches: analysis.bncc_matches,
      bullying_alerts: analysis.bullying_alerts,
      result: analysis.result
    }

    render_pdf("analysis_export.html.eex", data)
  end

  # ============================================
  # PDF Rendering
  # ============================================

  defp render_pdf(template, data) do
    html = render_template(template, data)

    case ChromicPDF.print_to_pdf({:html, html}, pdf_options()) do
      {:ok, pdf_binary} -> {:ok, pdf_binary}
      {:error, reason} -> {:error, reason}
    end
  end

  defp render_template(template, data) do
    template_path = Path.join([@templates_path, template])
    styles = render_styles()

    assigns =
      data
      |> Map.put(:styles, styles)
      |> Map.put(:h, Hellen.Reports.Helpers)
      |> Enum.into([])

    EEx.eval_file(template_path, assigns: assigns)
  end

  defp render_styles do
    styles_path = Path.join([@templates_path, "_styles.html.eex"])

    if File.exists?(styles_path) do
      EEx.eval_file(styles_path, [])
    else
      default_styles()
    end
  end

  defp pdf_options do
    [
      print_to_pdf: %{
        paperWidth: 8.27,
        paperHeight: 11.69,
        marginTop: 0.4,
        marginBottom: 0.4,
        marginLeft: 0.4,
        marginRight: 0.4,
        printBackground: true
      }
    ]
  end

  # ============================================
  # Helpers
  # ============================================

  defp get_period(opts) do
    now = Date.utc_today()
    month = Keyword.get(opts, :month, now.month)
    year = Keyword.get(opts, :year, now.year)
    {month, year}
  end

  defp month_range(month, year) do
    start_date = Date.new!(year, month, 1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    end_date =
      start_date
      |> DateTime.to_date()
      |> Date.end_of_month()
      |> Date.add(1)
      |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    {start_date, end_date}
  end

  defp format_period(month, year) do
    months = [
      "Janeiro",
      "Fevereiro",
      "Marco",
      "Abril",
      "Maio",
      "Junho",
      "Julho",
      "Agosto",
      "Setembro",
      "Outubro",
      "Novembro",
      "Dezembro"
    ]

    "#{Enum.at(months, month - 1)} #{year}"
  end

  defp default_styles do
    """
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { font-family: 'Helvetica Neue', Arial, sans-serif; font-size: 12px; color: #1f2937; line-height: 1.5; }
      .header { background: #4f46e5; color: white; padding: 24px; margin-bottom: 24px; }
      .header h1 { font-size: 24px; margin-bottom: 4px; }
      .header p { opacity: 0.9; }
      .section { margin-bottom: 24px; page-break-inside: avoid; }
      .section-title { font-size: 16px; font-weight: 600; color: #111827; margin-bottom: 12px; padding-bottom: 8px; border-bottom: 2px solid #e5e7eb; }
      .stats-grid { display: flex; gap: 16px; flex-wrap: wrap; }
      .stat-card { background: #f9fafb; padding: 16px; border-radius: 8px; flex: 1; min-width: 120px; }
      .stat-card h3 { font-size: 24px; color: #111827; }
      .stat-card p { font-size: 12px; color: #6b7280; }
      table { width: 100%; border-collapse: collapse; margin-top: 8px; }
      th, td { padding: 8px 12px; text-align: left; border-bottom: 1px solid #e5e7eb; }
      th { background: #f9fafb; font-weight: 600; color: #374151; }
      .badge { display: inline-block; padding: 2px 8px; border-radius: 9999px; font-size: 10px; font-weight: 500; }
      .badge-success { background: #d1fae5; color: #065f46; }
      .badge-warning { background: #fef3c7; color: #92400e; }
      .badge-error { background: #fee2e2; color: #991b1b; }
      .footer { margin-top: 32px; padding-top: 16px; border-top: 1px solid #e5e7eb; font-size: 10px; color: #9ca3af; text-align: center; }
    </style>
    """
  end
end

defmodule Hellen.Reports.Helpers do
  @moduledoc """
  Template helper functions for PDF report generation.
  """

  def score_class(nil), do: ""
  def score_class(score) when score >= 8, do: "score-good"
  def score_class(score) when score >= 6, do: "score-average"
  def score_class(_), do: "score-poor"

  def severity_order("high"), do: 1
  def severity_order("medium"), do: 2
  def severity_order("low"), do: 3
  def severity_order(_), do: 4

  def severity_badge_class("high"), do: "badge-error"
  def severity_badge_class("medium"), do: "badge-warning"
  def severity_badge_class("low"), do: "badge-success"
  def severity_badge_class(_), do: "badge-default"

  def severity_label("high"), do: "Alta"
  def severity_label("medium"), do: "Media"
  def severity_label("low"), do: "Baixa"
  def severity_label(other), do: other || "Desconhecido"

  def alert_type_label("verbal_aggression"), do: "Agressao Verbal"
  def alert_type_label("exclusion"), do: "Exclusao"
  def alert_type_label("intimidation"), do: "Intimidacao"
  def alert_type_label("cyberbullying"), do: "Cyberbullying"
  def alert_type_label(other), do: String.capitalize(other || "Outro")

  def status_badge_class("completed"), do: "badge-success"
  def status_badge_class("analyzing"), do: "badge-info"
  def status_badge_class("transcribing"), do: "badge-info"
  def status_badge_class("pending"), do: "badge-warning"
  def status_badge_class("failed"), do: "badge-error"
  def status_badge_class(_), do: "badge-default"

  def status_label("completed"), do: "Concluida"
  def status_label("analyzing"), do: "Analisando"
  def status_label("transcribing"), do: "Transcrevendo"
  def status_label("transcribed"), do: "Transcrita"
  def status_label("pending"), do: "Pendente"
  def status_label("failed"), do: "Falhou"
  def status_label(_), do: "Desconhecido"

  def trend_class(:improving), do: "trend-up"
  def trend_class(:declining), do: "trend-down"
  def trend_class(_), do: "trend-stable"

  def trend_label(:improving), do: "Em alta"
  def trend_label(:declining), do: "Em baixa"
  def trend_label(_), do: "Estavel"

  def truncate(nil, _), do: ""
  def truncate(string, max) when byte_size(string) <= max, do: string
  def truncate(string, max), do: String.slice(string, 0, max) <> "..."

  def format_date(nil), do: "-"

  def format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y")
  end

  def format_date(%Date{} = d) do
    Calendar.strftime(d, "%d/%m/%Y")
  end

  def format_datetime(nil), do: "-"

  def format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y as %H:%M")
  end

  def sort_by_severity(items) do
    Enum.sort_by(items, fn {k, _v} -> severity_order(k) end)
  end
end
