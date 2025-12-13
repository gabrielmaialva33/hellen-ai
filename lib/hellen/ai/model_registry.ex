defmodule Hellen.AI.ModelRegistry do
  @moduledoc """
  Registry of all available NVIDIA NIM models with metadata for intelligent selection.

  This module provides:
  - Complete catalog of available models by category
  - Model metadata (capabilities, cost, speed, quality ratings)
  - Smart model selection based on task requirements
  - UI-friendly descriptions for real-time status display

  ## Categories

  | Category      | Purpose                                    |
  |---------------|--------------------------------------------|
  | `:analysis`   | Pedagogical analysis, reasoning, compliance|
  | `:reasoning`  | Deep thinking, chain-of-thought            |
  | `:ocr`        | Document text extraction                   |
  | `:embedding`  | Text/code embeddings for retrieval         |
  | `:transcription` | Audio to text (ASR)                     |
  | `:translation`| Multi-language translation                 |
  | `:safety`     | Content moderation, guardrails             |
  | `:coding`     | Code generation and analysis               |
  | `:vision`     | Image understanding                        |

  ## Usage

      iex> ModelRegistry.get_model(:analysis, :deep)
      %{id: "meta/llama-3.1-405b-instruct", ...}

      iex> ModelRegistry.list_models(:reasoning)
      [%{id: "qwen/qwq-32b", ...}, ...]
  """

  # ============================================================================
  # Analysis Models (Pedagogical, Reasoning, Compliance)
  # ============================================================================

  @analysis_models %{
    # Premium tier - Maximum quality
    deep: %{
      id: "meta/llama-3.1-405b-instruct",
      name: "Llama 3.1 405B",
      provider: "Meta",
      description: "Análise profunda com raciocínio avançado",
      description_en: "Deep analysis with advanced reasoning",
      params: "405B",
      quality: 5,
      speed: 1,
      cost_per_1k: 0.50,
      capabilities: [:reasoning, :analysis, :compliance, :cot],
      max_tokens: 8192,
      timeout_ms: 300_000,
      temperature: 0.45
    },

    # Standard tier - Best cost-benefit
    standard: %{
      id: "meta/llama-3.1-70b-instruct",
      name: "Llama 3.1 70B",
      provider: "Meta",
      description: "Análise padrão com ótimo custo-benefício",
      description_en: "Standard analysis with great cost-benefit",
      params: "70B",
      quality: 4,
      speed: 3,
      cost_per_1k: 0.05,
      capabilities: [:reasoning, :analysis, :compliance],
      max_tokens: 8192,
      timeout_ms: 120_000,
      temperature: 0.5
    },

    # Latest Llama 3.3 (improved)
    standard_v2: %{
      id: "meta/llama-3.3-70b-instruct",
      name: "Llama 3.3 70B",
      provider: "Meta",
      description: "Versão melhorada com raciocínio aprimorado",
      description_en: "Improved version with enhanced reasoning",
      params: "70B",
      quality: 4,
      speed: 3,
      cost_per_1k: 0.05,
      capabilities: [:reasoning, :analysis, :function_calling],
      max_tokens: 8192,
      timeout_ms: 120_000,
      temperature: 0.5
    },

    # Fast tier - Quick preliminary checks
    fast: %{
      id: "meta/llama-3.1-8b-instruct",
      name: "Llama 3.1 8B",
      provider: "Meta",
      description: "Verificação rápida preliminar",
      description_en: "Quick preliminary check",
      params: "8B",
      quality: 3,
      speed: 5,
      cost_per_1k: 0.01,
      capabilities: [:analysis, :quick_check],
      max_tokens: 4096,
      timeout_ms: 60_000,
      temperature: 0.7
    },

    # Portuguese specialized
    brazilian: %{
      id: "qwen/qwen3-235b-a22b",
      name: "Qwen3 235B",
      provider: "Alibaba",
      description: "Especializado em português e contexto brasileiro",
      description_en: "Specialized in Portuguese and Brazilian context",
      params: "235B (22B active)",
      quality: 5,
      speed: 2,
      cost_per_1k: 0.40,
      capabilities: [:multilingual, :portuguese, :reasoning, :analysis],
      max_tokens: 8192,
      timeout_ms: 180_000,
      temperature: 0.5
    },

    # Current production model
    qwen_standard: %{
      id: "qwen/qwen3-next-80b-a3b-instruct",
      name: "Qwen3 Next 80B",
      provider: "Alibaba",
      description: "Modelo de produção atual - híbrido MoE",
      description_en: "Current production model - hybrid MoE",
      params: "80B (3B active)",
      quality: 4,
      speed: 4,
      cost_per_1k: 0.03,
      capabilities: [:analysis, :agentic, :long_context],
      max_tokens: 32_768,
      timeout_ms: 120_000,
      temperature: 0.5
    },

    # NVIDIA Nemotron models
    nemotron_super: %{
      id: "nvidia/llama-3.3-nemotron-super-49b-v1.5",
      name: "Nemotron Super 49B",
      provider: "NVIDIA",
      description: "Alta eficiência com precisão líder",
      description_en: "High efficiency with leading accuracy",
      params: "49B",
      quality: 4,
      speed: 4,
      cost_per_1k: 0.04,
      capabilities: [:reasoning, :tool_calling, :chat],
      max_tokens: 8192,
      timeout_ms: 120_000,
      temperature: 0.5
    },

    nemotron_ultra: %{
      id: "nvidia/llama-3.1-nemotron-ultra-253b-v1",
      name: "Nemotron Ultra 253B",
      provider: "NVIDIA",
      description: "Máxima precisão para raciocínio científico",
      description_en: "Maximum accuracy for scientific reasoning",
      params: "253B",
      quality: 5,
      speed: 1,
      cost_per_1k: 0.60,
      capabilities: [:math, :science, :reasoning, :coding],
      max_tokens: 8192,
      timeout_ms: 300_000,
      temperature: 0.45
    },

    # Mistral Large
    mistral_large: %{
      id: "mistralai/mistral-large-3-675b-instruct-2512",
      name: "Mistral Large 675B",
      provider: "Mistral AI",
      description: "MoE de propósito geral para chat e agentes",
      description_en: "General purpose MoE for chat and agents",
      params: "675B MoE",
      quality: 5,
      speed: 2,
      cost_per_1k: 0.55,
      capabilities: [:chat, :agentic, :vision],
      max_tokens: 8192,
      timeout_ms: 240_000,
      temperature: 0.5
    }
  }

  # ============================================================================
  # Reasoning Models (Deep Thinking, Chain-of-Thought)
  # ============================================================================

  @reasoning_models %{
    qwq: %{
      id: "qwen/qwq-32b",
      name: "QwQ 32B",
      provider: "Alibaba",
      description: "Modelo de raciocínio profundo para problemas complexos",
      description_en: "Deep reasoning model for complex problems",
      params: "32B",
      quality: 5,
      speed: 2,
      cost_per_1k: 0.10,
      capabilities: [:reasoning, :math, :coding, :thinking],
      max_tokens: 8192,
      timeout_ms: 180_000,
      temperature: 0.3
    },

    deepseek_r1: %{
      id: "deepseek-ai/deepseek-r1",
      name: "DeepSeek R1",
      provider: "DeepSeek",
      description: "Raciocínio avançado para matemática e código",
      description_en: "Advanced reasoning for math and code",
      params: "MoE",
      quality: 5,
      speed: 2,
      cost_per_1k: 0.15,
      capabilities: [:reasoning, :math, :coding],
      max_tokens: 8192,
      timeout_ms: 180_000,
      temperature: 0.3
    },

    deepseek_r1_distill_32b: %{
      id: "deepseek-ai/deepseek-r1-distill-qwen-32b",
      name: "DeepSeek R1 Distill 32B",
      provider: "DeepSeek",
      description: "Versão destilada com raciocínio aprimorado",
      description_en: "Distilled version with enhanced reasoning",
      params: "32B",
      quality: 4,
      speed: 3,
      cost_per_1k: 0.08,
      capabilities: [:reasoning, :coding, :distillation],
      max_tokens: 8192,
      timeout_ms: 120_000,
      temperature: 0.3
    },

    kimi_k2_thinking: %{
      id: "moonshotai/kimi-k2-thinking",
      name: "Kimi K2 Thinking",
      provider: "Moonshot AI",
      description: "Modelo de raciocínio com contexto de 256K",
      description_en: "Reasoning model with 256K context",
      params: "MoE",
      quality: 4,
      speed: 2,
      cost_per_1k: 0.12,
      capabilities: [:reasoning, :long_context, :tool_use],
      max_tokens: 8192,
      timeout_ms: 180_000,
      temperature: 0.3
    },

    qwen_thinking: %{
      id: "qwen/qwen3-next-80b-a3b-thinking",
      name: "Qwen3 Next Thinking",
      provider: "Alibaba",
      description: "Raciocínio híbrido com MoE",
      description_en: "Hybrid reasoning with MoE",
      params: "80B (3B active)",
      quality: 4,
      speed: 3,
      cost_per_1k: 0.06,
      capabilities: [:reasoning, :multilingual],
      max_tokens: 8192,
      timeout_ms: 150_000,
      temperature: 0.3
    }
  }

  # ============================================================================
  # OCR Models (Document Text Extraction)
  # ============================================================================

  @ocr_models %{
    nemotron_parse: %{
      id: "nvidia/nemotron-parse",
      name: "Nemotron Parse",
      provider: "NVIDIA",
      description: "Extração de texto e metadados de imagens",
      description_en: "Text and metadata extraction from images",
      params: "VLM",
      quality: 5,
      speed: 3,
      cost_per_1k: 0.02,
      capabilities: [:ocr, :table_extraction, :layout],
      max_tokens: 8192,
      timeout_ms: 120_000
    },

    nemoretriever_ocr: %{
      id: "nvidia/nemoretriever-ocr-v1",
      name: "NemoRetriever OCR v1",
      provider: "NVIDIA",
      description: "OCR rápido e preciso para documentos",
      description_en: "Fast and accurate OCR for documents",
      params: "OCR",
      quality: 4,
      speed: 4,
      cost_per_1k: 0.01,
      capabilities: [:ocr, :layout, :structure],
      max_tokens: 4096,
      timeout_ms: 60_000
    },

    paddleocr: %{
      id: "baidu/paddleocr",
      name: "PaddleOCR",
      provider: "Baidu",
      description: "Extração de tabelas e OCR",
      description_en: "Table extraction and OCR",
      params: "OCR",
      quality: 4,
      speed: 4,
      cost_per_1k: 0.01,
      capabilities: [:ocr, :table_extraction],
      max_tokens: 4096,
      timeout_ms: 60_000
    },

    nemoretriever_parse: %{
      id: "nvidia/nemoretriever-parse",
      name: "NemoRetriever Parse",
      provider: "NVIDIA",
      description: "VLM avançado para extração de texto",
      description_en: "Advanced VLM for text extraction",
      params: "VLM",
      quality: 5,
      speed: 3,
      cost_per_1k: 0.02,
      capabilities: [:ocr, :vlm, :document_understanding],
      max_tokens: 8192,
      timeout_ms: 120_000
    }
  }

  # ============================================================================
  # Transcription Models (ASR - Audio to Text)
  # ============================================================================

  @transcription_models %{
    parakeet_multilingual: %{
      id: "nvidia/parakeet-1.1b-rnnt-multilingual-asr",
      name: "Parakeet Multilingual 1.1B",
      provider: "NVIDIA",
      description: "Transcrição em 25 idiomas",
      description_en: "Transcription in 25 languages",
      params: "1.1B",
      quality: 5,
      speed: 4,
      cost_per_1k: 0.02,
      capabilities: [:asr, :multilingual, :streaming],
      languages: 25
    },

    parakeet_portuguese: %{
      id: "nvidia/parakeet-ctc-0.6b-asr",
      name: "Parakeet CTC 0.6B",
      provider: "NVIDIA",
      description: "Transcrição otimizada para português",
      description_en: "Optimized transcription for Portuguese",
      params: "0.6B",
      quality: 4,
      speed: 5,
      cost_per_1k: 0.01,
      capabilities: [:asr, :streaming, :batch],
      languages: ["en", "pt"]
    },

    parakeet_spanish: %{
      id: "nvidia/parakeet-ctc-0.6b-es",
      name: "Parakeet Spanish 0.6B",
      provider: "NVIDIA",
      description: "Transcrição em espanhol e inglês",
      description_en: "Spanish and English transcription",
      params: "0.6B",
      quality: 4,
      speed: 5,
      cost_per_1k: 0.01,
      capabilities: [:asr, :streaming],
      languages: ["en", "es"]
    },

    whisper_large: %{
      id: "openai/whisper-large-v3",
      name: "Whisper Large v3",
      provider: "OpenAI",
      description: "Reconhecimento de fala robusto multilíngue",
      description_en: "Robust multilingual speech recognition",
      params: "1.5B",
      quality: 5,
      speed: 3,
      cost_per_1k: 0.03,
      capabilities: [:asr, :multilingual, :batch],
      languages: 100
    },

    canary: %{
      id: "nvidia/canary-1b-asr",
      name: "Canary 1B ASR",
      provider: "NVIDIA",
      description: "Transcrição e tradução multilíngue",
      description_en: "Multilingual transcription and translation",
      params: "1B",
      quality: 4,
      speed: 4,
      cost_per_1k: 0.02,
      capabilities: [:asr, :translation, :multilingual],
      languages: 4
    }
  }

  # ============================================================================
  # Translation Models
  # ============================================================================

  @translation_models %{
    riva_12lang: %{
      id: "nvidia/riva-translate-4b-instruct-v1.1",
      name: "Riva Translate 4B",
      provider: "NVIDIA",
      description: "Tradução em 12 idiomas com few-shot",
      description_en: "Translation in 12 languages with few-shot",
      params: "4B",
      quality: 4,
      speed: 4,
      cost_per_1k: 0.02,
      capabilities: [:translation, :few_shot],
      languages: 12
    },

    riva_36lang: %{
      id: "nvidia/riva-translate-1.6b",
      name: "Riva Translate 1.6B",
      provider: "NVIDIA",
      description: "Tradução em 36 idiomas",
      description_en: "Translation in 36 languages",
      params: "1.6B",
      quality: 4,
      speed: 5,
      cost_per_1k: 0.01,
      capabilities: [:translation],
      languages: 36
    },

    megatron_nmt: %{
      id: "nvidia/megatron-1b-nmt",
      name: "Megatron NMT 1B",
      provider: "NVIDIA",
      description: "Tradução neural em 36 idiomas",
      description_en: "Neural translation in 36 languages",
      params: "1B",
      quality: 4,
      speed: 5,
      cost_per_1k: 0.01,
      capabilities: [:translation, :nmt],
      languages: 36
    }
  }

  # ============================================================================
  # Safety/Guardrail Models
  # ============================================================================

  @safety_models %{
    nemotron_safety: %{
      id: "nvidia/llama-3.1-nemotron-safety-guard-8b-v3",
      name: "Nemotron Safety Guard 8B",
      provider: "NVIDIA",
      description: "Moderação de conteúdo multilíngue",
      description_en: "Multilingual content moderation",
      params: "8B",
      quality: 5,
      speed: 4,
      cost_per_1k: 0.01,
      capabilities: [:content_safety, :moderation, :multilingual]
    },

    nemoguard_jailbreak: %{
      id: "nvidia/nemoguard-jailbreak-detect",
      name: "NemoGuard Jailbreak",
      provider: "NVIDIA",
      description: "Detecção de tentativas de jailbreak",
      description_en: "Jailbreak attempt detection",
      params: "Guard",
      quality: 5,
      speed: 5,
      cost_per_1k: 0.005,
      capabilities: [:jailbreak_detection, :llm_security]
    },

    nemoguard_content: %{
      id: "nvidia/llama-3.1-nemoguard-8b-content-safety",
      name: "NemoGuard Content Safety",
      provider: "NVIDIA",
      description: "Segurança de conteúdo para LLMs",
      description_en: "Content safety for LLMs",
      params: "8B",
      quality: 5,
      speed: 4,
      cost_per_1k: 0.01,
      capabilities: [:content_safety, :moderation]
    },

    llama_guard: %{
      id: "meta/llama-guard-4-12b",
      name: "Llama Guard 4 12B",
      provider: "Meta",
      description: "Classificação de segurança multimodal",
      description_en: "Multimodal safety classification",
      params: "12B",
      quality: 5,
      speed: 4,
      cost_per_1k: 0.015,
      capabilities: [:safety, :multimodal, :classification]
    }
  }

  # ============================================================================
  # Coding Models
  # ============================================================================

  @coding_models %{
    devstral: %{
      id: "mistralai/devstral-2-123b-instruct-2512",
      name: "Devstral 2 123B",
      provider: "Mistral AI",
      description: "Modelo de código state-of-the-art com 256K contexto",
      description_en: "State-of-the-art code model with 256K context",
      params: "123B",
      quality: 5,
      speed: 2,
      cost_per_1k: 0.20,
      capabilities: [:coding, :reasoning, :long_context]
    },

    qwen_coder: %{
      id: "qwen/qwen3-coder-480b-a35b-instruct",
      name: "Qwen3 Coder 480B",
      provider: "Alibaba",
      description: "Excelente para código agêntico e navegação",
      description_en: "Excellent for agentic coding and browser use",
      params: "480B (35B active)",
      quality: 5,
      speed: 2,
      cost_per_1k: 0.25,
      capabilities: [:coding, :agentic, :browser_use]
    },

    qwen_coder_32b: %{
      id: "qwen/qwen2.5-coder-32b-instruct",
      name: "Qwen 2.5 Coder 32B",
      provider: "Alibaba",
      description: "Geração de código em múltiplas linguagens",
      description_en: "Code generation in multiple languages",
      params: "32B",
      quality: 4,
      speed: 3,
      cost_per_1k: 0.08,
      capabilities: [:coding, :completion, :generation]
    },

    mamba_codestral: %{
      id: "mistralai/mamba-codestral-7b-v0.1",
      name: "Mamba Codestral 7B",
      provider: "Mistral AI",
      description: "Modelo de código leve e rápido",
      description_en: "Lightweight and fast code model",
      params: "7B",
      quality: 3,
      speed: 5,
      cost_per_1k: 0.02,
      capabilities: [:coding, :completion]
    }
  }

  # ============================================================================
  # Embedding Models (for RAG/Retrieval)
  # ============================================================================

  @embedding_models %{
    nemoretriever_embed: %{
      id: "nvidia/llama-3_2-nemoretriever-300m-embed-v2",
      name: "NemoRetriever Embed 300M",
      provider: "NVIDIA",
      description: "Embeddings multilíngue para RAG",
      description_en: "Multilingual embeddings for RAG",
      params: "300M",
      quality: 4,
      speed: 5,
      cost_per_1k: 0.005,
      capabilities: [:embedding, :multilingual, :rag],
      languages: 26
    },

    nv_embedqa: %{
      id: "nvidia/llama-3.2-nv-embedqa-1b-v2",
      name: "NV EmbedQA 1B",
      provider: "NVIDIA",
      description: "Embeddings para Q&A retrieval",
      description_en: "Embeddings for Q&A retrieval",
      params: "1B",
      quality: 4,
      speed: 4,
      cost_per_1k: 0.01,
      capabilities: [:embedding, :qa, :retrieval]
    },

    nv_embedcode: %{
      id: "nvidia/nv-embedcode-7b-v1",
      name: "NV EmbedCode 7B",
      provider: "NVIDIA",
      description: "Embeddings otimizados para código",
      description_en: "Embeddings optimized for code",
      params: "7B",
      quality: 5,
      speed: 3,
      cost_per_1k: 0.02,
      capabilities: [:embedding, :code, :retrieval]
    },

    bge_m3: %{
      id: "baai/bge-m3",
      name: "BGE M3",
      provider: "BAAI",
      description: "Embeddings densos e esparsos",
      description_en: "Dense and sparse embeddings",
      params: "M3",
      quality: 5,
      speed: 4,
      cost_per_1k: 0.01,
      capabilities: [:embedding, :dense, :sparse, :multilingual]
    }
  }

  # ============================================================================
  # Vision Models (Image Understanding)
  # ============================================================================

  @vision_models %{
    llama_vision_90b: %{
      id: "meta/llama-3.2-90b-vision-instruct",
      name: "Llama 3.2 90B Vision",
      provider: "Meta",
      description: "Raciocínio de alta qualidade a partir de imagens",
      description_en: "High-quality reasoning from images",
      params: "90B",
      quality: 5,
      speed: 2,
      cost_per_1k: 0.30,
      capabilities: [:vision, :reasoning, :qa]
    },

    llama_vision_11b: %{
      id: "meta/llama-3.2-11b-vision-instruct",
      name: "Llama 3.2 11B Vision",
      provider: "Meta",
      description: "Modelo de visão leve e eficiente",
      description_en: "Lightweight and efficient vision model",
      params: "11B",
      quality: 4,
      speed: 4,
      cost_per_1k: 0.05,
      capabilities: [:vision, :qa, :retrieval]
    },

    vila: %{
      id: "nvidia/vila",
      name: "VILA",
      provider: "NVIDIA",
      description: "VLM para texto, imagem e vídeo",
      description_en: "VLM for text, image and video",
      params: "VLM",
      quality: 4,
      speed: 3,
      cost_per_1k: 0.08,
      capabilities: [:vision, :video, :multimodal]
    },

    gemma_vision: %{
      id: "google/gemma-3-27b-it",
      name: "Gemma 3 27B",
      provider: "Google",
      description: "Modelo multimodal de alta qualidade",
      description_en: "High-quality multimodal model",
      params: "27B",
      quality: 4,
      speed: 3,
      cost_per_1k: 0.06,
      capabilities: [:vision, :reasoning, :chat]
    }
  }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Returns a model by category and tier/key.

  ## Examples

      iex> ModelRegistry.get_model(:analysis, :standard)
      %{id: "meta/llama-3.1-70b-instruct", ...}

      iex> ModelRegistry.get_model(:reasoning, :qwq)
      %{id: "qwen/qwq-32b", ...}
  """
  @spec get_model(atom(), atom()) :: map() | nil
  def get_model(:analysis, key), do: Map.get(@analysis_models, key)
  def get_model(:reasoning, key), do: Map.get(@reasoning_models, key)
  def get_model(:ocr, key), do: Map.get(@ocr_models, key)
  def get_model(:transcription, key), do: Map.get(@transcription_models, key)
  def get_model(:translation, key), do: Map.get(@translation_models, key)
  def get_model(:safety, key), do: Map.get(@safety_models, key)
  def get_model(:coding, key), do: Map.get(@coding_models, key)
  def get_model(:embedding, key), do: Map.get(@embedding_models, key)
  def get_model(:vision, key), do: Map.get(@vision_models, key)
  def get_model(_, _), do: nil

  @doc """
  Lists all models in a category.
  """
  @spec list_models(atom()) :: [map()]
  def list_models(:analysis), do: Map.values(@analysis_models)
  def list_models(:reasoning), do: Map.values(@reasoning_models)
  def list_models(:ocr), do: Map.values(@ocr_models)
  def list_models(:transcription), do: Map.values(@transcription_models)
  def list_models(:translation), do: Map.values(@translation_models)
  def list_models(:safety), do: Map.values(@safety_models)
  def list_models(:coding), do: Map.values(@coding_models)
  def list_models(:embedding), do: Map.values(@embedding_models)
  def list_models(:vision), do: Map.values(@vision_models)
  def list_models(_), do: []

  @doc """
  Returns all categories available.
  """
  @spec list_categories() :: [atom()]
  def list_categories do
    [:analysis, :reasoning, :ocr, :transcription, :translation, :safety, :coding, :embedding, :vision]
  end

  @doc """
  Finds model info by model ID string.
  """
  @spec find_by_id(String.t()) :: map() | nil
  def find_by_id(model_id) do
    list_categories()
    |> Enum.flat_map(&list_models/1)
    |> Enum.find(&(&1.id == model_id))
  end

  @doc """
  Returns the default model for a category.
  """
  @spec default_model(atom()) :: map() | nil
  def default_model(:analysis), do: get_model(:analysis, :standard)
  def default_model(:reasoning), do: get_model(:reasoning, :qwq)
  def default_model(:ocr), do: get_model(:ocr, :nemotron_parse)
  def default_model(:transcription), do: get_model(:transcription, :parakeet_multilingual)
  def default_model(:translation), do: get_model(:translation, :riva_12lang)
  def default_model(:safety), do: get_model(:safety, :nemotron_safety)
  def default_model(:coding), do: get_model(:coding, :qwen_coder_32b)
  def default_model(:embedding), do: get_model(:embedding, :nemoretriever_embed)
  def default_model(:vision), do: get_model(:vision, :llama_vision_11b)
  def default_model(_), do: nil

  @doc """
  Returns model info formatted for UI display.
  """
  @spec model_for_display(String.t()) :: map()
  def model_for_display(model_id) do
    case find_by_id(model_id) do
      nil ->
        %{
          id: model_id,
          name: extract_name_from_id(model_id),
          provider: extract_provider_from_id(model_id),
          description: "Modelo personalizado",
          quality: 3,
          speed: 3
        }

      model ->
        model
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp extract_name_from_id(model_id) do
    model_id
    |> String.split("/")
    |> List.last()
    |> String.replace("-", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp extract_provider_from_id(model_id) do
    model_id
    |> String.split("/")
    |> List.first()
    |> String.capitalize()
  end
end
