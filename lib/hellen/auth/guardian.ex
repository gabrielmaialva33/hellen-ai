defmodule Hellen.Auth.Guardian do
  @moduledoc """
  Guardian implementation for JWT token management.

  Used to generate and verify local JWT tokens after Firebase authentication.
  """

  use Guardian, otp_app: :hellen

  alias Hellen.Accounts
  alias Hellen.Accounts.User

  @doc """
  Returns the subject for the token (user ID).
  """
  def subject_for_token(%User{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def subject_for_token(_, _) do
    {:error, :invalid_resource}
  end

  @doc """
  Retrieves the user from the token claims.
  """
  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  def resource_from_claims(_claims) do
    {:error, :invalid_claims}
  end

  @doc """
  Generates access and refresh tokens for a user.
  """
  def generate_tokens(user) do
    with {:ok, access_token, _claims} <- encode_and_sign(user, %{}, token_type: "access", ttl: {1, :hour}),
         {:ok, refresh_token, _claims} <- encode_and_sign(user, %{}, token_type: "refresh", ttl: {7, :day}) do
      {:ok, %{access_token: access_token, refresh_token: refresh_token}}
    end
  end

  @doc """
  Refreshes an access token using a refresh token.
  """
  def refresh_access_token(refresh_token) do
    with {:ok, claims} <- decode_and_verify(refresh_token),
         {:ok, user} <- resource_from_claims(claims) do
      encode_and_sign(user, %{}, token_type: "access", ttl: {1, :hour})
    end
  end
end
