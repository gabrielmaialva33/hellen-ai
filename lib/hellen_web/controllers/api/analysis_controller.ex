defmodule HellenWeb.API.AnalysisController do
  @moduledoc """
  API controller for analysis management.
  All actions are scoped to the user's institution for security.
  """
  use HellenWeb, :controller

  alias Hellen.Analysis

  action_fallback HellenWeb.FallbackController

  def index(conn, %{"lesson_id" => lesson_id}) do
    user = conn.assigns.current_user
    analyses = Analysis.list_analyses_by_lesson(lesson_id, user.institution_id)
    render(conn, :index, analyses: analyses)
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    analysis = Analysis.get_analysis_with_details!(id, user.institution_id)
    render(conn, :show, analysis: analysis)
  end
end
