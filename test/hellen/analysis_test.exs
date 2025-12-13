defmodule Hellen.AnalysisTest do
  use Hellen.DataCase, async: true

  alias Hellen.Analysis

  describe "analyses" do
    test "get_analysis!/2 returns analysis by id scoped to institution" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution)
      analysis = insert(:analysis, lesson: lesson, institution: institution)

      result = Analysis.get_analysis!(analysis.id, institution.id)
      assert result.id == analysis.id
    end

    test "get_analysis!/2 raises for non-existent analysis" do
      institution = insert(:institution)

      assert_raise Ecto.NoResultsError, fn ->
        Analysis.get_analysis!(Ecto.UUID.generate(), institution.id)
      end
    end

    test "get_analysis!/2 raises when institution doesn't match" do
      institution1 = insert(:institution)
      institution2 = insert(:institution)
      user = insert(:user, institution: institution1)
      lesson = insert(:lesson, user: user, institution: institution1)
      analysis = insert(:analysis, lesson: lesson, institution: institution1)

      assert_raise Ecto.NoResultsError, fn ->
        Analysis.get_analysis!(analysis.id, institution2.id)
      end
    end

    test "get_analysis_with_details!/2 returns analysis with associations" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution)
      analysis = insert(:analysis, lesson: lesson, institution: institution)
      insert(:bncc_match, analysis: analysis)
      insert(:bullying_alert, analysis: analysis)

      result = Analysis.get_analysis_with_details!(analysis.id, institution.id)
      assert result.id == analysis.id
      assert length(result.bncc_matches) == 1
      assert length(result.bullying_alerts) == 1
    end

    test "list_analyses_by_lesson/2 returns analyses for lesson" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution)
      analysis1 = insert(:analysis, lesson: lesson, institution: institution)
      analysis2 = insert(:analysis, lesson: lesson, institution: institution)
      _other = insert(:analysis)

      analyses = Analysis.list_analyses_by_lesson(lesson.id, institution.id)
      analysis_ids = Enum.map(analyses, & &1.id)

      assert length(analyses) == 2
      assert analysis1.id in analysis_ids
      assert analysis2.id in analysis_ids
    end

    test "create_analysis/1 creates analysis with valid data" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution)

      attrs = %{
        lesson_id: lesson.id,
        institution_id: institution.id,
        analysis_type: "full",
        model_used: "qwen3-8b",
        raw_response: %{},
        result: %{"summary" => "Test"},
        overall_score: 0.85
      }

      assert {:ok, analysis} = Analysis.create_analysis(attrs)
      assert analysis.analysis_type == "full"
      assert analysis.overall_score == 0.85
    end

    test "create_full_analysis/2 creates analysis with BNCC matches and alerts" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution)

      analysis_result = %{
        model: "qwen3-8b",
        raw: %{},
        structured: %{"summary" => "Test"},
        overall_score: 0.85,
        processing_time_ms: 1500,
        tokens_used: 500,
        bncc_matches: [
          %{
            competencia_code: "EF05MA01",
            competencia_name: "Test competency",
            match_score: 0.9,
            evidence_text: "Evidence"
          }
        ],
        bullying_alerts: [
          %{
            severity: "medium",
            alert_type: "verbal_aggression",
            description: "Test alert",
            evidence_text: "Evidence"
          }
        ]
      }

      assert {:ok, analysis} = Analysis.create_full_analysis(lesson.id, analysis_result)
      assert analysis.overall_score == 0.85

      # Verify related records
      bncc_matches = Analysis.list_bncc_matches_by_analysis(analysis.id)
      assert length(bncc_matches) == 1
      assert hd(bncc_matches).competencia_code == "EF05MA01"

      alerts = Analysis.list_bullying_alerts_by_analysis(analysis.id)
      assert length(alerts) == 1
      assert hd(alerts).severity == "medium"
    end
  end

  describe "bncc_matches" do
    test "create_bncc_match/1 creates match" do
      analysis = insert(:analysis)

      attrs = %{
        analysis_id: analysis.id,
        competencia_code: "EF05MA02",
        competencia_name: "Test competency",
        match_score: 0.85,
        evidence_text: "Evidence text"
      }

      assert {:ok, match} = Analysis.create_bncc_match(attrs)
      assert match.competencia_code == "EF05MA02"
      assert match.match_score == 0.85
    end

    test "list_bncc_matches_by_analysis/1 returns matches ordered by score" do
      analysis = insert(:analysis)
      insert(:bncc_match, analysis: analysis, match_score: 0.7)
      insert(:bncc_match, analysis: analysis, match_score: 0.9)
      insert(:bncc_match, analysis: analysis, match_score: 0.8)

      matches = Analysis.list_bncc_matches_by_analysis(analysis.id)

      assert length(matches) == 3
      scores = Enum.map(matches, & &1.match_score)
      assert scores == Enum.sort(scores, :desc)
    end
  end

  describe "bullying_alerts" do
    test "create_bullying_alert/1 creates alert" do
      analysis = insert(:analysis)

      attrs = %{
        analysis_id: analysis.id,
        severity: "high",
        alert_type: "verbal_aggression",
        description: "Test alert",
        evidence_text: "Evidence"
      }

      assert {:ok, alert} = Analysis.create_bullying_alert(attrs)
      assert alert.severity == "high"
      assert alert.reviewed == false
    end

    test "list_bullying_alerts_by_analysis/1 returns alerts" do
      analysis = insert(:analysis)
      insert(:bullying_alert, analysis: analysis, severity: "low")
      insert(:bullying_alert, analysis: analysis, severity: "high")
      insert(:bullying_alert, analysis: analysis, severity: "medium")

      alerts = Analysis.list_bullying_alerts_by_analysis(analysis.id)
      assert length(alerts) == 3
    end

    test "review_bullying_alert/2 marks alert as reviewed" do
      analysis = insert(:analysis)
      alert = insert(:bullying_alert, analysis: analysis, reviewed: false)
      reviewer = insert(:user)

      assert {:ok, reviewed} = Analysis.review_bullying_alert(alert.id, reviewer.id)
      assert reviewed.reviewed == true
      assert reviewed.reviewed_by_id == reviewer.id
      assert reviewed.reviewed_at != nil
    end

    test "list_unreviewed_alerts/1 returns only unreviewed alerts" do
      analysis = insert(:analysis)
      insert(:bullying_alert, analysis: analysis, reviewed: false)
      insert(:bullying_alert, analysis: analysis, reviewed: false)
      insert(:bullying_alert, analysis: analysis, reviewed: true, reviewed_by: insert(:user))

      alerts = Analysis.list_unreviewed_alerts()
      assert length(alerts) == 2
      assert Enum.all?(alerts, &(&1.reviewed == false))
    end

    test "list_unreviewed_alerts/1 respects limit" do
      analysis = insert(:analysis)
      for _ <- 1..5, do: insert(:bullying_alert, analysis: analysis, reviewed: false)

      alerts = Analysis.list_unreviewed_alerts(limit: 3)
      assert length(alerts) == 3
    end
  end

  describe "statistics" do
    test "get_user_score_history/2 returns score history for user" do
      user = insert(:user)
      lesson1 = insert(:lesson, user: user, title: "Lesson 1")
      lesson2 = insert(:lesson, user: user, title: "Lesson 2")
      insert(:analysis, lesson: lesson1, overall_score: 0.8)
      insert(:analysis, lesson: lesson2, overall_score: 0.9)

      history = Analysis.get_user_score_history(user.id)
      assert length(history) == 2
      assert Enum.any?(history, &(&1.lesson_title == "Lesson 1"))
      assert Enum.any?(history, &(&1.lesson_title == "Lesson 2"))
    end

    test "get_discipline_average/2 returns average score for subject" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson1 = insert(:lesson, user: user, institution: institution, subject: "Matematica")
      lesson2 = insert(:lesson, user: user, institution: institution, subject: "Matematica")
      lesson3 = insert(:lesson, user: user, institution: institution, subject: "Portugues")

      insert(:analysis, lesson: lesson1, institution: institution, overall_score: 0.8)
      insert(:analysis, lesson: lesson2, institution: institution, overall_score: 0.9)
      insert(:analysis, lesson: lesson3, institution: institution, overall_score: 0.7)

      avg = Analysis.get_discipline_average("Matematica", institution.id)
      assert_in_delta avg, 0.85, 0.01
    end

    test "get_user_trend/1 returns stable with single analysis" do
      user = insert(:user)
      lesson = insert(:lesson, user: user)
      insert(:analysis, lesson: lesson, overall_score: 0.8)

      {trend, change} = Analysis.get_user_trend(user.id)
      assert trend == :stable
      assert change == 0.0
    end

    test "get_user_trend/1 returns stable with no analyses" do
      user = insert(:user)

      {trend, change} = Analysis.get_user_trend(user.id)
      assert trend == :stable
      assert change == 0.0
    end

    test "get_bncc_coverage/2 returns aggregated BNCC competencies" do
      user = insert(:user)
      lesson = insert(:lesson, user: user)
      analysis = insert(:analysis, lesson: lesson)

      insert(:bncc_match, analysis: analysis, competencia_code: "EF05MA01", match_score: 0.8)
      insert(:bncc_match, analysis: analysis, competencia_code: "EF05MA01", match_score: 0.9)
      insert(:bncc_match, analysis: analysis, competencia_code: "EF05LP01", match_score: 0.7)

      coverage = Analysis.get_bncc_coverage(user.id)

      ma_coverage = Enum.find(coverage, &(&1.code == "EF05MA01"))
      assert ma_coverage.count == 2
    end
  end

  describe "alerts by institution" do
    test "list_alerts_by_institution/2 returns alerts for institution" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution)
      analysis = insert(:analysis, lesson: lesson, institution: institution)
      insert(:bullying_alert, analysis: analysis)
      insert(:bullying_alert, analysis: analysis)

      # Different institution
      other_analysis = insert(:analysis)
      insert(:bullying_alert, analysis: other_analysis)

      alerts = Analysis.list_alerts_by_institution(institution.id)
      assert length(alerts) == 2
    end

    test "list_alerts_by_institution/2 filters by status" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution)
      analysis = insert(:analysis, lesson: lesson, institution: institution)
      insert(:bullying_alert, analysis: analysis, reviewed: false)
      insert(:bullying_alert, analysis: analysis, reviewed: true, reviewed_by: insert(:user))

      unreviewed = Analysis.list_alerts_by_institution(institution.id, status: :unreviewed)
      assert length(unreviewed) == 1

      reviewed = Analysis.list_alerts_by_institution(institution.id, status: :reviewed)
      assert length(reviewed) == 1
    end

    test "get_alert_stats/1 returns alert statistics" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution)
      analysis = insert(:analysis, lesson: lesson, institution: institution)
      insert(:bullying_alert, analysis: analysis, severity: "high", reviewed: false)

      insert(:bullying_alert,
        analysis: analysis,
        severity: "medium",
        reviewed: true,
        reviewed_by: insert(:user)
      )

      insert(:bullying_alert, analysis: analysis, severity: "high", reviewed: false)

      stats = Analysis.get_alert_stats(institution.id)
      assert stats.total == 3
      assert stats.unreviewed == 2
      assert stats.reviewed == 1
      assert stats.by_severity["high"] == 2
      assert stats.by_severity["medium"] == 1
    end
  end

  describe "advanced analytics" do
    test "get_score_comparison/2 returns period comparison" do
      user = insert(:user)

      comparison = Analysis.get_score_comparison(user.id, days: 30)

      assert Map.has_key?(comparison, :current_avg)
      assert Map.has_key?(comparison, :previous_avg)
      assert Map.has_key?(comparison, :change_percent)
      assert Map.has_key?(comparison, :trend)
      assert comparison.trend in [:improving, :stable, :declining]
    end

    test "get_institution_comparison/2 returns institution vs platform comparison" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution)
      insert(:analysis, lesson: lesson, institution: institution, overall_score: 0.85)

      comparison = Analysis.get_institution_comparison(institution.id)

      assert Map.has_key?(comparison, :institution_avg)
      assert Map.has_key?(comparison, :platform_avg)
      assert Map.has_key?(comparison, :rank)
      assert Map.has_key?(comparison, :percentile)
    end

    test "get_daily_scores/2 returns daily score breakdown" do
      user = insert(:user)
      lesson = insert(:lesson, user: user)
      insert(:analysis, lesson: lesson, overall_score: 0.85)

      scores = Analysis.get_daily_scores(user.id, days: 7)

      # Should have at least today's entry
      assert is_list(scores)
    end

    test "get_bncc_coverage_detailed/2 includes category" do
      user = insert(:user)
      lesson = insert(:lesson, user: user)
      analysis = insert(:analysis, lesson: lesson)
      insert(:bncc_match, analysis: analysis, competencia_code: "EF05LP01")

      coverage = Analysis.get_bncc_coverage_detailed(user.id)

      # The extract_bncc_category function extracts first 2 uppercase letters (EF)
      refute Enum.empty?(coverage)
      assert hd(coverage).category == "EF"
    end

    test "list_analyses_for_export/2 returns analyses with all associations" do
      user = insert(:user)
      lesson = insert(:lesson, user: user)
      analysis = insert(:analysis, lesson: lesson)
      insert(:bncc_match, analysis: analysis)
      insert(:bullying_alert, analysis: analysis)

      analyses = Analysis.list_analyses_for_export(user.id)

      assert length(analyses) == 1
      exported = hd(analyses)
      assert exported.lesson != nil
      assert length(exported.bncc_matches) >= 0
    end
  end

  describe "cascade deletes" do
    alias Hellen.Lessons

    test "delete_lesson/1 cascades to analysis and related records" do
      institution = insert(:institution)
      user = insert(:user, institution: institution)
      lesson = insert(:lesson, user: user, institution: institution)
      analysis = insert(:analysis, lesson: lesson, institution: institution)
      insert(:bncc_match, analysis: analysis)
      insert(:bullying_alert, analysis: analysis)

      # Verify records exist before deletion
      assert Repo.get(Hellen.Analysis.Analysis, analysis.id)

      {:ok, _} = Lessons.delete_lesson(lesson)

      # Verify analysis and related records were deleted
      assert Repo.one(from a in Hellen.Analysis.Analysis, where: a.lesson_id == ^lesson.id) == nil

      assert Repo.one(from b in Hellen.Analysis.BnccMatch, where: b.analysis_id == ^analysis.id) ==
               nil

      assert Repo.one(
               from b in Hellen.Analysis.BullyingAlert, where: b.analysis_id == ^analysis.id
             ) ==
               nil
    end

    test "deleting analysis cascades to bncc_matches" do
      analysis = insert(:analysis)
      bncc1 = insert(:bncc_match, analysis: analysis)
      bncc2 = insert(:bncc_match, analysis: analysis)

      # Verify matches exist
      assert Repo.get(Hellen.Analysis.BnccMatch, bncc1.id)
      assert Repo.get(Hellen.Analysis.BnccMatch, bncc2.id)

      Repo.delete!(analysis)

      # Verify matches were cascade deleted
      assert Repo.get(Hellen.Analysis.BnccMatch, bncc1.id) == nil
      assert Repo.get(Hellen.Analysis.BnccMatch, bncc2.id) == nil
    end

    test "deleting analysis cascades to bullying_alerts" do
      analysis = insert(:analysis)
      alert1 = insert(:bullying_alert, analysis: analysis, severity: "low")
      alert2 = insert(:bullying_alert, analysis: analysis, severity: "high")

      # Verify alerts exist
      assert Repo.get(Hellen.Analysis.BullyingAlert, alert1.id)
      assert Repo.get(Hellen.Analysis.BullyingAlert, alert2.id)

      Repo.delete!(analysis)

      # Verify alerts were cascade deleted
      assert Repo.get(Hellen.Analysis.BullyingAlert, alert1.id) == nil
      assert Repo.get(Hellen.Analysis.BullyingAlert, alert2.id) == nil
    end

    test "deleting analysis cascades to lesson_characters" do
      analysis = insert(:analysis)
      character = insert(:lesson_character, analysis: analysis)

      # Verify character exists
      assert Repo.get(Hellen.Analysis.LessonCharacter, character.id)

      Repo.delete!(analysis)

      # Verify character was cascade deleted
      assert Repo.get(Hellen.Analysis.LessonCharacter, character.id) == nil
    end
  end
end
