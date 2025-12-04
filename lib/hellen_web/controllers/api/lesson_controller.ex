defmodule HellenWeb.API.LessonController do
  @moduledoc """
  API controller for lesson management.
  All actions are scoped to the user's institution for security.
  """
  use HellenWeb, :controller

  alias Hellen.Lessons
  alias Hellen.Lessons.Lesson

  action_fallback HellenWeb.FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user
    lessons = Lessons.list_lessons_by_user(user.id)
    render(conn, :index, lessons: lessons)
  end

  def create(conn, %{"lesson" => lesson_params}) do
    user = conn.assigns.current_user

    with {:ok, %Lesson{} = lesson} <- Lessons.create_lesson(user, lesson_params) do
      conn
      |> put_status(:created)
      |> render(:show, lesson: lesson)
    end
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    lesson = Lessons.get_lesson_with_transcription!(id, user.institution_id)
    render(conn, :show, lesson: lesson)
  end

  def update(conn, %{"id" => id, "lesson" => lesson_params}) do
    user = conn.assigns.current_user
    lesson = Lessons.get_lesson!(id, user.institution_id)

    with {:ok, %Lesson{} = lesson} <- Lessons.update_lesson(lesson, lesson_params) do
      render(conn, :show, lesson: lesson)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    lesson = Lessons.get_lesson!(id, user.institution_id)

    with {:ok, %Lesson{}} <- Lessons.delete_lesson(lesson) do
      send_resp(conn, :no_content, "")
    end
  end

  def analyze(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    lesson = Lessons.get_lesson!(id, user.institution_id)

    with {:ok, lesson} <- Lessons.start_processing(lesson, user) do
      conn
      |> put_status(:accepted)
      |> render(:show, lesson: lesson)
    end
  end
end
