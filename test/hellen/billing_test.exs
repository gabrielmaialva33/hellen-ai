defmodule Hellen.BillingTest do
  use Hellen.DataCase, async: true

  alias Hellen.Billing

  describe "credits" do
    test "get_balance/1 returns user credits" do
      user = insert(:user, credits: 50)
      assert Billing.get_balance(user) == 50
    end

    test "check_credits/1 returns :ok with sufficient credits" do
      user = insert(:user, credits: 10)
      assert Billing.check_credits(user) == :ok
    end

    test "check_credits/1 returns error with insufficient credits" do
      user = insert(:user, credits: 0)
      assert Billing.check_credits(user) == {:error, :insufficient_credits}
    end

    test "add_credits/4 adds credits to user" do
      user = insert(:user, credits: 10)
      assert {:ok, updated} = Billing.add_credits(user, 5, "gift")
      assert updated.credits == 15
    end

    test "add_credits/4 creates transaction record" do
      user = insert(:user, credits: 10)
      {:ok, _updated} = Billing.add_credits(user, 5, "purchase")

      transactions = Billing.list_transactions(user.id)
      assert length(transactions) == 1

      transaction = hd(transactions)
      assert transaction.amount == 5
      assert transaction.balance_after == 15
      assert transaction.reason == "purchase"
    end

    test "deduct_credits/4 deducts credits from user" do
      user = insert(:user, credits: 10)
      assert {:ok, updated} = Billing.deduct_credits(user, 3, "lesson_analysis")
      assert updated.credits == 7
    end

    test "deduct_credits/4 returns error with insufficient credits" do
      user = insert(:user, credits: 2)
      assert {:error, :insufficient_credits} = Billing.deduct_credits(user, 5, "lesson_analysis")
    end

    test "deduct_credits/4 creates transaction record" do
      user = insert(:user, credits: 10)
      {:ok, _updated} = Billing.deduct_credits(user, 3, "lesson_analysis")

      transactions = Billing.list_transactions(user.id)
      transaction = hd(transactions)

      assert transaction.amount == -3
      assert transaction.balance_after == 7
      assert transaction.reason == "lesson_analysis"
    end

    test "use_credit/2 deducts one credit for lesson" do
      user = insert(:user, credits: 5)
      lesson = insert(:lesson, user: user)

      assert {:ok, updated} = Billing.use_credit(user, lesson.id)
      assert updated.credits == 4
    end

    test "use_credit/2 returns error with zero credits" do
      user = insert(:user, credits: 0)
      lesson = insert(:lesson, user: user)

      assert {:error, :insufficient_credits} = Billing.use_credit(user, lesson.id)
    end

    test "refund_credit/2 adds back one credit" do
      user = insert(:user, credits: 5)
      lesson = insert(:lesson, user: user)

      assert {:ok, updated} = Billing.refund_credit(user, lesson.id)
      assert updated.credits == 6
    end

    test "grant_signup_bonus/1 adds signup bonus credits" do
      user = insert(:user, credits: 0)
      assert {:ok, updated} = Billing.grant_signup_bonus(user)
      assert updated.credits == 2
    end
  end

  describe "transactions" do
    test "list_transactions/2 returns user transactions" do
      user = insert(:user, credits: 20)
      Billing.add_credits(user, 5, "gift")
      Billing.add_credits(user, 10, "purchase")

      transactions = Billing.list_transactions(user.id)
      assert length(transactions) == 2
    end

    test "list_transactions/2 orders by inserted_at desc" do
      user = insert(:user, credits: 20)
      Billing.add_credits(user, 5, "gift")
      # Sleep 1+ second since inserted_at is truncated to seconds
      :timer.sleep(1100)
      Billing.add_credits(user, 10, "purchase")

      [first, second] = Billing.list_transactions(user.id)
      # Most recent
      assert first.amount == 10
      assert second.amount == 5
    end

    test "list_transactions/2 respects limit" do
      user = insert(:user, credits: 50)
      for _ <- 1..5, do: Billing.add_credits(user, 1, "gift")

      transactions = Billing.list_transactions(user.id, limit: 3)
      assert length(transactions) == 3
    end

    test "list_transactions_filtered/2 filters by reason" do
      user = insert(:user, credits: 20)
      Billing.add_credits(user, 5, "gift")
      Billing.add_credits(user, 10, "purchase")

      {transactions, total} = Billing.list_transactions_filtered(user.id, reason: "gift")
      assert length(transactions) == 1
      assert total == 1
      assert hd(transactions).reason == "gift"
    end

    test "list_transactions_filtered/2 returns total count" do
      user = insert(:user, credits: 50)
      for _ <- 1..5, do: Billing.add_credits(user, 1, "gift")

      {transactions, total} = Billing.list_transactions_filtered(user.id, limit: 2)
      assert length(transactions) == 2
      assert total == 5
    end
  end

  describe "usage statistics" do
    test "get_usage_stats/2 returns usage statistics" do
      user = insert(:user, credits: 50)
      Billing.add_credits(user, 10, "purchase")
      user = Repo.get!(Hellen.Accounts.User, user.id)
      Billing.deduct_credits(user, 3, "lesson_analysis")

      stats = Billing.get_usage_stats(user.id, 30)

      assert stats.total_added == 10
      assert stats.total_used == 3
      assert stats.transaction_count == 2
      assert is_map(stats.by_reason)
    end

    test "get_daily_usage/2 returns daily breakdown" do
      user = insert(:user, credits: 20)
      Billing.add_credits(user, 5, "purchase")

      daily = Billing.get_daily_usage(user.id, 7)

      # Today + 7 previous days
      assert length(daily) == 8
      today = Date.utc_today()
      today_data = Enum.find(daily, &(&1.date == today))
      assert today_data.added == 5
    end

    test "get_analyses_count/1 returns lesson analysis count" do
      user = insert(:user, credits: 20)
      lesson1 = insert(:lesson, user: user)
      lesson2 = insert(:lesson, user: user)
      Billing.use_credit(user, lesson1.id)
      user = Repo.get!(Hellen.Accounts.User, user.id)
      Billing.use_credit(user, lesson2.id)

      count = Billing.get_analyses_count(user.id)
      assert count == 2
    end
  end

  describe "packages" do
    test "credit_packages/0 returns available packages" do
      packages = Billing.credit_packages()

      assert length(packages) == 3
      assert Enum.find(packages, &(&1.id == "basic"))
      assert Enum.find(packages, &(&1.id == "standard"))
      assert Enum.find(packages, &(&1.id == "pro"))
    end

    test "credit_packages/0 includes price information" do
      [basic | _] = Billing.credit_packages()

      assert basic.credits == 10
      assert basic.price == 2990
      assert basic.price_display == "R$ 29,90"
    end

    test "add_credits_with_stripe/4 adds credits with payment tracking" do
      user = insert(:user, credits: 10)
      {:ok, updated} = Billing.add_credits_with_stripe(user, 10, "basic", "pi_123456")
      assert updated.credits == 20

      [transaction] = Billing.list_transactions(user.id)
      assert transaction.reason == "purchase"
      assert transaction.stripe_payment_intent_id == "pi_123456"
    end
  end
end
