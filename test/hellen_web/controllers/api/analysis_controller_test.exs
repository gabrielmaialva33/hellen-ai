defmodule HellenWeb.API.AnalysisControllerTest do
  use HellenWeb.ConnCase, async: true

  describe "GET /api/lessons/:lesson_id/analyses" do
    setup :register_and_log_in_user

    test "returns analyses for a lesson", %{conn: conn, user: user} do
      lesson = insert(:lesson, user: user, institution: user.institution)
      insert(:analysis, lesson: lesson, institution: user.institution)
      insert(:analysis, lesson: lesson, institution: user.institution)

      conn = get(conn, ~p"/api/lessons/#{lesson.id}/analyses")
      response = json_response(conn, 200)

      assert length(response["data"]) == 2
    end

    test "returns empty list for lesson without analyses", %{conn: conn, user: user} do
      lesson = insert(:lesson, user: user, institution: user.institution)

      conn = get(conn, ~p"/api/lessons/#{lesson.id}/analyses")
      response = json_response(conn, 200)

      assert response["data"] == []
    end

    test "returns empty list for other user's lesson", %{conn: conn} do
      other_lesson = insert(:lesson)
      insert(:analysis, lesson: other_lesson, institution: other_lesson.institution)

      conn = get(conn, ~p"/api/lessons/#{other_lesson.id}/analyses")
      response = json_response(conn, 200)

      # Returns empty because institution doesn't match
      assert response["data"] == []
    end

    test "returns 401 without auth", %{conn: _conn} do
      lesson = insert(:lesson)
      conn = build_conn()
      conn = get(conn, ~p"/api/lessons/#{lesson.id}/analyses")
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/analyses/:id" do
    setup :register_and_log_in_user

    test "returns analysis with BNCC matches and alerts", %{conn: conn, user: user} do
      lesson = insert(:lesson, user: user, institution: user.institution)
      analysis = insert(:analysis, lesson: lesson, institution: user.institution)
      insert(:bncc_match, analysis: analysis)
      insert(:bullying_alert, analysis: analysis)

      conn = get(conn, ~p"/api/analyses/#{analysis.id}")
      response = json_response(conn, 200)

      assert response["data"]["id"] == analysis.id
      assert length(response["data"]["bncc_matches"]) == 1
      assert length(response["data"]["bullying_alerts"]) == 1
    end

    test "returns 404 for non-existent analysis", %{conn: conn} do
      conn = get(conn, ~p"/api/analyses/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns 404 for other user's analysis", %{conn: conn} do
      other_analysis = insert(:analysis)

      conn = get(conn, ~p"/api/analyses/#{other_analysis.id}")
      assert json_response(conn, 404)
    end

    test "returns 401 without auth", %{conn: _conn} do
      analysis = insert(:analysis)
      conn = build_conn()
      conn = get(conn, ~p"/api/analyses/#{analysis.id}")
      assert json_response(conn, 401)
    end
  end
end
