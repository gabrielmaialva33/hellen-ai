defmodule Hellen.Cache.Serializer do
  @moduledoc """
  Serialization and deserialization for cache values.

  Uses :erlang.term_to_binary for efficient serialization of Elixir terms,
  with support for Ecto schemas and special types.

  ## Encoding Strategy

  - Simple types (strings, numbers, booleans): stored as-is or JSON
  - Maps and lists: encoded as JSON for readability
  - Ecto schemas: converted to maps, metadata removed
  - Complex Elixir terms: encoded with :erlang.term_to_binary

  ## Format Detection

  Encoded values are prefixed with a type byte:
  - `j:` - JSON encoded
  - `e:` - Erlang term encoded
  - `r:` - Raw string (no encoding)
  """

  require Logger

  @json_prefix "j:"
  @term_prefix "e:"
  @raw_prefix "r:"

  @doc """
  Encode a value for storage in Redis.
  """
  @spec encode(any()) :: binary()
  def encode(nil), do: @raw_prefix <> "null"
  def encode(value) when is_binary(value), do: @raw_prefix <> value
  def encode(value) when is_integer(value), do: @raw_prefix <> Integer.to_string(value)
  def encode(value) when is_float(value), do: @raw_prefix <> Float.to_string(value)
  def encode(true), do: @raw_prefix <> "true"
  def encode(false), do: @raw_prefix <> "false"

  def encode(%{__struct__: _} = struct) do
    struct
    |> sanitize_struct()
    |> encode_json()
  end

  def encode(value) when is_map(value) or is_list(value) do
    encode_json(value)
  end

  def encode(value) do
    # Fallback to Erlang term encoding for complex types
    @term_prefix <> :erlang.term_to_binary(value)
  end

  @doc """
  Decode a value retrieved from Redis.
  """
  @spec decode(binary() | nil) :: any()
  def decode(nil), do: nil

  def decode(@raw_prefix <> "null"), do: nil
  def decode(@raw_prefix <> "true"), do: true
  def decode(@raw_prefix <> "false"), do: false

  def decode(@raw_prefix <> value) do
    # Try to parse as number first
    case Integer.parse(value) do
      {int, ""} ->
        int

      _ ->
        case Float.parse(value) do
          {float, ""} -> float
          _ -> value
        end
    end
  end

  def decode(@json_prefix <> json) do
    case Jason.decode(json) do
      {:ok, value} -> restore_atoms(value)
      {:error, _} -> json
    end
  end

  def decode(@term_prefix <> binary) do
    :erlang.binary_to_term(binary, [:safe])
  rescue
    ArgumentError ->
      Logger.warning("[Cache.Serializer] Failed to decode term, returning raw binary")
      binary
  end

  # Fallback for unrecognized format (legacy or raw values)
  def decode(value) when is_binary(value) do
    # Try JSON first (for backwards compatibility)
    case Jason.decode(value) do
      {:ok, decoded} -> restore_atoms(decoded)
      {:error, _} -> value
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp encode_json(value) do
    case Jason.encode(value) do
      {:ok, json} ->
        @json_prefix <> json

      {:error, _} ->
        # Fallback to term encoding if JSON fails
        @term_prefix <> :erlang.term_to_binary(value)
    end
  end

  defp sanitize_struct(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> sanitize_map()
  end

  defp sanitize_map(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {sanitize_key(k), sanitize_value(v)} end)
  end

  defp sanitize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp sanitize_key(key), do: key

  defp sanitize_value(%{__struct__: _} = struct), do: sanitize_struct(struct)
  defp sanitize_value(map) when is_map(map), do: sanitize_map(map)
  defp sanitize_value(list) when is_list(list), do: Enum.map(list, &sanitize_value/1)
  defp sanitize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp sanitize_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp sanitize_value(%Date{} = d), do: Date.to_iso8601(d)
  defp sanitize_value(%Decimal{} = d), do: Decimal.to_float(d)
  defp sanitize_value(value), do: value

  # Restore common atom keys from string keys
  @atom_keys ~w(
    id user_id lesson_id analysis_id institution_id
    status type name title subject email
    inserted_at updated_at created_at
    score overall_score confidence_score
    total completed processing pending failed
    credits balance
  )

  defp restore_atoms(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      key = if k in @atom_keys, do: String.to_existing_atom(k), else: k
      {key, restore_atoms(v)}
    end)
  rescue
    ArgumentError -> Map.new(map, fn {k, v} -> {k, restore_atoms(v)} end)
  end

  defp restore_atoms(list) when is_list(list) do
    Enum.map(list, &restore_atoms/1)
  end

  defp restore_atoms(value), do: value
end
