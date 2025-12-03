defmodule Hellen.Auth.Firebase do
  @moduledoc """
  Firebase ID Token verification using JOSE.

  Verifies tokens issued by Firebase Authentication by:
  1. Fetching Google's public keys (with caching)
  2. Verifying JWT signature using RS256
  3. Validating claims (issuer, audience, expiration)
  """

  require Logger

  @google_certs_url "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
  @cache_ttl :timer.hours(1)

  @doc """
  Verifies a Firebase ID token and returns the decoded claims.

  ## Options
    * `:project_id` - Firebase project ID (required for audience validation)

  ## Returns
    * `{:ok, claims}` - Token is valid, returns decoded claims map
    * `{:error, reason}` - Token is invalid
  """
  def verify_id_token(token, opts \\ []) do
    project_id = opts[:project_id] || get_project_id()

    with {:ok, header} <- peek_header(token),
         {:ok, certs} <- fetch_google_certs(),
         {:ok, jwk} <- get_jwk_for_kid(certs, header["kid"]),
         {:ok, claims} <- verify_signature(token, jwk),
         :ok <- validate_claims(claims, project_id) do
      {:ok, claims}
    end
  end

  @doc """
  Extracts user info from verified Firebase claims.
  """
  def extract_user_info(claims) do
    %{
      firebase_uid: claims["sub"],
      email: claims["email"],
      email_verified: claims["email_verified"] || false,
      name: claims["name"],
      picture: claims["picture"],
      provider: get_provider(claims),
      raw_claims: claims
    }
  end

  # Private functions

  defp get_project_id do
    Application.get_env(:hellen, :firebase)[:project_id] || "hellen-ai"
  end

  defp peek_header(token) do
    case String.split(token, ".") do
      [header_b64 | _] ->
        case Base.url_decode64(header_b64, padding: false) do
          {:ok, header_json} ->
            {:ok, Jason.decode!(header_json)}

          :error ->
            {:error, :invalid_token_format}
        end

      _ ->
        {:error, :invalid_token_format}
    end
  end

  defp fetch_google_certs do
    cache_key = :firebase_google_certs
    now = System.system_time(:millisecond)

    case :persistent_term.get(cache_key, nil) do
      {certs, expires_at} when is_integer(expires_at) ->
        if expires_at > now do
          {:ok, certs}
        else
          fetch_and_cache_certs(cache_key)
        end

      _ ->
        fetch_and_cache_certs(cache_key)
    end
  end

  defp fetch_and_cache_certs(cache_key) do
    case Req.get(@google_certs_url) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        expires_at = System.system_time(:millisecond) + @cache_ttl
        :persistent_term.put(cache_key, {body, expires_at})
        {:ok, body}

      {:ok, %{status: status}} ->
        Logger.error("Failed to fetch Google certs: HTTP #{status}")
        {:error, :certs_fetch_failed}

      {:error, reason} ->
        Logger.error("Failed to fetch Google certs: #{inspect(reason)}")
        {:error, :certs_fetch_failed}
    end
  end

  defp get_jwk_for_kid(certs, kid) do
    case Map.get(certs, kid) do
      nil ->
        {:error, :unknown_key_id}

      cert_pem ->
        jwk = JOSE.JWK.from_pem(cert_pem)
        {:ok, jwk}
    end
  end

  defp verify_signature(token, jwk) do
    case JOSE.JWT.verify_strict(jwk, ["RS256"], token) do
      {true, %JOSE.JWT{fields: fields}, _jws} ->
        {:ok, fields}

      {false, _, _} ->
        {:error, :invalid_signature}
    end
  end

  defp validate_claims(claims, project_id) do
    now = System.system_time(:second)
    expected_issuer = "https://securetoken.google.com/#{project_id}"

    cond do
      claims["iss"] != expected_issuer ->
        {:error, :invalid_issuer}

      claims["aud"] != project_id ->
        {:error, :invalid_audience}

      claims["exp"] <= now ->
        {:error, :token_expired}

      claims["iat"] > now ->
        {:error, :token_not_yet_valid}

      is_nil(claims["sub"]) or claims["sub"] == "" ->
        {:error, :missing_subject}

      true ->
        :ok
    end
  end

  defp get_provider(claims) do
    case claims["firebase"]["sign_in_provider"] do
      "password" -> "email"
      "google.com" -> "google"
      provider -> provider
    end
  rescue
    _ -> "unknown"
  end
end
