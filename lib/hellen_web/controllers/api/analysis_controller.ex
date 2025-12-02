defmodule HellenWeb.API.AnalysisController do
  use HellenWeb, :controller

  alias Hellen.Analysis

  action_fallback HellenWeb.FallbackController

  def index(conn, %{"lesson_id" => lesson_id}) do
    analyses = Analysis.list_analyses_by_lesson(lesson_id)
    render(conn, :index, analyses: analyses)
  end

  def show(conn, %{"id" => id}) do
    analysis = Analysis.get_analysis_with_details!(id)
    render(conn, :show, analysis: analysis)
  end
end
