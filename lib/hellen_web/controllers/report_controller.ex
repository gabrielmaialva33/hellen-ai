defmodule HellenWeb.ReportController do
  @moduledoc """
  Controller for generating and downloading PDF reports.
  """
  use HellenWeb, :controller

  alias Hellen.Reports

  plug :require_coordinator

  @doc """
  Download monthly institution report.
  """
  def monthly(conn, params) do
    user = conn.assigns.current_user
    institution_id = user.institution_id

    if institution_id do
      month = parse_int(params["month"], Date.utc_today().month)
      year = parse_int(params["year"], Date.utc_today().year)

      case Reports.generate_monthly_report(institution_id, month: month, year: year) do
        {:ok, pdf_binary} ->
          filename = "relatorio-mensal-#{month}-#{year}.pdf"
          send_pdf(conn, pdf_binary, filename)

        {:error, reason} ->
          conn
          |> put_flash(:error, "Erro ao gerar relatorio: #{inspect(reason)}")
          |> redirect(to: ~p"/institution/reports")
      end
    else
      conn
      |> put_flash(:error, "Instituicao nao encontrada")
      |> redirect(to: ~p"/institution/reports")
    end
  end

  @doc """
  Download teacher report.
  """
  def teacher(conn, %{"id" => teacher_id} = params) do
    user = conn.assigns.current_user
    institution_id = user.institution_id

    # Verify the teacher belongs to the same institution
    teacher = Hellen.Accounts.get_user(teacher_id)

    if teacher && teacher.institution_id == institution_id do
      month = parse_int(params["month"], Date.utc_today().month)
      year = parse_int(params["year"], Date.utc_today().year)

      case Reports.generate_teacher_report(teacher_id, month: month, year: year) do
        {:ok, pdf_binary} ->
          teacher_name = String.replace(teacher.name || "professor", " ", "-") |> String.downcase()
          filename = "relatorio-#{teacher_name}-#{month}-#{year}.pdf"
          send_pdf(conn, pdf_binary, filename)

        {:error, reason} ->
          conn
          |> put_flash(:error, "Erro ao gerar relatorio: #{inspect(reason)}")
          |> redirect(to: ~p"/institution/reports")
      end
    else
      conn
      |> put_flash(:error, "Professor nao encontrado")
      |> redirect(to: ~p"/institution/reports")
    end
  end

  @doc """
  Download analysis export.
  """
  def analysis(conn, %{"id" => analysis_id}) do
    user = conn.assigns.current_user
    institution_id = user.institution_id

    # Verify the analysis belongs to the same institution
    try do
      analysis = Hellen.Analysis.get_analysis!(analysis_id, institution_id)

      case Reports.generate_analysis_export(analysis.id) do
        {:ok, pdf_binary} ->
          filename = "analise-#{String.slice(analysis_id, 0, 8)}.pdf"
          send_pdf(conn, pdf_binary, filename)

        {:error, reason} ->
          conn
          |> put_flash(:error, "Erro ao gerar relatorio: #{inspect(reason)}")
          |> redirect(to: ~p"/institution/reports")
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_flash(:error, "Analise nao encontrada")
        |> redirect(to: ~p"/institution/reports")
    end
  end

  # Helpers

  defp send_pdf(conn, pdf_binary, filename) do
    conn
    |> put_resp_content_type("application/pdf")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
    |> send_resp(200, pdf_binary)
  end

  defp parse_int(nil, default), do: default
  defp parse_int("", default), do: default

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_int(value, _default) when is_integer(value), do: value

  defp require_coordinator(conn, _opts) do
    user = conn.assigns[:current_user]

    if user && user.role in ["coordinator", "admin"] do
      conn
    else
      conn
      |> put_flash(:error, "Acesso negado")
      |> redirect(to: ~p"/dashboard")
      |> halt()
    end
  end
end
