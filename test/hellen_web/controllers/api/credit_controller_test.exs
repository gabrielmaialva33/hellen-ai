defmodule HellenWeb.API.CreditControllerTest do
  use HellenWeb.ConnCase, async: true

  alias Hellen.Billing

  describe "GET /api/credits" do
    setup :register_and_log_in_user

    test "returns current credit balance", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/credits")
      response = json_response(conn, 200)

      assert response["data"]["credits"] == user.credits
    end

    test "returns updated balance after credit change", %{conn: conn, user: user} do
      # Add credits
      {:ok, _} = Billing.add_credits(user, 50, "gift")

      conn = get(conn, ~p"/api/credits")
      response = json_response(conn, 200)

      assert response["data"]["credits"] == user.credits + 50
    end

    test "returns 401 without auth", %{conn: _conn} do
      conn = build_conn()
      conn = get(conn, ~p"/api/credits")
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/credits/history" do
    setup :register_and_log_in_user

    test "returns paginated transaction history", %{conn: conn, user: user} do
      Billing.add_credits(user, 10, "gift")
      Billing.add_credits(user, 20, "purchase")

      conn = get(conn, ~p"/api/credits/history")
      response = json_response(conn, 200)

      assert length(response["data"]) == 2
    end

    test "returns empty list for user without transactions", %{conn: conn} do
      conn = get(conn, ~p"/api/credits/history")
      response = json_response(conn, 200)

      assert response["data"] == []
    end

    test "respects limit parameter", %{conn: conn, user: user} do
      for _ <- 1..5, do: Billing.add_credits(user, 1, "gift")

      conn = get(conn, ~p"/api/credits/history?limit=3")
      response = json_response(conn, 200)

      assert length(response["data"]) == 3
    end

    test "returns 401 without auth", %{conn: _conn} do
      conn = build_conn()
      conn = get(conn, ~p"/api/credits/history")
      assert json_response(conn, 401)
    end
  end
end
