defmodule Hellen.Lessons.DocxExtractor do
  @moduledoc """
  Extracts text content from DOCX files.

  DOCX files are ZIP archives containing XML files.
  The main content is in `word/document.xml`.

  Handles:
  - Standard text content in <w:t> elements
  - Image-only documents using Nemotron Parse OCR
  - Mixed content documents

  Uses built-in :zip module for extraction.
  """

  alias Hellen.AI.NemotronOCR

  require Logger

  @doc """
  Extracts text content from a DOCX file.

  Returns {:ok, text} on success, {:error, reason} on failure.
  """
  @spec extract(binary() | String.t()) :: {:ok, String.t()} | {:error, term()}
  def extract(path) when is_binary(path) do
    with {:ok, document_xml} <- extract_document_xml(path),
         {:ok, text} <- parse_document_xml(document_xml) do
      cleaned = clean_text(text)

      if String.length(cleaned) > 50 do
        # Document has real text content
        {:ok, cleaned}
      else
        # Fallback: document might be image-only, use OCR
        Logger.info("[DocxExtractor] Limited text found (#{String.length(cleaned)} chars), trying OCR")
        extract_with_ocr(path)
      end
    end
  rescue
    e ->
      Logger.warning("[DocxExtractor] Failed to extract DOCX: #{inspect(e)}")
      {:error, :extraction_failed}
  end

  @doc """
  Checks if a file is a DOCX file based on extension.
  """
  @spec docx?(String.t()) :: boolean()
  def docx?(filename) when is_binary(filename) do
    filename
    |> String.downcase()
    |> String.ends_with?(".docx")
  end

  def docx?(_), do: false

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp extract_document_xml(path) do
    # DOCX is a ZIP file, extract word/document.xml
    case :zip.unzip(String.to_charlist(path), [:memory, {:file_list, [~c"word/document.xml"]}]) do
      {:ok, [{~c"word/document.xml", content}]} ->
        {:ok, content}

      {:ok, []} ->
        {:error, :document_xml_not_found}

      {:error, reason} ->
        Logger.warning("[DocxExtractor] ZIP extraction failed: #{inspect(reason)}")
        {:error, :invalid_docx}
    end
  end

  defp parse_document_xml(xml) do
    xml_str = to_string(xml)

    # Strategy 1: Extract from <w:t> tags (most common)
    text_from_wt =
      Regex.scan(~r/<w:t[^>]*>([^<]*)<\/w:t>/s, xml_str)
      |> Enum.map(fn [_, content] -> content end)
      |> Enum.join(" ")

    # Strategy 2: Extract from <t> tags without namespace
    text_from_t =
      if String.length(text_from_wt) == 0 do
        Regex.scan(~r/<t[^>]*>([^<]*)<\/t>/s, xml_str)
        |> Enum.map(fn [_, content] -> content end)
        |> Enum.join(" ")
      else
        ""
      end

    combined = String.trim(text_from_wt <> " " <> text_from_t)
    {:ok, combined}
  rescue
    e ->
      Logger.warning("[DocxExtractor] Parse failed: #{inspect(e)}")
      {:ok, ""}
  end

  defp extract_with_ocr(path) do
    case extract_images_from_docx(path) do
      {:ok, images} when length(images) > 0 ->
        Logger.info("[DocxExtractor] Found #{length(images)} images, running OCR...")
        NemotronOCR.extract_from_images(images)

      {:ok, []} ->
        {:error, :no_images_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_images_from_docx(path) do
    case :zip.unzip(String.to_charlist(path), [:memory]) do
      {:ok, files} ->
        images =
          files
          |> Enum.filter(fn {name, _} ->
            name_str = to_string(name)
            String.starts_with?(name_str, "word/media/") and
              (String.ends_with?(name_str, ".png") or
               String.ends_with?(name_str, ".jpg") or
               String.ends_with?(name_str, ".jpeg"))
          end)
          |> Enum.sort_by(fn {name, _} -> to_string(name) end)
          |> Enum.map(fn {_name, data} -> data end)

        {:ok, images}

      {:error, reason} ->
        Logger.warning("[DocxExtractor] Failed to extract images: #{inspect(reason)}")
        {:error, :image_extraction_failed}
    end
  end

  defp clean_text(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
