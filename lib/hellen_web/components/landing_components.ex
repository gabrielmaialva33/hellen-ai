defmodule HellenWeb.LandingComponents do
  @moduledoc """
  Landing page components for Hellen AI.

  Includes:
  - Navbar for landing page
  - Hero section with animated background
  - How it works section
  - Feature cards and sections
  - Pricing cards and section
  - Testimonials
  - CTA section
  - Footer
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  import HellenWeb.CoreComponents, only: [icon: 1]

  # ============================================================================
  # NAVBAR
  # ============================================================================

  @doc """
  Renders the landing page navbar.

  ## Examples

      <.landing_navbar />
  """
  attr :class, :string, default: nil

  def landing_navbar(assigns) do
    ~H"""
    <nav class={[
      "fixed top-0 left-0 right-0 z-50",
      "bg-white/80 dark:bg-slate-900/80 backdrop-blur-md",
      "border-b border-slate-200/50 dark:border-slate-700/50",
      "transition-all duration-300",
      @class
    ]}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-16">
          <!-- Logo -->
          <div class="flex items-center">
            <a href="/" class="flex items-center group">
              <span class="text-2xl font-bold bg-gradient-to-r from-teal-600 to-cyan-500 dark:from-teal-400 dark:to-cyan-400 bg-clip-text text-transparent">
                Hellen
              </span>
              <span class="ml-1.5 text-xs font-semibold text-slate-500 dark:text-slate-400 group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors">
                AI
              </span>
            </a>
          </div>
          <!-- Navigation Links (Desktop) -->
          <div class="hidden md:flex items-center gap-8">
            <a
              href="#features"
              class="text-sm font-medium text-slate-700 dark:text-slate-300 hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
            >
              Recursos
            </a>
            <a
              href="#pricing"
              class="text-sm font-medium text-slate-700 dark:text-slate-300 hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
            >
              Preços
            </a>
            <a
              href="#testimonials"
              class="text-sm font-medium text-slate-700 dark:text-slate-300 hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
            >
              Depoimentos
            </a>
            <a
              href="#contact"
              class="text-sm font-medium text-slate-700 dark:text-slate-300 hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
            >
              Contato
            </a>
          </div>
          <!-- Actions -->
          <div class="flex items-center gap-2 sm:gap-3">
            <button
              id="theme-toggle"
              phx-hook="ThemeToggle"
              class="p-2 text-slate-400 dark:text-slate-300 hover:text-slate-600 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              title="Alternar tema"
            >
              <.icon name="hero-sun" class="h-5 w-5 dark:hidden" />
              <.icon name="hero-moon" class="h-5 w-5 hidden dark:block" />
            </button>

            <a
              href="/login"
              class="hidden md:block text-sm font-medium text-slate-700 dark:text-slate-300 hover:text-teal-600 dark:hover:text-teal-400 transition-colors px-3 py-2"
            >
              Entrar
            </a>

            <a
              href="/register"
              class="hidden sm:inline-flex items-center justify-center px-4 py-2 text-sm font-semibold text-white bg-teal-600 hover:bg-teal-700 rounded-xl transition-all duration-200 shadow-sm hover:shadow-md hover:shadow-teal-500/25"
            >
              Criar Conta
            </a>
            <!-- Mobile menu button -->
            <button
              type="button"
              class="md:hidden p-2 text-slate-400 dark:text-slate-300 hover:text-slate-600 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              phx-click={JS.toggle(to: "#mobile-menu", in: "fade-in-scale", out: "fade-out-scale")}
              aria-expanded="false"
              aria-controls="mobile-menu"
            >
              <span class="sr-only">Abrir menu</span>
              <.icon name="hero-bars-3" class="h-6 w-6" />
            </button>
          </div>
        </div>
      </div>
      <!-- Mobile menu -->
      <div
        id="mobile-menu"
        class="hidden md:hidden bg-white/95 dark:bg-slate-900/95 backdrop-blur-md border-t border-slate-200/50 dark:border-slate-700/50"
      >
        <div class="px-4 py-4 space-y-3">
          <a
            href="#features"
            class="block px-3 py-2 text-base font-medium text-slate-700 dark:text-slate-300 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-50 dark:hover:bg-slate-800 rounded-lg transition-colors"
            phx-click={JS.hide(to: "#mobile-menu")}
          >
            Recursos
          </a>
          <a
            href="#pricing"
            class="block px-3 py-2 text-base font-medium text-slate-700 dark:text-slate-300 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-50 dark:hover:bg-slate-800 rounded-lg transition-colors"
            phx-click={JS.hide(to: "#mobile-menu")}
          >
            Preços
          </a>
          <a
            href="#testimonials"
            class="block px-3 py-2 text-base font-medium text-slate-700 dark:text-slate-300 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-50 dark:hover:bg-slate-800 rounded-lg transition-colors"
            phx-click={JS.hide(to: "#mobile-menu")}
          >
            Depoimentos
          </a>
          <a
            href="#contact"
            class="block px-3 py-2 text-base font-medium text-slate-700 dark:text-slate-300 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-50 dark:hover:bg-slate-800 rounded-lg transition-colors"
            phx-click={JS.hide(to: "#mobile-menu")}
          >
            Contato
          </a>

          <div class="pt-3 border-t border-slate-200 dark:border-slate-700 space-y-3">
            <a
              href="/login"
              class="block px-3 py-2 text-base font-medium text-slate-700 dark:text-slate-300 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-50 dark:hover:bg-slate-800 rounded-lg transition-colors"
            >
              Entrar
            </a>
            <a
              href="/register"
              class="block w-full text-center px-4 py-2.5 text-base font-semibold text-white bg-teal-600 hover:bg-teal-700 rounded-xl transition-colors duration-200"
            >
              Criar Conta Gratuita
            </a>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  # ============================================================================
  # HERO SECTION
  # ============================================================================

  @doc """
  Renders the hero section with animated background.

  ## Examples

      <.hero_section />
  """
  attr :class, :string, default: nil

  def hero_section(assigns) do
    ~H"""
    <section class={[
      "relative min-h-screen flex items-center justify-center overflow-hidden",
      "bg-gradient-to-br from-slate-50 via-teal-50/30 to-cyan-50/20",
      "dark:from-slate-900 dark:via-teal-950/30 dark:to-cyan-950/20",
      "pt-16",
      @class
    ]}>
      <!-- Animated background orbs -->
      <div class="absolute inset-0 overflow-hidden pointer-events-none">
        <div class="absolute top-1/4 left-1/4 w-96 h-96 bg-teal-400/20 dark:bg-teal-500/10 rounded-full blur-3xl animate-float" />
        <div class="absolute bottom-1/4 right-1/4 w-96 h-96 bg-cyan-400/20 dark:bg-cyan-500/10 rounded-full blur-3xl animate-float-delayed" />
        <div class="absolute top-1/2 left-1/2 w-96 h-96 bg-emerald-400/10 dark:bg-emerald-500/5 rounded-full blur-3xl animate-pulse-glow" />
      </div>
      <!-- Grid pattern -->
      <div class="absolute inset-0 bg-[linear-gradient(to_right,#8882_1px,transparent_1px),linear-gradient(to_bottom,#8882_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_110%)] dark:opacity-20" />

      <div class="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24 lg:py-32">
        <div class="text-center max-w-4xl mx-auto">
          <!-- Badge -->
          <div class="inline-flex items-center gap-2 px-3 sm:px-4 py-1.5 rounded-full bg-teal-100/80 dark:bg-teal-900/30 backdrop-blur-sm mb-6 sm:mb-8 animate-fade-in-up border border-teal-200/50 dark:border-teal-700/50">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-teal-400 opacity-75">
              </span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-teal-500"></span>
            </span>
            <span class="text-xs sm:text-sm font-semibold text-teal-700 dark:text-teal-300">
              Feedback pedagógico com IA
            </span>
          </div>
          <!-- Headline -->
          <h1 class="text-3xl sm:text-5xl lg:text-6xl xl:text-7xl font-bold text-slate-900 dark:text-white mb-4 sm:mb-6 animate-fade-in-up leading-tight tracking-tight">
            Transforme suas aulas com
            <span class="bg-gradient-to-r from-teal-600 to-cyan-500 dark:from-teal-400 dark:to-cyan-400 bg-clip-text text-transparent">
              feedback inteligente
            </span>
          </h1>
          <!-- Subtitle -->
          <p class="text-base sm:text-xl lg:text-2xl text-slate-600 dark:text-slate-300 mb-8 sm:mb-12 max-w-3xl mx-auto animate-fade-in-up leading-relaxed px-2">
            Analise gravações de aulas automaticamente com base na
            <strong class="text-teal-600 dark:text-teal-400">BNCC</strong>
            e <strong class="text-teal-600 dark:text-teal-400">Lei 13.185</strong>. Receba insights pedagógicos em minutos.
          </p>
          <!-- CTAs -->
          <div class="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center items-center mb-10 sm:mb-16 animate-fade-in-up px-4 sm:px-0">
            <a
              href="/register"
              class="group inline-flex items-center justify-center px-6 sm:px-8 py-3.5 sm:py-4 text-base font-semibold text-white bg-teal-600 hover:bg-teal-700 rounded-xl transition-all duration-200 shadow-lg hover:shadow-xl hover:shadow-teal-500/25 hover:scale-105 w-full sm:w-auto"
            >
              Comece Grátis
              <.icon
                name="hero-arrow-right"
                class="ml-2 h-5 w-5 group-hover:translate-x-1 transition-transform"
              />
            </a>

            <a
              href="#features"
              class="inline-flex items-center justify-center px-6 sm:px-8 py-3.5 sm:py-4 text-base font-semibold text-teal-600 dark:text-teal-400 bg-white dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700 border-2 border-teal-200 dark:border-teal-800 rounded-xl transition-all duration-200 w-full sm:w-auto shadow-sm"
            >
              <.icon name="hero-sparkles" class="mr-2 h-5 w-5" /> Ver Recursos
            </a>
          </div>
          <!-- Social Proof Enhanced -->
          <div class="flex flex-col sm:flex-row items-center justify-center gap-4 sm:gap-6 animate-fade-in-up">
            <div class="flex items-center gap-3">
              <div class="flex -space-x-2">
                <div class="w-8 h-8 rounded-full bg-gradient-to-br from-teal-400 to-teal-500 border-2 border-white dark:border-slate-900 flex items-center justify-center text-white text-xs font-bold">
                  M
                </div>
                <div class="w-8 h-8 rounded-full bg-gradient-to-br from-cyan-400 to-cyan-500 border-2 border-white dark:border-slate-900 flex items-center justify-center text-white text-xs font-bold">
                  J
                </div>
                <div class="w-8 h-8 rounded-full bg-gradient-to-br from-emerald-400 to-emerald-500 border-2 border-white dark:border-slate-900 flex items-center justify-center text-white text-xs font-bold">
                  A
                </div>
                <div class="w-8 h-8 rounded-full bg-gradient-to-br from-amber-400 to-amber-500 border-2 border-white dark:border-slate-900 flex items-center justify-center text-white text-xs font-bold">
                  R
                </div>
                <div class="w-8 h-8 rounded-full bg-slate-200 dark:bg-slate-700 border-2 border-white dark:border-slate-900 flex items-center justify-center text-slate-600 dark:text-slate-300 text-xs font-bold">
                  +
                </div>
              </div>
              <div class="text-sm text-slate-600 dark:text-slate-400">
                <strong class="text-slate-900 dark:text-white">847</strong> professores ativos
              </div>
            </div>
            <div class="hidden sm:block w-px h-6 bg-slate-300 dark:bg-slate-700"></div>
            <div class="flex items-center gap-2">
              <div class="flex items-center gap-0.5 text-amber-400">
                <.icon name="hero-star-solid" class="h-4 w-4" />
                <.icon name="hero-star-solid" class="h-4 w-4" />
                <.icon name="hero-star-solid" class="h-4 w-4" />
                <.icon name="hero-star-solid" class="h-4 w-4" />
                <.icon name="hero-star-solid" class="h-4 w-4" />
              </div>
              <span class="text-sm text-slate-600 dark:text-slate-400">
                <strong class="text-slate-900 dark:text-white">4.9</strong>/5 (312 avaliações)
              </span>
            </div>
          </div>
          <!-- Trust Badges -->
          <div class="mt-8 flex flex-wrap items-center justify-center gap-4 sm:gap-8 text-xs text-slate-500 dark:text-slate-400 animate-fade-in-up">
            <div class="flex items-center gap-2">
              <.icon name="hero-shield-check" class="h-5 w-5 text-emerald-500" />
              <span>Dados Criptografados</span>
            </div>
            <div class="flex items-center gap-2">
              <.icon name="hero-academic-cap" class="h-5 w-5 text-teal-500" />
              <span>Alinhado à BNCC</span>
            </div>
            <div class="flex items-center gap-2">
              <.icon name="hero-clock" class="h-5 w-5 text-cyan-500" />
              <span>Análise em &lt;5 min</span>
            </div>
          </div>
        </div>
      </div>
      <!-- Scroll indicator -->
      <div class="absolute bottom-8 left-1/2 -translate-x-1/2 animate-bounce">
        <.icon name="hero-chevron-down" class="h-6 w-6 text-slate-400" />
      </div>
    </section>
    """
  end

  # ============================================================================
  # IMPACT METRICS SECTION
  # ============================================================================

  @doc """
  Renders the impact metrics section.

  ## Examples

      <.impact_metrics />
  """
  attr :class, :string, default: nil

  def impact_metrics(assigns) do
    ~H"""
    <section class={[
      "py-16 bg-gradient-to-r from-teal-600 to-cyan-600 dark:from-teal-800 dark:to-cyan-800",
      @class
    ]}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-8 text-center text-white">
          <div data-animate>
            <div class="text-4xl sm:text-5xl font-bold mb-2">12.847</div>
            <div class="text-teal-100 text-sm sm:text-base">Aulas Analisadas</div>
          </div>
          <div data-animate>
            <div class="text-4xl sm:text-5xl font-bold mb-2">847</div>
            <div class="text-teal-100 text-sm sm:text-base">Professores Ativos</div>
          </div>
          <div data-animate>
            <div class="text-4xl sm:text-5xl font-bold mb-2">98.7%</div>
            <div class="text-teal-100 text-sm sm:text-base">Satisfação</div>
          </div>
          <div data-animate>
            <div class="text-4xl sm:text-5xl font-bold mb-2">&lt;5min</div>
            <div class="text-teal-100 text-sm sm:text-base">Tempo Médio</div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # HOW IT WORKS SECTION
  # ============================================================================

  @doc """
  Renders the how it works section.

  ## Examples

      <.how_it_works />
  """
  attr :class, :string, default: nil

  def how_it_works(assigns) do
    ~H"""
    <section
      class={[
        "py-24 bg-white dark:bg-slate-900",
        @class
      ]}
      data-animate
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-16">
          <div class="inline-flex items-center px-3 py-1 rounded-full bg-teal-100 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300 text-sm font-medium mb-4">
            Processo Simples
          </div>
          <h2 class="text-4xl sm:text-5xl font-bold text-slate-900 dark:text-white mb-4 tracking-tight">
            Como funciona
          </h2>
          <p class="text-xl text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
            Análise pedagógica em 4 passos simples
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          <!-- Step 1 -->
          <div class="relative group" data-animate>
            <div class="text-center">
              <div class="relative inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-teal-100 dark:bg-teal-900/30 text-teal-600 dark:text-teal-400 mb-4 group-hover:scale-110 group-hover:shadow-lg group-hover:shadow-teal-500/25 transition-all duration-300">
                <.icon name="hero-cloud-arrow-up" class="h-8 w-8" />
                <span class="absolute -top-2 -right-2 w-6 h-6 bg-teal-600 text-white text-xs font-bold rounded-full flex items-center justify-center">
                  1
                </span>
              </div>
              <div class="absolute top-8 left-full w-full h-0.5 bg-gradient-to-r from-teal-300 to-transparent dark:from-teal-700 hidden lg:block" />
              <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-2">
                Upload
              </h3>
              <p class="text-slate-600 dark:text-slate-400 text-sm">
                Envie sua gravação de áudio ou vídeo
              </p>
            </div>
          </div>
          <!-- Step 2 -->
          <div class="relative group" data-animate>
            <div class="text-center">
              <div class="relative inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-cyan-100 dark:bg-cyan-900/30 text-cyan-600 dark:text-cyan-400 mb-4 group-hover:scale-110 group-hover:shadow-lg group-hover:shadow-cyan-500/25 transition-all duration-300">
                <.icon name="hero-document-text" class="h-8 w-8" />
                <span class="absolute -top-2 -right-2 w-6 h-6 bg-cyan-600 text-white text-xs font-bold rounded-full flex items-center justify-center">
                  2
                </span>
              </div>
              <div class="absolute top-8 left-full w-full h-0.5 bg-gradient-to-r from-cyan-300 to-transparent dark:from-cyan-700 hidden lg:block" />
              <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-2">
                Transcrição
              </h3>
              <p class="text-slate-600 dark:text-slate-400 text-sm">
                IA transcreve automaticamente o conteúdo
              </p>
            </div>
          </div>
          <!-- Step 3 -->
          <div class="relative group" data-animate>
            <div class="text-center">
              <div class="relative inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 mb-4 group-hover:scale-110 group-hover:shadow-lg group-hover:shadow-emerald-500/25 transition-all duration-300">
                <.icon name="hero-academic-cap" class="h-8 w-8" />
                <span class="absolute -top-2 -right-2 w-6 h-6 bg-emerald-600 text-white text-xs font-bold rounded-full flex items-center justify-center">
                  3
                </span>
              </div>
              <div class="absolute top-8 left-full w-full h-0.5 bg-gradient-to-r from-emerald-300 to-transparent dark:from-emerald-700 hidden lg:block" />
              <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-2">
                Análise
              </h3>
              <p class="text-slate-600 dark:text-slate-400 text-sm">
                Avaliação pedagógica baseada na BNCC
              </p>
            </div>
          </div>
          <!-- Step 4 -->
          <div class="relative group" data-animate>
            <div class="text-center">
              <div class="relative inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400 mb-4 group-hover:scale-110 group-hover:shadow-lg group-hover:shadow-amber-500/25 transition-all duration-300">
                <.icon name="hero-light-bulb" class="h-8 w-8" />
                <span class="absolute -top-2 -right-2 w-6 h-6 bg-amber-600 text-white text-xs font-bold rounded-full flex items-center justify-center">
                  4
                </span>
              </div>
              <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-2">
                Plano de Ação
              </h3>
              <p class="text-slate-600 dark:text-slate-400 text-sm">
                Receba sugestões de melhorias personalizadas
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # FEATURE CARD
  # ============================================================================

  @doc """
  Renders a feature card.

  ## Examples

      <.feature_card
        icon="hero-bolt"
        title="Rápido"
        description="Análise em minutos"
        stat="99%"
        stat_label="Precisão"
        color="blue"
      />
  """
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :stat, :string, default: nil
  attr :stat_label, :string, default: nil
  attr :color, :string, default: "blue", values: ~w(blue green yellow red purple)
  attr :class, :string, default: nil

  def feature_card(assigns) do
    ~H"""
    <div
      class={[
        "group relative bg-white dark:bg-slate-800 rounded-xl sm:rounded-2xl p-5 sm:p-8",
        "border border-slate-200/50 dark:border-slate-700/50",
        "hover:border-transparent hover:shadow-xl hover:shadow-slate-200/50 dark:hover:shadow-slate-900/50",
        "transition-all duration-300",
        "overflow-hidden",
        @class
      ]}
      data-animate
    >
      <!-- Colored bottom border on hover -->
      <div class={[
        "absolute bottom-0 left-0 right-0 h-1 transform scale-x-0 group-hover:scale-x-100 transition-transform duration-300",
        feature_color_border(@color)
      ]} />
      <!-- Icon -->
      <div class={[
        "inline-flex items-center justify-center w-12 h-12 sm:w-14 sm:h-14 rounded-xl mb-4 sm:mb-6 group-hover:scale-110 transition-transform duration-300",
        feature_color_bg(@color)
      ]}>
        <.icon name={@icon} class={"h-6 w-6 sm:h-7 sm:w-7 #{feature_color_text(@color)}"} />
      </div>
      <!-- Content -->
      <h3 class="text-lg sm:text-xl font-semibold text-slate-900 dark:text-white mb-2 sm:mb-3">
        <%= @title %>
      </h3>
      <p class="text-sm sm:text-base text-slate-600 dark:text-slate-400 mb-4 sm:mb-6">
        <%= @description %>
      </p>
      <!-- Stats -->
      <div :if={@stat} class="pt-4 sm:pt-6 border-t border-slate-200 dark:border-slate-700">
        <div class={["text-2xl sm:text-3xl font-bold mb-1", feature_color_text(@color)]}>
          <%= @stat %>
        </div>
        <div class="text-xs sm:text-sm text-slate-500 dark:text-slate-400">
          <%= @stat_label %>
        </div>
      </div>
    </div>
    """
  end

  defp feature_color_bg("blue"), do: "bg-teal-100 dark:bg-teal-900/30"
  defp feature_color_bg("green"), do: "bg-emerald-100 dark:bg-emerald-900/30"
  defp feature_color_bg("yellow"), do: "bg-amber-100 dark:bg-amber-900/30"
  defp feature_color_bg("red"), do: "bg-red-100 dark:bg-red-900/30"
  defp feature_color_bg("purple"), do: "bg-violet-100 dark:bg-violet-900/30"
  defp feature_color_bg("teal"), do: "bg-teal-100 dark:bg-teal-900/30"
  defp feature_color_bg("cyan"), do: "bg-cyan-100 dark:bg-cyan-900/30"
  defp feature_color_bg(_), do: "bg-teal-100 dark:bg-teal-900/30"

  defp feature_color_text("blue"), do: "text-teal-600 dark:text-teal-400"
  defp feature_color_text("green"), do: "text-emerald-600 dark:text-emerald-400"
  defp feature_color_text("yellow"), do: "text-amber-600 dark:text-amber-400"
  defp feature_color_text("red"), do: "text-red-600 dark:text-red-400"
  defp feature_color_text("purple"), do: "text-violet-600 dark:text-violet-400"
  defp feature_color_text("teal"), do: "text-teal-600 dark:text-teal-400"
  defp feature_color_text("cyan"), do: "text-cyan-600 dark:text-cyan-400"
  defp feature_color_text(_), do: "text-teal-600 dark:text-teal-400"

  defp feature_color_border("blue"), do: "bg-gradient-to-r from-teal-500 to-cyan-500"
  defp feature_color_border("green"), do: "bg-gradient-to-r from-emerald-500 to-teal-500"
  defp feature_color_border("yellow"), do: "bg-gradient-to-r from-amber-500 to-amber-600"
  defp feature_color_border("red"), do: "bg-gradient-to-r from-red-500 to-red-600"
  defp feature_color_border("purple"), do: "bg-gradient-to-r from-violet-500 to-violet-600"
  defp feature_color_border("teal"), do: "bg-gradient-to-r from-teal-500 to-cyan-500"
  defp feature_color_border("cyan"), do: "bg-gradient-to-r from-cyan-500 to-teal-500"
  defp feature_color_border(_), do: "bg-gradient-to-r from-teal-500 to-cyan-500"

  # ============================================================================
  # FEATURES SECTION
  # ============================================================================

  @doc """
  Renders the features section with feature cards.

  ## Examples

      <.features_section />
  """
  attr :class, :string, default: nil

  def features_section(assigns) do
    ~H"""
    <section
      id="features"
      class={[
        "py-16 sm:py-24 bg-gray-50 dark:bg-slate-950",
        @class
      ]}
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-10 sm:mb-16">
          <h2 class="text-3xl sm:text-4xl lg:text-5xl font-bold text-gray-900 dark:text-white mb-3 sm:mb-4">
            Recursos Poderosos
          </h2>
          <p class="text-base sm:text-xl text-gray-600 dark:text-gray-400 max-w-2xl mx-auto px-2">
            Tudo que você precisa para melhorar suas aulas
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-8">
          <.feature_card
            icon="hero-microphone"
            title="Transcrição Automática"
            description="IA de última geração transforma áudio em texto com alta precisão, suportando diversos formatos de arquivo."
            stat="99%"
            stat_label="Precisão"
            color="blue"
          />

          <.feature_card
            icon="hero-academic-cap"
            title="Feedback BNCC"
            description="Análise pedagógica alinhada à Base Nacional Comum Curricular, identificando competências e habilidades."
            stat="100%"
            stat_label="Alinhado BNCC"
            color="green"
          />

          <.feature_card
            icon="hero-shield-check"
            title="Lei 13.185 Anti-Bullying"
            description="Detecção automática de comportamentos inadequados e situações de bullying, garantindo ambiente seguro."
            stat="98%"
            stat_label="Detecção"
            color="red"
          />

          <.feature_card
            icon="hero-light-bulb"
            title="Plano de Ação"
            description="Sugestões práticas e personalizadas de melhorias pedagógicas com base na análise da sua aula."
            stat="100%"
            stat_label="Personalizado"
            color="yellow"
          />
        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # PRICING CARD
  # ============================================================================

  @doc """
  Renders a pricing card.

  ## Examples

      <.pricing_card
        name="Pro"
        price="R$ 49"
        period="/mês"
        description="Para professores individuais"
        features={["20 análises/mês", "Suporte prioritário"]}
        popular={true}
        cta_text="Começar"
        cta_link="/register"
      />
  """
  attr :name, :string, required: true
  attr :price, :string, required: true
  attr :period, :string, default: ""
  attr :description, :string, required: true
  attr :features, :list, required: true
  attr :popular, :boolean, default: false
  attr :cta_text, :string, default: "Começar"
  attr :cta_link, :string, default: "/register"
  attr :class, :string, default: nil

  def pricing_card(assigns) do
    ~H"""
    <div
      class={[
        "relative bg-white dark:bg-slate-800 rounded-2xl p-8",
        "border-2",
        @popular && "border-teal-500 shadow-xl shadow-teal-500/10 scale-105",
        !@popular && "border-slate-200 dark:border-slate-700",
        "transition-all duration-300 hover:shadow-lg",
        @class
      ]}
      data-animate
    >
      <!-- Popular badge -->
      <div :if={@popular} class="absolute -top-4 left-1/2 -translate-x-1/2">
        <span class="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full bg-gradient-to-r from-teal-600 to-cyan-500 text-white text-sm font-semibold shadow-lg">
          <.icon name="hero-star-solid" class="h-4 w-4" /> Mais Popular
        </span>
      </div>
      <!-- Plan name -->
      <h3 class="text-2xl font-bold text-slate-900 dark:text-white mb-2">
        <%= @name %>
      </h3>
      <!-- Description -->
      <p class="text-slate-600 dark:text-slate-400 mb-6">
        <%= @description %>
      </p>
      <!-- Price -->
      <div class="mb-8">
        <div class="flex items-baseline">
          <span class="text-5xl font-bold text-slate-900 dark:text-white">
            <%= @price %>
          </span>
          <span class="ml-2 text-slate-600 dark:text-slate-400">
            <%= @period %>
          </span>
        </div>
      </div>
      <!-- Features -->
      <ul class="space-y-4 mb-8">
        <li :for={feature <- @features} class="flex items-start">
          <.icon
            name="hero-check-circle"
            class="h-6 w-6 text-emerald-500 dark:text-emerald-400 mr-3 flex-shrink-0"
          />
          <span class="text-slate-700 dark:text-slate-300">
            <%= feature %>
          </span>
        </li>
      </ul>
      <!-- CTA -->
      <a
        href={@cta_link}
        class={[
          "block w-full text-center px-6 py-3 rounded-xl font-semibold transition-all duration-200",
          @popular &&
            "bg-teal-600 text-white hover:bg-teal-700 shadow-lg hover:shadow-xl hover:shadow-teal-500/25",
          !@popular &&
            "bg-slate-100 dark:bg-slate-700 text-slate-900 dark:text-white hover:bg-slate-200 dark:hover:bg-slate-600"
        ]}
      >
        <%= @cta_text %>
      </a>
    </div>
    """
  end

  # ============================================================================
  # PRICING SECTION
  # ============================================================================

  @doc """
  Renders the pricing section with pricing cards.

  ## Examples

      <.pricing_section />
  """
  attr :class, :string, default: nil

  def pricing_section(assigns) do
    ~H"""
    <section
      id="pricing"
      class={[
        "py-24 bg-white dark:bg-slate-900",
        @class
      ]}
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-16">
          <!-- Urgency Badge -->
          <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300 text-sm font-medium mb-4 animate-pulse">
            <.icon name="hero-fire" class="h-4 w-4" />
            <span>Oferta de Lançamento - 3 créditos grátis!</span>
          </div>
          <h2 class="text-4xl sm:text-5xl font-bold text-gray-900 dark:text-white mb-4">
            Planos e Preços
          </h2>
          <p class="text-xl text-gray-600 dark:text-gray-400 max-w-2xl mx-auto">
            Escolha o plano ideal para suas necessidades
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-6xl mx-auto">
          <.pricing_card
            name="Gratuito"
            price="R$ 0"
            period=""
            description="Para conhecer a plataforma"
            features={[
              "3 creditos gratis ao cadastrar",
              "Transcricao automatica de audio",
              "Analise pedagogica BNCC",
              "Deteccao anti-bullying",
              "Historico de aulas"
            ]}
            cta_text="Comecar Gratis"
            cta_link="/register"
          />

          <.pricing_card
            name="Creditos"
            price="R$ 4,90"
            period="/credito"
            description="Pague apenas pelo que usar"
            features={[
              "Compre creditos avulsos",
              "1 credito = 1 analise completa",
              "Sem mensalidade",
              "Creditos nao expiram",
              "Todas as funcionalidades",
              "Suporte por email"
            ]}
            popular={true}
            cta_text="Comprar Creditos"
            cta_link="/register"
          />

          <.pricing_card
            name="Escola"
            price="Sob consulta"
            period=""
            description="Para instituicoes de ensino"
            features={[
              "Creditos em volume",
              "Dashboard de coordenacao",
              "Multiplos professores",
              "Relatorios institucionais",
              "Alertas anti-bullying",
              "Suporte dedicado",
              "Treinamento incluso"
            ]}
            cta_text="Falar com Vendas"
            cta_link="mailto:contato@hellen.ai"
          />
        </div>
        <!-- Money Back Guarantee -->
        <div class="mt-12 text-center">
          <div class="inline-flex items-center gap-3 px-6 py-3 rounded-2xl bg-emerald-50 dark:bg-emerald-900/20 border border-emerald-200 dark:border-emerald-800">
            <.icon name="hero-shield-check" class="h-6 w-6 text-emerald-600 dark:text-emerald-400" />
            <span class="text-emerald-700 dark:text-emerald-300 font-medium">
              Garantia de satisfação - Se não gostar, devolvemos seus créditos
            </span>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # TESTIMONIAL CARD
  # ============================================================================

  @doc """
  Renders a testimonial card.

  ## Examples

      <.testimonial_card
        quote="Incrível ferramenta!"
        author="Maria Silva"
        role="Professora de Matemática"
      />
  """
  attr :quote, :string, required: true
  attr :author, :string, required: true
  attr :role, :string, required: true
  attr :avatar, :string, default: nil
  attr :class, :string, default: nil

  def testimonial_card(assigns) do
    ~H"""
    <div
      class={[
        "bg-white dark:bg-slate-800 rounded-2xl p-8",
        "border border-slate-200/50 dark:border-slate-700/50",
        "hover:shadow-xl hover:shadow-slate-200/50 dark:hover:shadow-slate-900/50 transition-all duration-300",
        @class
      ]}
      data-animate
    >
      <!-- Quote icon -->
      <div class="mb-6">
        <.icon name="hero-chat-bubble-left-right" class="h-10 w-10 text-teal-600 dark:text-teal-400" />
      </div>
      <!-- Stars -->
      <div class="flex items-center gap-0.5 mb-4 text-amber-400">
        <.icon name="hero-star-solid" class="h-5 w-5" />
        <.icon name="hero-star-solid" class="h-5 w-5" />
        <.icon name="hero-star-solid" class="h-5 w-5" />
        <.icon name="hero-star-solid" class="h-5 w-5" />
        <.icon name="hero-star-solid" class="h-5 w-5" />
      </div>
      <!-- Quote -->
      <blockquote class="text-lg text-slate-700 dark:text-slate-300 mb-6 leading-relaxed">
        "<%= @quote %>"
      </blockquote>
      <!-- Author -->
      <div class="flex items-center">
        <div
          :if={@avatar}
          class="w-12 h-12 rounded-full bg-gradient-to-br from-teal-400 to-cyan-400 mr-4"
        />
        <div
          :if={!@avatar}
          class="w-12 h-12 rounded-xl bg-gradient-to-br from-teal-500 to-cyan-500 flex items-center justify-center text-white font-bold text-lg mr-4 shadow-lg"
        >
          <%= String.first(@author) %>
        </div>
        <div>
          <div class="font-semibold text-slate-900 dark:text-white">
            <%= @author %>
          </div>
          <div class="text-sm text-slate-600 dark:text-slate-400">
            <%= @role %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # TESTIMONIALS SECTION
  # ============================================================================

  @doc """
  Renders the testimonials section.

  ## Examples

      <.testimonials_section />
  """
  attr :class, :string, default: nil

  def testimonials_section(assigns) do
    ~H"""
    <section
      id="testimonials"
      class={[
        "py-24 bg-gray-50 dark:bg-slate-950",
        @class
      ]}
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-16">
          <h2 class="text-4xl sm:text-5xl font-bold text-gray-900 dark:text-white mb-4">
            O que dizem os professores
          </h2>
          <p class="text-xl text-gray-600 dark:text-gray-400 max-w-2xl mx-auto">
            Depoimentos de educadores que transformaram suas aulas
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
          <.testimonial_card
            quote="A Hellen AI revolucionou minha forma de ensinar. Agora consigo identificar pontos de melhoria que antes passavam despercebidos. Recomendo para todos os colegas!"
            author="Maria Silva"
            role="Professora de Matemática - 5º ano"
          />

          <.testimonial_card
            quote="A análise baseada na BNCC me ajuda a garantir que estou cumprindo todos os objetivos de aprendizagem. O feedback é preciso e muito útil para meu planejamento."
            author="João Santos"
            role="Professor de Ciências - 8º ano"
          />

          <.testimonial_card
            quote="Como coordenadora, consigo acompanhar o desenvolvimento dos professores e oferecer suporte direcionado. A plataforma é intuitiva e os relatórios são excelentes."
            author="Ana Paula Costa"
            role="Coordenadora Pedagógica"
          />
        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # FAQ SECTION
  # ============================================================================

  @doc """
  Renders the FAQ section.

  ## Examples

      <.faq_section />
  """
  attr :class, :string, default: nil

  def faq_section(assigns) do
    faqs = [
      %{
        question: "Como funciona a análise de aulas?",
        answer:
          "Você envia um áudio ou vídeo da sua aula, nossa IA transcreve automaticamente e analisa o conteúdo com base na BNCC e Lei 13.185. Em menos de 5 minutos você recebe um relatório completo com pontuação, pontos fortes, sugestões de melhoria e competências identificadas."
      },
      %{
        question: "Preciso pagar mensalidade?",
        answer:
          "Não! Trabalhamos com sistema de créditos. Você compra créditos quando precisar e eles nunca expiram. 1 crédito = 1 análise completa. Ao se cadastrar você ganha 3 créditos grátis para experimentar."
      },
      %{
        question: "Meus dados estão seguros?",
        answer:
          "Sim! Utilizamos criptografia de ponta a ponta e seguimos rigorosamente a LGPD. Seus áudios são processados e depois automaticamente excluídos. Apenas os relatórios ficam salvos na sua conta."
      },
      %{
        question: "Funciona com qualquer disciplina?",
        answer:
          "Sim! A Hellen AI funciona com todas as disciplinas e níveis de ensino. Nossa IA foi treinada com base na BNCC completa, abrangendo desde a Educação Infantil até o Ensino Médio."
      },
      %{
        question: "Posso usar em reuniões pedagógicas?",
        answer:
          "Com certeza! Muitos coordenadores usam para analisar aulas observadas. O plano Escola inclui dashboard de coordenação com visão consolidada de todos os professores."
      },
      %{
        question: "E se eu não gostar do serviço?",
        answer:
          "Oferecemos garantia de satisfação. Se você não ficar satisfeito com a análise, devolvemos seus créditos. Simples assim."
      }
    ]

    assigns = assign(assigns, :faqs, faqs)

    ~H"""
    <section
      id="faq"
      class={[
        "py-24 bg-slate-50 dark:bg-slate-950",
        @class
      ]}
    >
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-16">
          <div class="inline-flex items-center px-3 py-1 rounded-full bg-teal-100 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300 text-sm font-medium mb-4">
            Dúvidas Frequentes
          </div>
          <h2 class="text-4xl sm:text-5xl font-bold text-slate-900 dark:text-white mb-4 tracking-tight">
            Perguntas Frequentes
          </h2>
          <p class="text-xl text-slate-600 dark:text-slate-400">
            Tire suas dúvidas sobre a plataforma
          </p>
        </div>

        <div class="space-y-4">
          <%= for faq <- @faqs do %>
            <div
              class="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 overflow-hidden"
              data-animate
            >
              <details class="group">
                <summary class="flex items-center justify-between p-6 cursor-pointer list-none">
                  <h3 class="text-lg font-semibold text-slate-900 dark:text-white pr-4">
                    <%= faq.question %>
                  </h3>
                  <div class="flex-shrink-0 w-8 h-8 rounded-full bg-teal-100 dark:bg-teal-900/30 flex items-center justify-center text-teal-600 dark:text-teal-400 group-open:rotate-180 transition-transform duration-200">
                    <.icon name="hero-chevron-down" class="h-5 w-5" />
                  </div>
                </summary>
                <div class="px-6 pb-6 pt-0">
                  <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                    <%= faq.answer %>
                  </p>
                </div>
              </details>
            </div>
          <% end %>
        </div>

        <div class="mt-12 text-center">
          <p class="text-slate-600 dark:text-slate-400 mb-4">
            Ainda tem dúvidas?
          </p>
          <a
            href="https://wa.me/5515997701743"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-2 px-6 py-3 text-white bg-green-600 hover:bg-green-700 rounded-xl font-semibold transition-all duration-200 shadow-lg hover:shadow-xl"
          >
            <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
            </svg>
            Falar pelo WhatsApp
          </a>
        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # CTA SECTION
  # ============================================================================

  @doc """
  Renders the final call-to-action section.

  ## Examples

      <.cta_section />
  """
  attr :class, :string, default: nil

  def cta_section(assigns) do
    ~H"""
    <section class={[
      "py-24 bg-gradient-to-br from-teal-600 to-cyan-600 dark:from-teal-900 dark:to-cyan-900 relative overflow-hidden",
      @class
    ]}>
      <!-- Background pattern -->
      <div class="absolute inset-0 opacity-10">
        <div class="absolute top-0 left-0 w-96 h-96 bg-white rounded-full blur-3xl" />
        <div class="absolute bottom-0 right-0 w-96 h-96 bg-white rounded-full blur-3xl" />
      </div>
      <!-- Grid pattern -->
      <div class="absolute inset-0 bg-[linear-gradient(to_right,#fff1_1px,transparent_1px),linear-gradient(to_bottom,#fff1_1px,transparent_1px)] bg-[size:4rem_4rem]" />

      <div class="relative max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <div class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/20 backdrop-blur-sm mb-6">
          <span class="relative flex h-2 w-2">
            <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-white opacity-75">
            </span>
            <span class="relative inline-flex rounded-full h-2 w-2 bg-white"></span>
          </span>
          <span class="text-sm font-medium text-white">Comece agora, é grátis!</span>
        </div>

        <h2 class="text-4xl sm:text-5xl font-bold text-white mb-6 tracking-tight">
          Pronto para transformar suas aulas?
        </h2>
        <p class="text-xl text-teal-100 mb-10 max-w-2xl mx-auto">
          Junte-se a centenas de professores que já estão melhorando suas práticas pedagógicas com a Hellen AI.
        </p>

        <div class="flex flex-col sm:flex-row gap-4 justify-center items-center">
          <a
            href="/register"
            class="group inline-flex items-center justify-center px-8 py-4 text-lg font-semibold text-teal-600 bg-white hover:bg-slate-50 rounded-xl transition-all duration-200 shadow-xl hover:shadow-2xl hover:scale-105 w-full sm:w-auto"
          >
            Criar Conta Gratuita
            <.icon
              name="hero-arrow-right"
              class="ml-2 h-5 w-5 group-hover:translate-x-1 transition-transform"
            />
          </a>

          <a
            href="#contact"
            class="inline-flex items-center justify-center px-8 py-4 text-lg font-semibold text-white bg-white/10 hover:bg-white/20 backdrop-blur-sm border-2 border-white/30 rounded-xl transition-all duration-200 w-full sm:w-auto"
          >
            <.icon name="hero-chat-bubble-left-right" class="mr-2 h-5 w-5" /> Falar com Vendas
          </a>
        </div>

        <div class="mt-8 flex flex-wrap justify-center gap-4 text-sm text-teal-100">
          <span class="flex items-center gap-1.5">
            <.icon name="hero-check-circle" class="h-5 w-5 text-white" /> Sem cartão de crédito
          </span>
          <span class="flex items-center gap-1.5">
            <.icon name="hero-check-circle" class="h-5 w-5 text-white" /> 3 créditos grátis
          </span>
          <span class="flex items-center gap-1.5">
            <.icon name="hero-check-circle" class="h-5 w-5 text-white" /> Pague apenas pelo que usar
          </span>
        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # FOOTER
  # ============================================================================

  @doc """
  Renders the landing page footer.

  ## Examples

      <.landing_footer />
  """
  attr :class, :string, default: nil

  def landing_footer(assigns) do
    ~H"""
    <footer
      id="contact"
      class={[
        "bg-slate-900 dark:bg-slate-950 text-slate-300 py-10 sm:py-12",
        @class
      ]}
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-4 gap-8 mb-8">
          <!-- Logo & Description -->
          <div class="col-span-2">
            <div class="flex items-center mb-4">
              <span class="text-xl sm:text-2xl font-bold bg-gradient-to-r from-teal-400 to-cyan-400 bg-clip-text text-transparent">
                Hellen
              </span>
              <span class="ml-1.5 text-xs font-semibold text-slate-400">
                AI
              </span>
            </div>
            <p class="text-sm sm:text-base text-slate-400 max-w-md mb-6">
              Análise pedagógica inteligente para professores que buscam excelência. Baseado na BNCC e Lei 13.185.
            </p>
            <div class="flex gap-4">
              <a
                href="mailto:contato@hellen.ai"
                class="w-10 h-10 rounded-xl bg-slate-800 hover:bg-teal-600 flex items-center justify-center text-slate-400 hover:text-white transition-all duration-200"
                title="Email"
              >
                <.icon name="hero-envelope" class="h-5 w-5" />
              </a>
            </div>
          </div>
          <!-- Links -->
          <div>
            <h3 class="text-white font-semibold mb-3 sm:mb-4 text-sm sm:text-base">Plataforma</h3>
            <ul class="space-y-1.5 sm:space-y-2">
              <li>
                <a
                  href="#features"
                  class="text-sm text-slate-400 hover:text-teal-400 transition-colors"
                >
                  Recursos
                </a>
              </li>
              <li>
                <a
                  href="#pricing"
                  class="text-sm text-slate-400 hover:text-teal-400 transition-colors"
                >
                  Precos
                </a>
              </li>
              <li>
                <a
                  href="#testimonials"
                  class="text-sm text-slate-400 hover:text-teal-400 transition-colors"
                >
                  Depoimentos
                </a>
              </li>
              <li>
                <a
                  href="/register"
                  class="text-sm text-slate-400 hover:text-teal-400 transition-colors"
                >
                  Criar Conta
                </a>
              </li>
            </ul>
          </div>
          <!-- Contato -->
          <div>
            <h3 class="text-white font-semibold mb-3 sm:mb-4 text-sm sm:text-base">Contato</h3>
            <ul class="space-y-1.5 sm:space-y-2">
              <li>
                <a
                  href="/support"
                  class="text-sm text-slate-400 hover:text-teal-400 transition-colors"
                >
                  Suporte
                </a>
              </li>
              <li>
                <a
                  href="mailto:contato@hellen.ai"
                  class="text-sm text-slate-400 hover:text-teal-400 transition-colors"
                >
                  contato@hellen.ai
                </a>
              </li>
              <li>
                <a
                  href="https://wa.me/5515997701743"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-sm text-slate-400 hover:text-green-400 transition-colors flex items-center gap-1.5"
                >
                  <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
                  </svg>
                  WhatsApp
                </a>
              </li>
            </ul>
          </div>
        </div>
        <!-- Bottom bar -->
        <div class="pt-6 sm:pt-8 border-t border-slate-800">
          <div class="flex flex-col sm:flex-row justify-between items-center gap-4">
            <p class="text-xs sm:text-sm text-slate-400 text-center sm:text-left">
              © 2025 Hellen AI. Todos os direitos reservados.
            </p>
            <div class="flex items-center gap-4 text-xs sm:text-sm">
              <a href="/terms" class="text-slate-400 hover:text-teal-400 transition-colors">
                Termos de Uso
              </a>
              <a href="/privacy" class="text-slate-400 hover:text-teal-400 transition-colors">
                Privacidade
              </a>
              <a href="/support" class="text-slate-400 hover:text-teal-400 transition-colors">
                Suporte
              </a>
            </div>
          </div>
        </div>
      </div>
    </footer>
    """
  end
end
