defmodule HellenWeb.API.AuthControllerTest do
  use HellenWeb.ConnCase, async: true
  alias Hellen.Auth.Guardian

  describe "POST /api/auth/register" do
    test "creates user with valid data", %{conn: conn} do
      institution = insert(:institution)

      params = %{
        "email" => "test@example.com",
        "password" => "password123",
        "name" => "Test User",
        "institution_id" => institution.id
      }

      conn = post(conn, ~p"/api/auth/register", params)
      response = json_response(conn, 201)

      assert response["data"]["user"]["email"] == "test@example.com"
      assert response["data"]["user"]["name"] == "Test User"
      assert response["data"]["access_token"]
      assert response["data"]["refresh_token"]
    end

    test "returns error with invalid email", %{conn: conn} do
      params = %{
        "email" => "invalid-email",
        "password" => "password123",
        "name" => "Test User"
      }

      conn = post(conn, ~p"/api/auth/register", params)
      assert json_response(conn, 422)
    end

    test "returns error with short password", %{conn: conn} do
      params = %{
        "email" => "test@example.com",
        "password" => "short",
        "name" => "Test User"
      }

      conn = post(conn, ~p"/api/auth/register", params)
      assert json_response(conn, 422)
    end

    test "returns error with duplicate email", %{conn: conn} do
      existing_user = insert(:user)

      params = %{
        "email" => existing_user.email,
        "password" => "password123",
        "name" => "Test User"
      }

      conn = post(conn, ~p"/api/auth/register", params)
      assert json_response(conn, 422)
    end

    test "returns error with missing required fields", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", %{})
      response = json_response(conn, 400)
      assert response["error"] =~ "Missing required fields"
    end
  end

  describe "POST /api/auth/login" do
    test "returns token with valid credentials", %{conn: conn} do
      user = insert(:user)

      params = %{
        "email" => user.email,
        "password" => "password123"
      }

      conn = post(conn, ~p"/api/auth/login", params)
      response = json_response(conn, 200)

      assert response["data"]["user"]["id"] == user.id
      assert response["data"]["access_token"]
      assert response["data"]["refresh_token"]
    end

    test "returns error with invalid password", %{conn: conn} do
      user = insert(:user)

      params = %{
        "email" => user.email,
        "password" => "wrong_password"
      }

      conn = post(conn, ~p"/api/auth/login", params)
      assert json_response(conn, 401)
    end

    test "returns error with unknown email", %{conn: conn} do
      params = %{
        "email" => "nonexistent@example.com",
        "password" => "password123"
      }

      conn = post(conn, ~p"/api/auth/login", params)
      assert json_response(conn, 401)
    end

    test "returns error with missing credentials", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{})
      response = json_response(conn, 400)
      assert response["error"] =~ "Missing email or password"
    end
  end

  describe "POST /api/auth/refresh" do
    test "returns new access token with valid refresh token", %{conn: conn} do
      user = insert(:user)
      {:ok, tokens} = Guardian.generate_tokens(user)

      params = %{"refresh_token" => tokens.refresh_token}
      conn = post(conn, ~p"/api/auth/refresh", params)
      response = json_response(conn, 200)

      assert response["data"]["access_token"]
    end

    test "returns error with invalid refresh token", %{conn: conn} do
      params = %{"refresh_token" => "invalid_token"}
      conn = post(conn, ~p"/api/auth/refresh", params)
      assert json_response(conn, 401)
    end

    test "returns error without refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{})
      response = json_response(conn, 400)
      assert response["error"] =~ "Missing refresh_token"
    end
  end

  describe "GET /api/auth/me" do
    setup :register_and_log_in_user

    test "returns current user with valid token", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/auth/me")
      response = json_response(conn, 200)

      assert response["data"]["user"]["id"] == user.id
      assert response["data"]["user"]["email"] == user.email
    end

    test "returns 401 without token", %{conn: _conn} do
      conn = build_conn()
      conn = get(conn, ~p"/api/auth/me")
      assert json_response(conn, 401)
    end
  end

  describe "POST /api/auth/firebase" do
    test "returns error without id_token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/firebase", %{})
      response = json_response(conn, 400)
      assert response["error"] =~ "Missing id_token"
    end
  end
end
