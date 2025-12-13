defmodule Hellen.AI.NemotronOCR do
  @moduledoc """
  OCR extraction using NVIDIA Nemotron Parse model.

  Nemotron Parse is a vision-encoder-decoder model that extracts
  formatted text from images, including PDFs and documents.
  """

  require Logger

  @nvidia_url "https://integrate.api.nvidia.com/v1/chat/completions"
  @model "nvidia/nemotron-parse"
  @max_tokens 8192
  @timeout 120_000

  @doc """
  Extracts text from an image using Nemotron Parse OCR.

  ## Options
  - `:mode` - Output mode: `:markdown` (default), `:markdown_bbox`, or `:detection_only`

  Returns {:ok, text} on success, {:error, reason} on failure.
  """
  @spec extract_from_image(binary(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def extract_from_image(image_data, opts \\ []) when is_binary(image_data) do
    mode = Keyword.get(opts, :mode, :markdown)
    tool_name = tool_for_mode(mode)

    with {:ok, api_key} <- get_api_key(),
         {:ok, response} <- call_api(api_key, image_data, tool_name) do
      extract_text_from_response(response)
    end
  end

  @doc """
  Extracts text from an image file path.
  """
  @spec extract_from_file(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def extract_from_file(path, opts \\ []) do
    case File.read(path) do
      {:ok, data} -> extract_from_image(data, opts)
      {:error, reason} -> {:error, {:file_read_error, reason}}
    end
  end

  @doc """
  Extracts text from multiple images and combines results.
  """
  @spec extract_from_images([binary()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def extract_from_images(images, opts \\ []) when is_list(images) do
    results =
      images
      |> Enum.with_index(1)
      |> Enum.map(fn {image_data, idx} ->
        Logger.info("[NemotronOCR] Processing image #{idx}/#{length(images)}")

        case extract_from_image(image_data, opts) do
          {:ok, text} -> {:ok, idx, text}
          {:error, reason} -> {:error, idx, reason}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _, _}, &1))

    if length(errors) == length(images) do
      # All failed
      {:error, :all_images_failed}
    else
      # Combine successful extractions
      text =
        results
        |> Enum.filter(&match?({:ok, _, _}, &1))
        |> Enum.sort_by(fn {:ok, idx, _} -> idx end)
        |> Enum.map_join("\n\n---\n\n", fn {:ok, idx, text} -> "[Página #{idx}]\n#{text}" end)

      {:ok, text}
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp get_api_key do
    case Application.get_env(:hellen, :nvidia_api_key) || System.get_env("NVIDIA_API_KEY") do
      nil -> {:error, :api_key_not_configured}
      key -> {:ok, key}
    end
  end

  defp tool_for_mode(:markdown), do: "markdown_no_bbox"
  defp tool_for_mode(:markdown_bbox), do: "markdown_bbox"
  defp tool_for_mode(:detection_only), do: "detection_only"
  defp tool_for_mode(_), do: "markdown_no_bbox"

  defp call_api(api_key, image_data, tool_name) do
    b64 = Base.encode64(image_data)
    mime = detect_mime(image_data)
    media_tag = "data:#{mime};base64,#{b64}"

    body = %{
      "model" => @model,
      "messages" => [
        %{
          "role" => "user",
          "content" => [
            %{
              "type" => "image_url",
              "image_url" => %{
                "url" => media_tag
              }
            }
          ]
        }
      ],
      "tools" => [
        %{
          "type" => "function",
          "function" => %{
            "name" => tool_name
          }
        }
      ],
      "max_tokens" => @max_tokens
    }

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    case Req.post(@nvidia_url, json: body, headers: headers, receive_timeout: @timeout) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("[NemotronOCR] API error #{status}: #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.warning("[NemotronOCR] Request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  defp extract_text_from_response(response) do
    # The response contains the extracted text in tool_calls or content
    case response do
      %{
        "choices" => [
          %{"message" => %{"tool_calls" => [%{"function" => %{"arguments" => args}}]}} | _
        ]
      } ->
        # Tool call response - arguments contains the extracted text
        extract_from_arguments(args)

      %{"choices" => [%{"message" => %{"content" => content}} | _]} when is_binary(content) ->
        {:ok, clean_ocr_text(content)}

      %{"choices" => [%{"message" => message} | _]} ->
        # Try to extract text from any available field
        text = message["content"] || message["text"] || ""
        {:ok, clean_ocr_text(text)}

      other ->
        Logger.warning("[NemotronOCR] Unexpected response format: #{inspect(other)}")
        {:error, :unexpected_response_format}
    end
  end

  defp extract_from_arguments(args) when is_binary(args) do
    case Jason.decode(args) do
      {:ok, %{"text" => text}} when is_binary(text) ->
        {:ok, clean_ocr_text(text)}

      {:ok, %{"content" => text}} when is_binary(text) ->
        {:ok, clean_ocr_text(text)}

      {:ok, list} when is_list(list) ->
        # Handle list of objects with "text" keys
        text =
          list
          |> Enum.map(fn
            %{"text" => t} when is_binary(t) -> clean_ocr_text(t)
            %{"content" => t} when is_binary(t) -> clean_ocr_text(t)
            _ -> ""
          end)
          |> Enum.reject(&(&1 == ""))
          |> Enum.join("\n\n")

        {:ok, text}

      {:ok, %{} = map} ->
        # Try to find any text field
        text = map["text"] || map["content"] || map["result"] || ""
        {:ok, clean_ocr_text(to_string(text))}

      {:error, _} ->
        # If JSON parsing fails, return as-is
        {:ok, clean_ocr_text(args)}
    end
  end

  defp clean_ocr_text(text) when is_binary(text) do
    text
    |> String.replace(~r/<class_[^>]+>/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/ \n/m, "\n")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  defp clean_ocr_text(other), do: inspect(other)

  defp detect_mime(<<0x89, 0x50, 0x4E, 0x47, _::binary>>), do: "image/png"
  defp detect_mime(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "image/jpeg"
  defp detect_mime(<<0x47, 0x49, 0x46, _::binary>>), do: "image/gif"
  defp detect_mime(<<0x42, 0x4D, _::binary>>), do: "image/bmp"
  defp detect_mime(_), do: "image/png"
end
