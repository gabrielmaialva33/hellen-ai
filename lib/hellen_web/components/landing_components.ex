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
      "border-b border-gray-200/50 dark:border-slate-700/50",
      "transition-all duration-300",
      @class
    ]}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-16">
          <!-- Logo -->
          <div class="flex items-center">
            <a href="/" class="flex items-center group">
              <span class="text-2xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 dark:from-indigo-400 dark:to-purple-400 bg-clip-text text-transparent">
                Hellen
              </span>
              <span class="ml-1.5 text-xs font-semibold text-gray-500 dark:text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition-colors">
                AI
              </span>
            </a>
          </div>
          <!-- Navigation Links (Desktop) -->
          <div class="hidden md:flex items-center gap-8">
            <a
              href="#features"
              class="text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors"
            >
              Recursos
            </a>
            <a
              href="#pricing"
              class="text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors"
            >
              Preços
            </a>
            <a
              href="#testimonials"
              class="text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors"
            >
              Depoimentos
            </a>
            <a
              href="#contact"
              class="text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors"
            >
              Contato
            </a>
          </div>
          <!-- Actions -->
          <div class="flex items-center gap-2 sm:gap-3">
            <button
              id="theme-toggle"
              phx-hook="ThemeToggle"
              class="p-2 text-gray-400 dark:text-gray-300 hover:text-gray-600 dark:hover:text-white rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors"
              title="Alternar tema"
            >
              <.icon name="hero-sun" class="h-5 w-5 dark:hidden" />
              <.icon name="hero-moon" class="h-5 w-5 hidden dark:block" />
            </button>

            <a
              href="/login"
              class="hidden md:block text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors px-3 py-2"
            >
              Entrar
            </a>

            <a
              href="/register"
              class="hidden sm:inline-flex items-center justify-center px-4 py-2 text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-700 rounded-lg transition-colors duration-200 shadow-sm hover:shadow-md"
            >
              Criar Conta
            </a>
            <!-- Mobile menu button -->
            <button
              type="button"
              class="md:hidden p-2 text-gray-400 dark:text-gray-300 hover:text-gray-600 dark:hover:text-white rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors"
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
        class="hidden md:hidden bg-white/95 dark:bg-slate-900/95 backdrop-blur-md border-t border-gray-200/50 dark:border-slate-700/50"
      >
        <div class="px-4 py-4 space-y-3">
          <a
            href="#features"
            class="block px-3 py-2 text-base font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-gray-50 dark:hover:bg-slate-800 rounded-lg transition-colors"
            phx-click={JS.hide(to: "#mobile-menu")}
          >
            Recursos
          </a>
          <a
            href="#pricing"
            class="block px-3 py-2 text-base font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-gray-50 dark:hover:bg-slate-800 rounded-lg transition-colors"
            phx-click={JS.hide(to: "#mobile-menu")}
          >
            Preços
          </a>
          <a
            href="#testimonials"
            class="block px-3 py-2 text-base font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-gray-50 dark:hover:bg-slate-800 rounded-lg transition-colors"
            phx-click={JS.hide(to: "#mobile-menu")}
          >
            Depoimentos
          </a>
          <a
            href="#contact"
            class="block px-3 py-2 text-base font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-gray-50 dark:hover:bg-slate-800 rounded-lg transition-colors"
            phx-click={JS.hide(to: "#mobile-menu")}
          >
            Contato
          </a>

          <div class="pt-3 border-t border-gray-200 dark:border-slate-700 space-y-3">
            <a
              href="/login"
              class="block px-3 py-2 text-base font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-gray-50 dark:hover:bg-slate-800 rounded-lg transition-colors"
            >
              Entrar
            </a>
            <a
              href="/register"
              class="block w-full text-center px-4 py-2.5 text-base font-semibold text-white bg-indigo-600 hover:bg-indigo-700 rounded-lg transition-colors duration-200"
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
      "bg-gradient-to-br from-gray-50 via-indigo-50/30 to-purple-50/20",
      "dark:from-slate-900 dark:via-indigo-950/30 dark:to-purple-950/20",
      "pt-16",
      @class
    ]}>
      <!-- Animated background orbs -->
      <div class="absolute inset-0 overflow-hidden pointer-events-none">
        <div class="absolute top-1/4 left-1/4 w-96 h-96 bg-indigo-400/20 dark:bg-indigo-500/10 rounded-full blur-3xl animate-float" />
        <div class="absolute bottom-1/4 right-1/4 w-96 h-96 bg-purple-400/20 dark:bg-purple-500/10 rounded-full blur-3xl animate-float-delayed" />
        <div class="absolute top-1/2 left-1/2 w-96 h-96 bg-pink-400/10 dark:bg-pink-500/5 rounded-full blur-3xl animate-pulse-glow" />
      </div>

      <div class="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-24 lg:py-32">
        <div class="text-center max-w-4xl mx-auto">
          <!-- Badge -->
          <div class="inline-flex items-center px-3 sm:px-4 py-1.5 rounded-full bg-indigo-100/80 dark:bg-indigo-900/30 backdrop-blur-sm mb-6 sm:mb-8 animate-fade-in-up">
            <span class="text-xs sm:text-sm font-semibold text-indigo-600 dark:text-indigo-400">
              Feedback pedagógico com IA
            </span>
          </div>
          <!-- Headline -->
          <h1 class="text-3xl sm:text-5xl lg:text-6xl xl:text-7xl font-bold text-gray-900 dark:text-white mb-4 sm:mb-6 animate-fade-in-up leading-tight">
            Transforme suas aulas com
            <span class="bg-gradient-to-r from-indigo-600 to-purple-600 dark:from-indigo-400 dark:to-purple-400 bg-clip-text text-transparent">
              feedback inteligente
            </span>
          </h1>
          <!-- Subtitle -->
          <p class="text-base sm:text-xl lg:text-2xl text-gray-600 dark:text-gray-300 mb-8 sm:mb-12 max-w-3xl mx-auto animate-fade-in-up leading-relaxed px-2">
            Analise gravações de aulas automaticamente com base na <strong>BNCC</strong>
            e <strong>Lei 13.185</strong>. Receba insights pedagógicos em minutos.
          </p>
          <!-- CTAs -->
          <div class="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center items-center mb-10 sm:mb-16 animate-fade-in-up px-4 sm:px-0">
            <a
              href="/register"
              class="inline-flex items-center justify-center px-6 sm:px-8 py-3.5 sm:py-4 text-base font-semibold text-white bg-indigo-600 hover:bg-indigo-700 rounded-xl transition-all duration-200 shadow-lg hover:shadow-xl hover:scale-105 w-full sm:w-auto"
            >
              Comece Grátis <.icon name="hero-arrow-right" class="ml-2 h-5 w-5" />
            </a>

            <a
              href="#features"
              class="inline-flex items-center justify-center px-6 sm:px-8 py-3.5 sm:py-4 text-base font-semibold text-indigo-600 dark:text-indigo-400 bg-white dark:bg-slate-800 hover:bg-gray-50 dark:hover:bg-slate-700 border-2 border-indigo-200 dark:border-indigo-800 rounded-xl transition-all duration-200 w-full sm:w-auto"
            >
              <.icon name="hero-sparkles" class="mr-2 h-5 w-5" /> Ver Recursos
            </a>
          </div>
          <!-- Social Proof -->
          <div class="flex items-center justify-center gap-2 text-sm text-gray-600 dark:text-gray-400 animate-fade-in-up">
            <div class="flex -space-x-1">
              <div
                :for={_ <- 1..5}
                class="w-5 h-5 rounded-full bg-gradient-to-br from-yellow-400 to-yellow-500 border-2 border-white dark:border-slate-900"
              />
            </div>
            <span class="ml-2 font-medium">
              <strong class="text-gray-900 dark:text-white">500+</strong> professores confiam em nós
            </span>
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
    <section class={[
      "py-24 bg-white dark:bg-slate-900",
      @class
    ]}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-16">
          <h2 class="text-4xl sm:text-5xl font-bold text-gray-900 dark:text-white mb-4">
            Como funciona
          </h2>
          <p class="text-xl text-gray-600 dark:text-gray-400 max-w-2xl mx-auto">
            Análise pedagógica em 4 passos simples
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          <!-- Step 1 -->
          <div class="relative group">
            <div class="text-center">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-indigo-100 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400 mb-4 group-hover:scale-110 transition-transform duration-200">
                <.icon name="hero-cloud-arrow-up" class="h-8 w-8" />
              </div>
              <div class="absolute top-8 left-full w-full h-0.5 bg-gradient-to-r from-indigo-200 to-transparent dark:from-indigo-800 hidden lg:block" />
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                1. Upload
              </h3>
              <p class="text-gray-600 dark:text-gray-400 text-sm">
                Envie sua gravação de áudio ou vídeo
              </p>
            </div>
          </div>
          <!-- Step 2 -->
          <div class="relative group">
            <div class="text-center">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400 mb-4 group-hover:scale-110 transition-transform duration-200">
                <.icon name="hero-document-text" class="h-8 w-8" />
              </div>
              <div class="absolute top-8 left-full w-full h-0.5 bg-gradient-to-r from-purple-200 to-transparent dark:from-purple-800 hidden lg:block" />
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                2. Transcrição
              </h3>
              <p class="text-gray-600 dark:text-gray-400 text-sm">
                IA transcreve automaticamente o conteúdo
              </p>
            </div>
          </div>
          <!-- Step 3 -->
          <div class="relative group">
            <div class="text-center">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400 mb-4 group-hover:scale-110 transition-transform duration-200">
                <.icon name="hero-academic-cap" class="h-8 w-8" />
              </div>
              <div class="absolute top-8 left-full w-full h-0.5 bg-gradient-to-r from-green-200 to-transparent dark:from-green-800 hidden lg:block" />
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                3. Análise
              </h3>
              <p class="text-gray-600 dark:text-gray-400 text-sm">
                Avaliação pedagógica baseada na BNCC
              </p>
            </div>
          </div>
          <!-- Step 4 -->
          <div class="relative group">
            <div class="text-center">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-yellow-100 dark:bg-yellow-900/30 text-yellow-600 dark:text-yellow-400 mb-4 group-hover:scale-110 transition-transform duration-200">
                <.icon name="hero-light-bulb" class="h-8 w-8" />
              </div>
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                4. Plano de Ação
              </h3>
              <p class="text-gray-600 dark:text-gray-400 text-sm">
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
    <div class={[
      "group relative bg-white dark:bg-slate-800 rounded-xl sm:rounded-2xl p-5 sm:p-8",
      "border border-gray-200 dark:border-slate-700 sm:border-2",
      "hover:border-transparent hover:shadow-xl",
      "transition-all duration-300",
      "overflow-hidden",
      @class
    ]}>
      <!-- Colored bottom border on hover -->
      <div class={[
        "absolute bottom-0 left-0 right-0 h-1 transform scale-x-0 group-hover:scale-x-100 transition-transform duration-300",
        feature_color_border(@color)
      ]} />
      <!-- Icon -->
      <div class={[
        "inline-flex items-center justify-center w-12 h-12 sm:w-14 sm:h-14 rounded-lg sm:rounded-xl mb-4 sm:mb-6",
        feature_color_bg(@color)
      ]}>
        <.icon name={@icon} class={"h-6 w-6 sm:h-7 sm:w-7 #{feature_color_text(@color)}"} />
      </div>
      <!-- Content -->
      <h3 class="text-lg sm:text-xl font-semibold text-gray-900 dark:text-white mb-2 sm:mb-3">
        <%= @title %>
      </h3>
      <p class="text-sm sm:text-base text-gray-600 dark:text-gray-400 mb-4 sm:mb-6">
        <%= @description %>
      </p>
      <!-- Stats -->
      <div :if={@stat} class="pt-4 sm:pt-6 border-t border-gray-200 dark:border-slate-700">
        <div class={["text-2xl sm:text-3xl font-bold mb-1", feature_color_text(@color)]}>
          <%= @stat %>
        </div>
        <div class="text-xs sm:text-sm text-gray-500 dark:text-gray-400">
          <%= @stat_label %>
        </div>
      </div>
    </div>
    """
  end

  defp feature_color_bg("blue"), do: "bg-blue-100 dark:bg-blue-900/30"
  defp feature_color_bg("green"), do: "bg-green-100 dark:bg-green-900/30"
  defp feature_color_bg("yellow"), do: "bg-yellow-100 dark:bg-yellow-900/30"
  defp feature_color_bg("red"), do: "bg-red-100 dark:bg-red-900/30"
  defp feature_color_bg("purple"), do: "bg-purple-100 dark:bg-purple-900/30"

  defp feature_color_text("blue"), do: "text-blue-600 dark:text-blue-400"
  defp feature_color_text("green"), do: "text-green-600 dark:text-green-400"
  defp feature_color_text("yellow"), do: "text-yellow-600 dark:text-yellow-400"
  defp feature_color_text("red"), do: "text-red-600 dark:text-red-400"
  defp feature_color_text("purple"), do: "text-purple-600 dark:text-purple-400"

  defp feature_color_border("blue"), do: "bg-gradient-to-r from-blue-500 to-blue-600"
  defp feature_color_border("green"), do: "bg-gradient-to-r from-green-500 to-green-600"
  defp feature_color_border("yellow"), do: "bg-gradient-to-r from-yellow-500 to-yellow-600"
  defp feature_color_border("red"), do: "bg-gradient-to-r from-red-500 to-red-600"
  defp feature_color_border("purple"), do: "bg-gradient-to-r from-purple-500 to-purple-600"

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
    <div class={[
      "relative bg-white dark:bg-slate-800 rounded-2xl p-8",
      "border-2",
      @popular && "border-indigo-500 shadow-xl scale-105",
      !@popular && "border-gray-200 dark:border-slate-700",
      "transition-all duration-300 hover:shadow-lg",
      @class
    ]}>
      <!-- Popular badge -->
      <div :if={@popular} class="absolute -top-4 left-1/2 -translate-x-1/2">
        <span class="inline-flex items-center px-4 py-1 rounded-full bg-gradient-to-r from-indigo-600 to-purple-600 text-white text-sm font-semibold shadow-lg">
          Mais Popular
        </span>
      </div>
      <!-- Plan name -->
      <h3 class="text-2xl font-bold text-gray-900 dark:text-white mb-2">
        <%= @name %>
      </h3>
      <!-- Description -->
      <p class="text-gray-600 dark:text-gray-400 mb-6">
        <%= @description %>
      </p>
      <!-- Price -->
      <div class="mb-8">
        <div class="flex items-baseline">
          <span class="text-5xl font-bold text-gray-900 dark:text-white">
            <%= @price %>
          </span>
          <span class="ml-2 text-gray-600 dark:text-gray-400">
            <%= @period %>
          </span>
        </div>
      </div>
      <!-- Features -->
      <ul class="space-y-4 mb-8">
        <li :for={feature <- @features} class="flex items-start">
          <.icon
            name="hero-check-circle"
            class="h-6 w-6 text-green-500 dark:text-green-400 mr-3 flex-shrink-0"
          />
          <span class="text-gray-700 dark:text-gray-300">
            <%= feature %>
          </span>
        </li>
      </ul>
      <!-- CTA -->
      <a
        href={@cta_link}
        class={[
          "block w-full text-center px-6 py-3 rounded-lg font-semibold transition-all duration-200",
          @popular &&
            "bg-indigo-600 text-white hover:bg-indigo-700 shadow-lg hover:shadow-xl",
          !@popular &&
            "bg-gray-100 dark:bg-slate-700 text-gray-900 dark:text-white hover:bg-gray-200 dark:hover:bg-slate-600"
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
    <div class={[
      "bg-white dark:bg-slate-800 rounded-2xl p-8",
      "border border-gray-200 dark:border-slate-700",
      "hover:shadow-xl transition-all duration-300",
      @class
    ]}>
      <!-- Quote icon -->
      <div class="mb-6">
        <.icon
          name="hero-chat-bubble-left-right"
          class="h-10 w-10 text-indigo-600 dark:text-indigo-400"
        />
      </div>
      <!-- Quote -->
      <blockquote class="text-lg text-gray-700 dark:text-gray-300 mb-6 leading-relaxed">
        "<%= @quote %>"
      </blockquote>
      <!-- Author -->
      <div class="flex items-center">
        <div
          :if={@avatar}
          class="w-12 h-12 rounded-full bg-gradient-to-br from-indigo-400 to-purple-400 mr-4"
        />
        <div
          :if={!@avatar}
          class="w-12 h-12 rounded-full bg-gradient-to-br from-indigo-400 to-purple-400 flex items-center justify-center text-white font-bold text-lg mr-4"
        >
          <%= String.first(@author) %>
        </div>
        <div>
          <div class="font-semibold text-gray-900 dark:text-white">
            <%= @author %>
          </div>
          <div class="text-sm text-gray-600 dark:text-gray-400">
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
      "py-24 bg-gradient-to-br from-indigo-600 to-purple-700 dark:from-indigo-900 dark:to-purple-900 relative overflow-hidden",
      @class
    ]}>
      <!-- Background pattern -->
      <div class="absolute inset-0 opacity-10">
        <div class="absolute top-0 left-0 w-96 h-96 bg-white rounded-full blur-3xl" />
        <div class="absolute bottom-0 right-0 w-96 h-96 bg-white rounded-full blur-3xl" />
      </div>

      <div class="relative max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h2 class="text-4xl sm:text-5xl font-bold text-white mb-6">
          Pronto para transformar suas aulas?
        </h2>
        <p class="text-xl text-indigo-100 mb-10 max-w-2xl mx-auto">
          Junte-se a centenas de professores que já estão melhorando suas práticas pedagógicas com a Hellen AI.
        </p>

        <div class="flex flex-col sm:flex-row gap-4 justify-center items-center">
          <a
            href="/register"
            class="inline-flex items-center justify-center px-8 py-4 text-lg font-semibold text-indigo-600 bg-white hover:bg-gray-100 rounded-xl transition-all duration-200 shadow-xl hover:shadow-2xl hover:scale-105 w-full sm:w-auto"
          >
            Criar Conta Gratuita <.icon name="hero-arrow-right" class="ml-2 h-5 w-5" />
          </a>

          <a
            href="#contact"
            class="inline-flex items-center justify-center px-8 py-4 text-lg font-semibold text-white bg-indigo-700 hover:bg-indigo-800 border-2 border-white/20 rounded-xl transition-all duration-200 w-full sm:w-auto"
          >
            Falar com Vendas
          </a>
        </div>

        <p class="mt-6 text-sm text-indigo-100">
          Sem cartao de credito para comecar • 3 creditos gratis • Pague apenas pelo que usar
        </p>
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
        "bg-gray-900 dark:bg-slate-950 text-gray-300 py-10 sm:py-12",
        @class
      ]}
    >
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-4 gap-8 mb-8">
          <!-- Logo & Description -->
          <div class="col-span-2">
            <div class="flex items-center mb-4">
              <span class="text-xl sm:text-2xl font-bold bg-gradient-to-r from-indigo-400 to-purple-400 bg-clip-text text-transparent">
                Hellen
              </span>
              <span class="ml-1.5 text-xs font-semibold text-gray-400">
                AI
              </span>
            </div>
            <p class="text-sm sm:text-base text-gray-400 max-w-md mb-6">
              Análise pedagógica inteligente para professores que buscam excelência. Baseado na BNCC e Lei 13.185.
            </p>
            <div class="flex gap-4">
              <a
                href="mailto:contato@hellen.ai"
                class="text-gray-400 hover:text-white transition-colors"
                title="Email"
              >
                <svg
                  class="h-5 w-5 sm:h-6 sm:w-6"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                  />
                </svg>
              </a>
            </div>
          </div>
          <!-- Links -->
          <div>
            <h3 class="text-white font-semibold mb-3 sm:mb-4 text-sm sm:text-base">Plataforma</h3>
            <ul class="space-y-1.5 sm:space-y-2">
              <li>
                <a href="#features" class="text-sm text-gray-400 hover:text-white transition-colors">
                  Recursos
                </a>
              </li>
              <li>
                <a href="#pricing" class="text-sm text-gray-400 hover:text-white transition-colors">
                  Precos
                </a>
              </li>
              <li>
                <a
                  href="#testimonials"
                  class="text-sm text-gray-400 hover:text-white transition-colors"
                >
                  Depoimentos
                </a>
              </li>
              <li>
                <a href="/register" class="text-sm text-gray-400 hover:text-white transition-colors">
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
                  href="mailto:contato@hellen.ai"
                  class="text-sm text-gray-400 hover:text-white transition-colors"
                >
                  contato@hellen.ai
                </a>
              </li>
              <li>
                <a
                  href="mailto:suporte@hellen.ai"
                  class="text-sm text-gray-400 hover:text-white transition-colors"
                >
                  suporte@hellen.ai
                </a>
              </li>
              <li>
                <span class="text-sm text-gray-500">
                  Brasil
                </span>
              </li>
            </ul>
          </div>
        </div>
        <!-- Bottom bar -->
        <div class="pt-6 sm:pt-8 border-t border-gray-800">
          <div class="flex flex-col sm:flex-row justify-between items-center gap-2">
            <p class="text-xs sm:text-sm text-gray-400 text-center sm:text-left">
              © 2025 Hellen AI. Todos os direitos reservados.
            </p>
            <p class="text-xs sm:text-sm text-gray-400">
              Feito com <span class="text-red-500">♥</span> para educadores
            </p>
          </div>
        </div>
      </div>
    </footer>
    """
  end
end
