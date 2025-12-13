defmodule Hellen.Factory do
  @moduledoc """
  Factory definitions for test data generation using ExMachina.
  """
  use ExMachina.Ecto, repo: Hellen.Repo

  # ============================================================================
  # Accounts
  # ============================================================================

  def institution_factory do
    %Hellen.Accounts.Institution{
      name: sequence(:name, &"Institution #{&1}"),
      plan: "free",
      settings: %{}
    }
  end

  def user_factory do
    institution = insert(:institution)

    %Hellen.Accounts.User{
      name: sequence(:name, &"User #{&1}"),
      email: sequence(:email, &"user#{&1}@example.com"),
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      role: "teacher",
      credits: 10,
      plan: "free",
      institution: institution
    }
  end

  def admin_factory do
    struct!(
      user_factory(),
      %{
        role: "admin",
        email: sequence(:email, &"admin#{&1}@example.com")
      }
    )
  end

  def coordinator_factory do
    struct!(
      user_factory(),
      %{
        role: "coordinator",
        email: sequence(:email, &"coordinator#{&1}@example.com")
      }
    )
  end

  def invitation_factory do
    institution = insert(:institution)
    inviter = insert(:user, institution: institution, role: "coordinator")

    %Hellen.Accounts.Invitation{
      email: sequence(:email, &"invite#{&1}@example.com"),
      name: sequence(:name, &"Invited User #{&1}"),
      token: generate_token(),
      role: "teacher",
      expires_at: DateTime.add(DateTime.utc_now(), 7, :day) |> DateTime.truncate(:second),
      institution: institution,
      invited_by: inviter
    }
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  # ============================================================================
  # Lessons
  # ============================================================================

  def lesson_factory do
    user = insert(:user)

    %Hellen.Lessons.Lesson{
      title: sequence(:title, &"Lesson #{&1}"),
      description: "A test lesson about mathematics",
      subject: "Matematica",
      grade_level: "5o ano",
      duration_seconds: 2700,
      status: "pending",
      metadata: %{},
      user: user,
      institution: user.institution
    }
  end

  def lesson_with_audio_factory do
    struct!(
      lesson_factory(),
      %{
        audio_url: "https://storage.example.com/audio/test.mp3",
        status: "completed"
      }
    )
  end

  def transcription_factory do
    lesson = insert(:lesson)

    %Hellen.Lessons.Transcription{
      full_text:
        "Esta e uma transcricao de teste da aula de matematica. " <>
          "Hoje vamos aprender sobre fracoes. Voces sabem o que sao fracoes?",
      language: "pt-BR",
      confidence_score: 0.95,
      word_count: 18,
      segments: [
        %{
          "start" => 0.0,
          "end" => 5.0,
          "text" => "Esta e uma transcricao de teste da aula de matematica."
        },
        %{"start" => 5.0, "end" => 8.0, "text" => "Hoje vamos aprender sobre fracoes."},
        %{"start" => 8.0, "end" => 11.0, "text" => "Voces sabem o que sao fracoes?"}
      ],
      lesson: lesson
    }
  end

  # ============================================================================
  # Analysis
  # ============================================================================

  def analysis_factory do
    lesson = insert(:lesson)

    %Hellen.Analysis.Analysis{
      analysis_type: "full",
      model_used: "qwen3-8b",
      raw_response: %{"analysis" => "test"},
      result: %{
        "summary" => "Good lesson with clear explanations",
        "strengths" => ["Clear introduction", "Good pacing"],
        "improvements" => ["More student interaction"]
      },
      overall_score: 0.85,
      processing_time_ms: 1500,
      tokens_used: 500,
      lesson: lesson,
      institution: lesson.institution
    }
  end

  def bncc_match_factory do
    analysis = insert(:analysis)

    %Hellen.Analysis.BnccMatch{
      competencia_code: sequence(:code, &"EF05MA0#{rem(&1, 9) + 1}"),
      competencia_name: "Resolver e elaborar problemas de adicao",
      match_score: 0.85,
      evidence_text: "Hoje vamos aprender sobre fracoes",
      evidence_timestamp_start: 5.0,
      evidence_timestamp_end: 8.0,
      analysis: analysis
    }
  end

  def bullying_alert_factory do
    analysis = insert(:analysis)

    %Hellen.Analysis.BullyingAlert{
      severity: "medium",
      alert_type: "verbal_aggression",
      description: "Possible verbal aggression detected",
      evidence_text: "Example evidence text",
      timestamp_start: 120.0,
      timestamp_end: 125.0,
      reviewed: false,
      analysis: analysis
    }
  end

  def critical_alert_factory do
    struct!(
      bullying_alert_factory(),
      %{
        severity: "critical",
        alert_type: "threat",
        description: "Critical threat detected"
      }
    )
  end

  # ============================================================================
  # Billing
  # ============================================================================

  def credit_transaction_factory do
    user = insert(:user)

    %Hellen.Billing.CreditTransaction{
      amount: -1,
      balance_after: 9,
      reason: "lesson_analysis",
      metadata: %{"lesson_id" => Ecto.UUID.generate()},
      user: user
    }
  end

  def purchase_transaction_factory do
    user = insert(:user)

    %Hellen.Billing.CreditTransaction{
      amount: 10,
      balance_after: 20,
      reason: "purchase",
      metadata: %{"package" => "starter"},
      user: user
    }
  end

  def signup_bonus_transaction_factory do
    user = insert(:user)

    %Hellen.Billing.CreditTransaction{
      amount: 2,
      balance_after: 2,
      reason: "signup_bonus",
      metadata: %{},
      user: user
    }
  end

  # ============================================================================
  # Notifications
  # ============================================================================

  def notification_factory do
    user = insert(:user)

    %Hellen.Notifications.Notification{
      type: "analysis_complete",
      title: "Analise Concluida",
      message: "A analise da sua aula foi concluida com sucesso.",
      data: %{"lesson_id" => Ecto.UUID.generate()},
      user: user,
      institution: user.institution
    }
  end

  def alert_notification_factory do
    user = insert(:user)

    %Hellen.Notifications.Notification{
      type: "alert_high",
      title: "Alerta de Bullying",
      message: "Um alerta de bullying foi detectado em uma aula.",
      data: %{"alert_id" => Ecto.UUID.generate(), "severity" => "high"},
      user: user,
      institution: user.institution
    }
  end

  def notification_preference_factory do
    user = insert(:user)

    %Hellen.Notifications.Preference{
      email_critical_alerts: true,
      email_high_alerts: true,
      email_analysis_complete: false,
      email_daily_summary: false,
      email_weekly_summary: true,
      inapp_all_alerts: true,
      inapp_analysis_complete: true,
      user: user
    }
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  @doc """
  Creates a user with a specific number of credits.
  """
  def user_with_credits(credits) do
    build(:user, credits: credits)
  end

  @doc """
  Creates a complete lesson with transcription and analysis.
  """
  def complete_lesson_factory do
    user = insert(:user)
    lesson = insert(:lesson, user: user, institution: user.institution, status: "completed")
    insert(:transcription, lesson: lesson)
    analysis = insert(:analysis, lesson: lesson, institution: user.institution)
    insert(:bncc_match, analysis: analysis)

    lesson
  end

  @doc """
  Creates a user with zero credits.
  """
  def user_with_no_credits_factory do
    institution = insert(:institution)

    %Hellen.Accounts.User{
      name: sequence(:name, &"User #{&1}"),
      email: sequence(:email, &"user#{&1}@example.com"),
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      role: "teacher",
      credits: 0,
      plan: "free",
      institution: institution
    }
  end

  @doc """
  Creates a lesson with transcription already attached.
  """
  def lesson_with_transcription_factory do
    lesson = insert(:lesson)

    transcription =
      insert(:transcription,
        lesson: lesson,
        full_text:
          "Esta e uma transcricao de teste da aula de matematica. " <>
            "Hoje vamos aprender sobre fracoes."
      )

    %{lesson | transcription: transcription}
  end

  @doc """
  Creates an analysis with BNCC matches and bullying alerts.
  """
  def analysis_with_details_factory do
    analysis = insert(:analysis)
    insert(:bncc_match, analysis: analysis)
    insert(:bullying_alert, analysis: analysis, severity: "low")

    analysis |> Hellen.Repo.preload([:bncc_matches, :bullying_alerts])
  end

  @doc """
  Creates an institution with multiple users.
  """
  def institution_with_users(user_count \\ 2) do
    institution = insert(:institution)

    users =
      for _ <- 1..user_count do
        insert(:user, institution: institution)
      end

    %{institution | users: users}
  end

  @doc """
  Creates a transcription annotation.
  """
  def transcription_annotation_factory do
    lesson = insert(:lesson)

    %Hellen.Lessons.TranscriptionAnnotation{
      content: sequence(:content, &"Annotation comment #{&1}"),
      selection_start: 10,
      selection_end: 50,
      selection_text: "selected text from transcription",
      lesson_id: lesson.id,
      user_id: lesson.user_id
    }
  end

  @doc """
  Creates a lesson character.
  """
  def lesson_character_factory do
    analysis = insert(:analysis)

    %Hellen.Analysis.LessonCharacter{
      identifier: sequence(:identifier, &"Character #{&1}"),
      role: "student",
      speech_count: :rand.uniform(20),
      word_count: :rand.uniform(500),
      characteristics: ["participativo", "questionador"],
      speech_patterns: "Pergunta com frequência",
      key_quotes: ["Posso fazer uma pergunta?"],
      sentiment: "positive",
      engagement_level: "high",
      analysis: analysis
    }
  end
end
