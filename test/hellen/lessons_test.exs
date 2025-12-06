defmodule Hellen.LessonsTest do
  use Hellen.DataCase, async: true

  alias Hellen.Lessons

  describe "lessons" do
    test "get_lesson!/1 returns lesson by id" do
      lesson = insert(:lesson)
      result = Lessons.get_lesson!(lesson.id)
      assert result.id == lesson.id
    end

    test "get_lesson!/1 raises for non-existent lesson" do
      assert_raise Ecto.NoResultsError, fn ->
        Lessons.get_lesson!(Ecto.UUID.generate())
      end
    end

    test "get_lesson!/2 returns lesson scoped to institution" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution)

      result = Lessons.get_lesson!(lesson.id, institution.id)
      assert result.id == lesson.id
    end

    test "get_lesson!/2 raises when institution doesn't match" do
      institution1 = insert(:institution)
      institution2 = insert(:institution)
      user = insert(:user, institution: institution1)
      lesson = insert(:lesson, user: user, institution: institution1)

      assert_raise Ecto.NoResultsError, fn ->
        Lessons.get_lesson!(lesson.id, institution2.id)
      end
    end

    test "get_lesson_with_transcription!/1 returns lesson with transcription" do
      lesson = insert(:lesson)
      insert(:transcription, lesson: lesson)

      result = Lessons.get_lesson_with_transcription!(lesson.id)
      assert result.id == lesson.id
      assert result.transcription != nil
    end

    test "list_lessons_by_user/2 returns paginated lessons" do
      user = insert(:user)
      lesson1 = insert(:lesson, user: user)
      lesson2 = insert(:lesson, user: user)
      _other_lesson = insert(:lesson)

      lessons = Lessons.list_lessons_by_user(user.id)
      lesson_ids = Enum.map(lessons, & &1.id)

      assert length(lessons) == 2
      assert lesson1.id in lesson_ids
      assert lesson2.id in lesson_ids
    end

    test "list_lessons_by_user/2 respects limit and offset" do
      user = insert(:user)
      insert(:lesson, user: user)
      insert(:lesson, user: user)
      insert(:lesson, user: user)

      lessons = Lessons.list_lessons_by_user(user.id, limit: 2, offset: 1)
      assert length(lessons) == 2
    end

    test "list_lessons_by_institution/2 returns lessons for institution" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson1 = insert(:lesson, user: user, institution: institution)
      lesson2 = insert(:lesson, user: user, institution: institution)

      lessons = Lessons.list_lessons_by_institution(institution.id)
      lesson_ids = Enum.map(lessons, & &1.id)

      assert length(lessons) == 2
      assert lesson1.id in lesson_ids
      assert lesson2.id in lesson_ids
    end

    test "list_lessons_by_institution/2 filters by status" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      insert(:lesson, user: user, institution: institution, status: "pending")
      insert(:lesson, user: user, institution: institution, status: "completed")

      pending = Lessons.list_lessons_by_institution(institution.id, status: "pending")
      assert length(pending) == 1
      assert hd(pending).status == "pending"
    end

    test "list_lessons_by_institution/2 filters by subject" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      insert(:lesson, user: user, institution: institution, subject: "Matematica")
      insert(:lesson, user: user, institution: institution, subject: "Portugues")

      math = Lessons.list_lessons_by_institution(institution.id, subject: "Matematica")
      assert length(math) == 1
      assert hd(math).subject == "Matematica"
    end

    test "create_lesson/2 creates lesson with valid data" do
      user = insert(:user, credits: 10)

      attrs = %{
        "title" => "Test Lesson",
        "subject" => "Matematica",
        "grade_level" => "5o ano"
      }

      assert {:ok, lesson} = Lessons.create_lesson(user, attrs)
      assert lesson.title == "Test Lesson"
      assert lesson.user_id == user.id
      assert lesson.institution_id == user.institution_id
    end

    test "create_lesson/2 returns error with insufficient credits" do
      user = insert(:user, credits: 0)
      attrs = %{"title" => "Test"}

      assert {:error, :insufficient_credits} = Lessons.create_lesson(user, attrs)
    end

    test "create_lesson/2 returns error without title" do
      user = insert(:user, credits: 10)
      attrs = %{"subject" => "Matematica"}

      assert {:error, changeset} = Lessons.create_lesson(user, attrs)
      assert "can't be blank" in errors_on(changeset).title
    end

    test "update_lesson/2 updates lesson with valid data" do
      lesson = insert(:lesson)
      assert {:ok, updated} = Lessons.update_lesson(lesson, %{title: "Updated Title"})
      assert updated.title == "Updated Title"
    end

    test "update_lesson_status/2 updates status" do
      lesson = insert(:lesson, status: "pending")
      assert {:ok, updated} = Lessons.update_lesson_status(lesson, "transcribing")
      assert updated.status == "transcribing"
    end

    test "update_lesson_status/2 rejects invalid status" do
      lesson = insert(:lesson)
      assert {:error, changeset} = Lessons.update_lesson_status(lesson, "invalid")
      assert "is invalid" in errors_on(changeset).status
    end

    test "delete_lesson/1 deletes lesson" do
      lesson = insert(:lesson)
      assert {:ok, _deleted} = Lessons.delete_lesson(lesson)
      assert_raise Ecto.NoResultsError, fn -> Lessons.get_lesson!(lesson.id) end
    end
  end

  describe "transcriptions" do
    test "get_transcription_by_lesson/1 returns transcription" do
      lesson = insert(:lesson)
      transcription = insert(:transcription, lesson: lesson)

      result = Lessons.get_transcription_by_lesson(lesson.id)
      assert result.id == transcription.id
    end

    test "get_transcription_by_lesson/1 returns nil if not found" do
      lesson = insert(:lesson)
      assert Lessons.get_transcription_by_lesson(lesson.id) == nil
    end

    test "create_transcription/2 creates transcription" do
      lesson = insert(:lesson)

      attrs = %{
        full_text: "Test transcription content",
        language: "pt-BR",
        confidence_score: 0.95
      }

      assert {:ok, transcription} = Lessons.create_transcription(lesson.id, attrs)
      assert transcription.full_text == "Test transcription content"
      assert transcription.lesson_id == lesson.id
      assert transcription.word_count == 3
    end

    test "create_transcription/2 computes word count" do
      lesson = insert(:lesson)

      attrs = %{
        full_text: "One two three four five six seven",
        language: "pt-BR"
      }

      assert {:ok, transcription} = Lessons.create_transcription(lesson.id, attrs)
      assert transcription.word_count == 7
    end
  end

  describe "statistics" do
    test "get_institution_stats/1 returns lesson statistics" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)

      insert(:lesson,
        user: user,
        institution: institution,
        status: "pending",
        subject: "Ciencias"
      )

      insert(:lesson,
        user: user,
        institution: institution,
        status: "completed",
        subject: "Matematica"
      )

      insert(:lesson,
        user: user,
        institution: institution,
        status: "completed",
        subject: "Portugues"
      )

      stats = Lessons.get_institution_stats(institution.id)

      assert stats.total == 3
      assert stats.pending == 1
      assert stats.completed == 2
      assert stats.by_status["pending"] == 1
      assert stats.by_status["completed"] == 2
      assert stats.by_subject["Matematica"] == 1
      assert stats.by_subject["Portugues"] == 1
    end

    test "list_subjects/1 returns distinct subjects" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      insert(:lesson, user: user, institution: institution, subject: "Matematica")
      insert(:lesson, user: user, institution: institution, subject: "Matematica")
      insert(:lesson, user: user, institution: institution, subject: "Portugues")

      subjects = Lessons.list_subjects(institution.id)

      assert length(subjects) == 2
      assert "Matematica" in subjects
      assert "Portugues" in subjects
    end
  end
end
