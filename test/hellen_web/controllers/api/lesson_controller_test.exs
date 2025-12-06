defmodule HellenWeb.API.LessonControllerTest do
  use HellenWeb.ConnCase, async: true

  describe "GET /api/lessons" do
    setup :register_and_log_in_user

    test "returns paginated lessons for authenticated user", %{conn: conn, user: user} do
      insert(:lesson, user: user, institution: user.institution)
      insert(:lesson, user: user, institution: user.institution)

      conn = get(conn, ~p"/api/lessons")
      response = json_response(conn, 200)

      assert length(response["data"]) == 2
    end

    test "only returns user's own lessons", %{conn: conn, user: user} do
      insert(:lesson, user: user, institution: user.institution)
      # Different user
      insert(:lesson)

      conn = get(conn, ~p"/api/lessons")
      response = json_response(conn, 200)

      assert length(response["data"]) == 1
    end

    test "returns 401 without auth", %{conn: _conn} do
      conn = build_conn()
      conn = get(conn, ~p"/api/lessons")
      assert json_response(conn, 401)
    end
  end

  describe "POST /api/lessons" do
    setup :register_and_log_in_user

    test "creates lesson with valid data", %{conn: conn} do
      params = %{
        "lesson" => %{
          "title" => "Test Lesson",
          "subject" => "Matematica",
          "grade_level" => "5o ano"
        }
      }

      conn = post(conn, ~p"/api/lessons", params)
      response = json_response(conn, 201)

      assert response["data"]["title"] == "Test Lesson"
      assert response["data"]["subject"] == "Matematica"
    end

    test "returns error with missing required fields", %{conn: conn} do
      params = %{
        "lesson" => %{
          "subject" => "Matematica"
        }
      }

      conn = post(conn, ~p"/api/lessons", params)
      assert json_response(conn, 422)
    end

    test "returns error with insufficient credits", %{conn: conn, user: user} do
      # Update user to have 0 credits
      Hellen.Repo.update!(Ecto.Changeset.change(user, credits: 0))

      params = %{
        "lesson" => %{
          "title" => "Test Lesson",
          "subject" => "Matematica"
        }
      }

      conn = post(conn, ~p"/api/lessons", params)
      # 402 Payment Required for insufficient credits
      assert json_response(conn, 402)
    end

    test "returns 401 without auth", %{conn: _conn} do
      conn = build_conn()
      conn = post(conn, ~p"/api/lessons", %{"lesson" => %{"title" => "Test"}})
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/lessons/:id" do
    setup :register_and_log_in_user

    test "returns lesson with associations", %{conn: conn, user: user} do
      lesson = insert(:lesson, user: user, institution: user.institution)

      conn = get(conn, ~p"/api/lessons/#{lesson.id}")
      response = json_response(conn, 200)

      assert response["data"]["id"] == lesson.id
      assert response["data"]["title"] == lesson.title
    end

    test "returns 404 for non-existent lesson", %{conn: conn} do
      conn = get(conn, ~p"/api/lessons/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end

    test "returns 404 for other user's lesson", %{conn: conn} do
      other_lesson = insert(:lesson)

      conn = get(conn, ~p"/api/lessons/#{other_lesson.id}")
      assert json_response(conn, 404)
    end
  end

  describe "PATCH /api/lessons/:id" do
    setup :register_and_log_in_user

    test "updates lesson with valid data", %{conn: conn, user: user} do
      lesson = insert(:lesson, user: user, institution: user.institution)

      params = %{
        "lesson" => %{
          "title" => "Updated Title"
        }
      }

      conn = patch(conn, ~p"/api/lessons/#{lesson.id}", params)
      response = json_response(conn, 200)

      assert response["data"]["title"] == "Updated Title"
    end

    test "returns 404 for other user's lesson", %{conn: conn} do
      other_lesson = insert(:lesson)

      params = %{
        "lesson" => %{
          "title" => "Updated Title"
        }
      }

      conn = patch(conn, ~p"/api/lessons/#{other_lesson.id}", params)
      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/lessons/:id" do
    setup :register_and_log_in_user

    test "deletes lesson", %{conn: conn, user: user} do
      lesson = insert(:lesson, user: user, institution: user.institution)

      conn = delete(conn, ~p"/api/lessons/#{lesson.id}")
      assert response(conn, 204)

      assert_raise Ecto.NoResultsError, fn ->
        Hellen.Lessons.get_lesson!(lesson.id)
      end
    end

    test "returns 404 for other user's lesson", %{conn: conn} do
      other_lesson = insert(:lesson)

      conn = delete(conn, ~p"/api/lessons/#{other_lesson.id}")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/lessons/:id/analyze" do
    setup :register_and_log_in_user

    test "returns 404 for other user's lesson", %{conn: conn} do
      other_lesson = insert(:lesson)

      conn = post(conn, ~p"/api/lessons/#{other_lesson.id}/analyze")
      assert json_response(conn, 404)
    end

    test "returns 401 without auth", %{conn: _conn} do
      lesson = insert(:lesson)
      conn = build_conn()
      conn = post(conn, ~p"/api/lessons/#{lesson.id}/analyze")
      assert json_response(conn, 401)
    end
  end
end
