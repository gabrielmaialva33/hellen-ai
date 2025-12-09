defmodule Hellen.Gamification do
  @moduledoc """
  Gamification context for achievements, badges, and XP system.
  Motivates teachers through achievements and progress tracking.
  """

  import Ecto.Query

  alias Hellen.Accounts.User
  alias Hellen.Gamification.UserAchievement
  alias Hellen.Lessons
  alias Hellen.Repo

  # XP rewards for actions
  @xp_first_lesson 50
  @xp_per_level 100

  # Achievement definitions
  @achievements %{
    # Lesson milestones
    "first_lesson" => %{
      name: "Primeira Aula",
      description: "Enviou sua primeira aula para analise",
      icon: "hero-academic-cap",
      color: "teal",
      xp: @xp_first_lesson,
      category: :lessons
    },
    "lesson_explorer" => %{
      name: "Explorador",
      description: "Enviou 5 aulas para analise",
      icon: "hero-map",
      color: "emerald",
      xp: 100,
      category: :lessons
    },
    "lesson_master" => %{
      name: "Mestre das Aulas",
      description: "Enviou 25 aulas para analise",
      icon: "hero-trophy",
      color: "amber",
      xp: 250,
      category: :lessons
    },
    "lesson_legend" => %{
      name: "Lenda Pedagogica",
      description: "Enviou 100 aulas para analise",
      icon: "hero-star",
      color: "violet",
      xp: 500,
      category: :lessons
    },

    # Analysis achievements
    "first_analysis" => %{
      name: "Primeiro Insight",
      description: "Recebeu sua primeira analise completa",
      icon: "hero-light-bulb",
      color: "cyan",
      xp: 30,
      category: :analysis
    },
    "score_champion" => %{
      name: "Nota Alta",
      description: "Obteve score acima de 90% em uma analise",
      icon: "hero-chart-bar",
      color: "emerald",
      xp: 50,
      category: :analysis
    },
    "consistent_quality" => %{
      name: "Qualidade Consistente",
      description: "Manteve score acima de 80% em 5 aulas consecutivas",
      icon: "hero-check-badge",
      color: "teal",
      xp: 100,
      category: :analysis
    },

    # BNCC achievements
    "bncc_aligned" => %{
      name: "Alinhado a BNCC",
      description: "Teve competencias BNCC identificadas em 10 aulas",
      icon: "hero-document-check",
      color: "violet",
      xp: 75,
      category: :bncc
    },
    "bncc_expert" => %{
      name: "Expert BNCC",
      description: "Cobriu 5 diferentes competencias da BNCC",
      icon: "hero-puzzle-piece",
      color: "purple",
      xp: 150,
      category: :bncc
    },

    # Engagement achievements
    "early_adopter" => %{
      name: "Early Adopter",
      description: "Um dos primeiros a usar o Hellen AI",
      icon: "hero-rocket-launch",
      color: "orange",
      xp: 100,
      category: :special
    },
    "weekly_streak" => %{
      name: "Semana Produtiva",
      description: "Enviou aulas por 7 dias consecutivos",
      icon: "hero-fire",
      color: "red",
      xp: 75,
      category: :engagement
    },
    "complete_profile" => %{
      name: "Perfil Completo",
      description: "Completou o onboarding e configurou seu perfil",
      icon: "hero-user-circle",
      color: "blue",
      xp: 25,
      category: :profile
    }
  }

  @doc """
  Returns all available achievement definitions.
  """
  def list_achievement_definitions do
    @achievements
  end

  @doc """
  Returns achievement definition by key.
  """
  def get_achievement_definition(key) do
    Map.get(@achievements, key)
  end

  @doc """
  Lists all achievements for a user (unlocked only).
  """
  def list_user_achievements(user_id) do
    UserAchievement
    |> where([ua], ua.user_id == ^user_id)
    |> order_by([ua], desc: ua.unlocked_at)
    |> Repo.all()
    |> Enum.map(fn ua ->
      Map.put(ua, :definition, get_achievement_definition(ua.achievement_key))
    end)
  end

  @doc """
  Returns user's achievement progress (unlocked + locked with progress).
  """
  def get_user_achievement_progress(user_id) do
    unlocked_keys =
      UserAchievement
      |> where([ua], ua.user_id == ^user_id)
      |> select([ua], ua.achievement_key)
      |> Repo.all()
      |> MapSet.new()

    lesson_count = Lessons.count_lessons_by_user(user_id)
    # completed_count = Lessons.count_completed_lessons_by_user(user_id)

    @achievements
    |> Enum.map(fn {key, definition} ->
      unlocked = MapSet.member?(unlocked_keys, key)

      progress = calculate_achievement_progress(key, unlocked, lesson_count)

      %{
        key: key,
        definition: definition,
        unlocked: unlocked,
        progress: progress
      }
    end)
    |> Enum.sort_by(fn a -> {!a.unlocked, -a.progress, a.definition.name} end)
  end

  defp calculate_achievement_progress(_key, true, _lesson_count), do: 100
  defp calculate_achievement_progress("first_lesson", false, count), do: if(count >= 1, do: 100, else: 0)
  defp calculate_achievement_progress("lesson_explorer", false, count), do: min(count / 5 * 100, 100) |> round()
  defp calculate_achievement_progress("lesson_master", false, count), do: min(count / 25 * 100, 100) |> round()
  defp calculate_achievement_progress("lesson_legend", false, count), do: min(count / 100 * 100, 100) |> round()
  defp calculate_achievement_progress(_key, false, _count), do: 0

  @doc """
  Unlocks an achievement for a user if not already unlocked.
  Returns {:ok, achievement} or {:already_unlocked, nil}.
  """
  def unlock_achievement(user_id, achievement_key) do
    if get_achievement_definition(achievement_key) == nil do
      {:error, :invalid_achievement}
    else
      do_unlock_achievement(user_id, achievement_key)
    end
  end

  defp do_unlock_achievement(user_id, achievement_key) do
    case Repo.get_by(UserAchievement, user_id: user_id, achievement_key: achievement_key) do
      nil ->
        %UserAchievement{}
        |> UserAchievement.changeset(%{
          user_id: user_id,
          achievement_key: achievement_key,
          unlocked_at: DateTime.utc_now()
        })
        |> Repo.insert()

      _existing ->
        {:already_unlocked, nil}
    end
  end

  @doc """
  Checks and unlocks achievements based on lesson count.
  Called after a new lesson is created.
  """
  def check_lesson_achievements(user_id) do
    lesson_count = Lessons.count_lessons_by_user(user_id)
    thresholds = lesson_achievement_thresholds()

    newly_unlocked =
      thresholds
      |> Enum.filter(fn {_key, required} -> lesson_count >= required end)
      |> Enum.reduce([], fn {key, _required}, acc ->
        maybe_add_unlocked_achievement(acc, user_id, key)
      end)

    award_xp_for_achievements(user_id, newly_unlocked)
    newly_unlocked
  end

  defp lesson_achievement_thresholds do
    [
      {"first_lesson", 1},
      {"lesson_explorer", 5},
      {"lesson_master", 25},
      {"lesson_legend", 100}
    ]
  end

  defp maybe_add_unlocked_achievement(acc, user_id, key) do
    case unlock_achievement(user_id, key) do
      {:ok, achievement} -> [achievement | acc]
      _ -> acc
    end
  end

  defp award_xp_for_achievements(user_id, achievements) do
    Enum.each(achievements, fn achievement ->
      definition = get_achievement_definition(achievement.achievement_key)
      if definition, do: award_xp(user_id, definition.xp)
    end)
  end

  @doc """
  Awards XP to a user and levels up if needed.
  """
  def award_xp(user_id, xp_amount) do
    user = Repo.get!(User, user_id)
    new_xp = (user.experience_points || 0) + xp_amount
    new_level = calculate_level(new_xp)

    user
    |> Ecto.Changeset.change(%{
      experience_points: new_xp,
      level: new_level
    })
    |> Repo.update()
  end

  @doc """
  Calculates level based on XP.
  """
  def calculate_level(xp) do
    # Level 1: 0-99 XP
    # Level 2: 100-299 XP
    # Level 3: 300-599 XP
    # Each level requires progressively more XP
    level = 1
    xp_needed = @xp_per_level

    do_calculate_level(xp, level, xp_needed)
  end

  defp do_calculate_level(xp, level, xp_needed) when xp >= xp_needed do
    # Next level requires 50% more XP
    next_xp_needed = xp_needed + round(@xp_per_level * (level * 0.5))
    do_calculate_level(xp - xp_needed, level + 1, next_xp_needed)
  end

  defp do_calculate_level(_xp, level, _xp_needed), do: level

  @doc """
  Returns XP needed for the next level.
  """
  def xp_for_next_level(current_level) do
    # Same formula as calculate_level
    round(@xp_per_level * (1 + (current_level - 1) * 0.5))
  end

  @doc """
  Returns user's current XP progress towards next level.
  """
  def get_level_progress(user) do
    xp = user.experience_points || 0
    level = user.level || 1

    # Calculate XP accumulated in previous levels
    xp_in_previous_levels =
      Enum.reduce(1..(level - 1)//1, 0, fn l, acc ->
        acc + round(@xp_per_level * (1 + (l - 1) * 0.5))
      end)

    current_level_xp = xp - xp_in_previous_levels
    xp_for_next = xp_for_next_level(level)

    %{
      level: level,
      current_xp: current_level_xp,
      xp_for_next_level: xp_for_next,
      total_xp: xp,
      progress_percent: min(round(current_level_xp / xp_for_next * 100), 100)
    }
  end

  @doc """
  Returns count of unlocked achievements for a user.
  """
  def count_user_achievements(user_id) do
    UserAchievement
    |> where([ua], ua.user_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns total available achievements count.
  """
  def total_achievements_count do
    map_size(@achievements)
  end
end
