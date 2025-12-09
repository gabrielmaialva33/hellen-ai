defmodule HellenWeb.Sidebar do
  @moduledoc """
  Sidebar navigation component for the app layout.
  Modern 2025 design with:
  - Teal/Sage color palette
  - Collapsible sidebar (desktop)
  - Drawer sidebar (mobile)
  - Global search shortcut (Cmd+K)
  - User profile section
  - Theme toggle
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  import HellenWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: HellenWeb.Endpoint,
    router: HellenWeb.Router,
    statics: HellenWeb.static_paths()

  attr :current_user, :map, required: true
  attr :current_path, :string, default: "/"
  attr :collapsed, :boolean, default: false

  slot :notification_bell

  def sidebar(assigns) do
    ~H"""
    <!-- Mobile Menu Button -->
    <div class="lg:hidden fixed top-4 left-4 z-50">
      <button
        type="button"
        phx-click={show_mobile_menu()}
        class="p-2.5 rounded-xl bg-white dark:bg-slate-800 shadow-card border border-slate-200/50 dark:border-slate-700/50 hover:shadow-elevated transition-all duration-200"
      >
        <.icon name="hero-bars-3" class="h-5 w-5 text-slate-600 dark:text-slate-300" />
      </button>
    </div>
    <!-- Mobile Overlay -->
    <div
      id="sidebar-overlay"
      class="hidden lg:hidden fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-40"
      phx-click={hide_mobile_menu()}
    >
    </div>
    <!-- Sidebar -->
    <aside
      id="sidebar"
      phx-hook="SidebarHook"
      class="fixed inset-y-0 left-0 z-50 w-64 bg-white dark:bg-slate-900 border-r border-slate-200 dark:border-slate-800 transform -translate-x-full lg:translate-x-0 transition-all duration-300 ease-out flex flex-col shadow-xl lg:shadow-none"
    >
      <!-- Logo Section -->
      <div class="h-16 flex items-center justify-between px-5 border-b border-slate-200 dark:border-slate-800">
        <a href="/dashboard" class="flex items-center group">
          <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-teal-500 to-teal-600 flex items-center justify-center shadow-sm group-hover:shadow-glow-teal transition-shadow duration-300">
            <span class="text-white font-bold text-sm">H</span>
          </div>
          <span class="ml-2.5 text-lg font-bold text-slate-900 dark:text-white">
            Hellen
          </span>
          <span class="ml-1 text-[10px] font-semibold px-1.5 py-0.5 rounded bg-teal-500/10 text-teal-600 dark:text-teal-400">
            AI
          </span>
        </a>
        <!-- Mobile close button -->
        <button
          type="button"
          phx-click={hide_mobile_menu()}
          class="lg:hidden p-1.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <.icon name="hero-x-mark" class="h-5 w-5 text-slate-500 dark:text-slate-400" />
        </button>
      </div>
      <!-- Search Button (Cmd+K) -->
      <div class="px-4 py-3">
        <button
          type="button"
          phx-click={JS.dispatch("open-search")}
          class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl bg-slate-100/50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700/50 text-sm text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 hover:border-slate-300 dark:hover:border-slate-600 transition-all duration-200 group"
        >
          <.icon name="hero-magnifying-glass" class="h-4 w-4" />
          <span class="flex-1 text-left">Buscar...</span>
          <kbd class="hidden sm:inline-flex items-center gap-1 px-1.5 py-0.5 text-xs font-medium bg-slate-100 dark:bg-slate-700 rounded border border-slate-200 dark:border-slate-600 text-slate-500 dark:text-slate-400 group-hover:border-slate-400 dark:group-hover:border-slate-500 transition-colors">
            <span class="text-[10px]">⌘</span>K
          </kbd>
        </button>
      </div>
      <!-- Navigation -->
      <nav class="flex-1 overflow-y-auto py-2 px-3 scrollbar-thin">
        <!-- Main Menu -->
        <div class="space-y-0.5">
          <p class="px-3 py-2 text-[11px] font-semibold text-slate-500 dark:text-slate-500 uppercase tracking-wider">
            Principal
          </p>
          <.nav_item
            path={~p"/dashboard"}
            icon="hero-squares-2x2"
            label="Dashboard"
            current_path={@current_path}
          />
          <.nav_item
            path={~p"/lessons/new"}
            icon="hero-plus-circle"
            label="Nova Aula"
            current_path={@current_path}
            highlight={true}
          />
          <.nav_item
            path={~p"/aulas"}
            icon="hero-academic-cap"
            label="Minhas Aulas"
            current_path={@current_path}
          />
          <.nav_item
            path={~p"/analytics"}
            icon="hero-chart-bar-square"
            label="Analytics"
            current_path={@current_path}
          />
          <.nav_item
            path={~p"/billing"}
            icon="hero-credit-card"
            label="Creditos"
            current_path={@current_path}
          />
        </div>
        <!-- Ferramentas Pedagogicas -->
        <div class="mt-6 space-y-0.5">
          <p class="px-3 py-2 text-[11px] font-semibold text-slate-500 dark:text-slate-500 uppercase tracking-wider">
            Ferramentas
          </p>
          <.nav_item
            path={~p"/plannings"}
            icon="hero-document-text"
            label="Planejamentos"
            current_path={@current_path}
          />
          <.nav_item
            path={~p"/assessments"}
            icon="hero-clipboard-document-list"
            label="Avaliacoes"
            current_path={@current_path}
          />
          <.nav_item
            path={~p"/reports"}
            icon="hero-chart-bar"
            label="Relatorios"
            current_path={@current_path}
          />
        </div>
        <!-- Coordinator Menu (conditional) -->
        <div :if={coordinator?(@current_user)} class="mt-6 space-y-0.5">
          <p class="px-3 py-2 text-[11px] font-semibold text-slate-500 dark:text-slate-500 uppercase tracking-wider">
            Coordenacao
          </p>
          <.nav_item
            path={~p"/institution"}
            icon="hero-building-office"
            label="Instituicao"
            current_path={@current_path}
          />
          <.nav_item
            path={~p"/institution/teachers"}
            icon="hero-users"
            label="Equipe"
            current_path={@current_path}
          />
          <.nav_item
            path={~p"/alerts"}
            icon="hero-bell-alert"
            label="Alertas"
            current_path={@current_path}
          />
        </div>
        <!-- Admin Menu (conditional) -->
        <div :if={admin?(@current_user)} class="mt-6 space-y-0.5">
          <p class="px-3 py-2 text-[11px] font-semibold text-slate-500 dark:text-slate-500 uppercase tracking-wider">
            Administracao
          </p>
          <.nav_item
            path={~p"/admin"}
            icon="hero-shield-check"
            label="Painel Admin"
            current_path={@current_path}
          />
          <.nav_item
            path={~p"/admin/institutions"}
            icon="hero-building-office-2"
            label="Instituicoes"
            current_path={@current_path}
          />
          <.nav_item
            path={~p"/admin/users"}
            icon="hero-user-group"
            label="Usuarios"
            current_path={@current_path}
          />
          <.nav_item
            path={~p"/admin/health"}
            icon="hero-server-stack"
            label="Sistema"
            current_path={@current_path}
          />
        </div>
      </nav>
      <!-- Credits Display -->
      <div :if={@current_user.credits} class="mx-4 mb-3">
        <div class="p-3 rounded-xl bg-gradient-to-br from-teal-500/10 to-sage-500/10 dark:from-teal-900/20 dark:to-sage-900/20 border border-teal-200/50 dark:border-teal-800/50">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <div class="w-8 h-8 rounded-lg bg-teal-500/20 dark:bg-teal-500/10 flex items-center justify-center">
                <.icon name="hero-bolt" class="h-4 w-4 text-teal-600 dark:text-teal-400" />
              </div>
              <div>
                <p class="text-xs text-slate-500 dark:text-slate-400">Creditos</p>
                <p class="text-sm font-bold text-slate-900 dark:text-white">
                  <%= @current_user.credits %>
                </p>
              </div>
            </div>
            <a
              href="/billing"
              class="px-2.5 py-1 text-xs font-medium text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300 hover:bg-teal-500/10 rounded-lg transition-colors"
            >
              + Comprar
            </a>
          </div>
        </div>
      </div>
      <!-- User Section -->
      <div class="border-t border-slate-200 dark:border-slate-800 p-4">
        <div class="flex items-center gap-3 mb-3">
          <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-teal-500 to-sage-500 flex items-center justify-center text-white font-semibold text-sm shadow-sm">
            <%= String.first(@current_user.name || @current_user.email) |> String.upcase() %>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-semibold text-slate-900 dark:text-white truncate">
              <%= @current_user.name || "Usuario" %>
            </p>
            <p class="text-xs text-slate-500 dark:text-slate-400 truncate flex items-center gap-1">
              <span class={[
                "w-1.5 h-1.5 rounded-full",
                role_color(@current_user.role)
              ]}>
              </span>
              <%= role_label(@current_user.role) %>
            </p>
          </div>
        </div>

        <div class="flex items-center justify-between">
          <!-- Notification Bell (from slot) -->
          <%= render_slot(@notification_bell) %>
          <!-- Settings -->
          <a
            href="/settings"
            class="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors text-slate-500 dark:text-slate-400 hover:text-teal-600 dark:hover:text-teal-400"
            title="Configuracoes"
          >
            <.icon name="hero-cog-6-tooth" class="h-5 w-5" />
          </a>
          <!-- Theme Toggle -->
          <button
            type="button"
            id="sidebar-theme-toggle"
            phx-hook="ThemeToggle"
            class="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors text-slate-500 dark:text-slate-400 hover:text-amber-500 dark:hover:text-amber-400"
            title="Alternar tema"
          >
            <.icon name="hero-moon" class="h-5 w-5 dark:hidden" />
            <.icon name="hero-sun" class="h-5 w-5 hidden dark:block" />
          </button>
          <!-- Logout -->
          <a
            href="/logout"
            class="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors text-slate-500 dark:text-slate-400 hover:text-red-500 dark:hover:text-red-400"
            title="Sair"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="h-5 w-5" />
          </a>
        </div>
      </div>
    </aside>
    """
  end

  attr :path, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :current_path, :string, required: true
  attr :badge, :integer, default: nil
  attr :highlight, :boolean, default: false

  defp nav_item(assigns) do
    is_active = String.starts_with?(assigns.current_path, assigns.path)
    assigns = assign(assigns, :is_active, is_active)

    ~H"""
    <a
      href={@path}
      class={[
        "flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200 group",
        @is_active && "bg-teal-500/10 dark:bg-teal-500/15 text-teal-700 dark:text-teal-300 shadow-sm",
        !@is_active && !@highlight &&
          "text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800/70 hover:text-teal-600 dark:hover:text-teal-400",
        !@is_active && @highlight &&
          "text-teal-600 dark:text-teal-400 hover:bg-teal-500/10 dark:hover:bg-teal-500/15"
      ]}
    >
      <span class={[
        "flex-shrink-0 transition-transform duration-200",
        @is_active && "scale-110"
      ]}>
        <.icon name={@icon} class="h-5 w-5" />
      </span>
      <span class="flex-1"><%= @label %></span>
      <span
        :if={@badge}
        class="px-2 py-0.5 text-xs font-semibold bg-teal-500/20 dark:bg-teal-500/30 text-teal-700 dark:text-teal-300 rounded-full"
      >
        <%= @badge %>
      </span>
      <span :if={@is_active} class="w-1 h-6 rounded-full bg-teal-500"></span>
    </a>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp nav_item_disabled(assigns) do
    ~H"""
    <div class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium text-slate-400 dark:text-slate-600 cursor-not-allowed">
      <.icon name={@icon} class="h-5 w-5" />
      <span class="flex-1"><%= @label %></span>
      <span class="px-1.5 py-0.5 text-[10px] font-medium bg-slate-100 dark:bg-slate-800 text-slate-400 dark:text-slate-600 rounded uppercase tracking-wide">
        soon
      </span>
    </div>
    """
  end

  defp coordinator?(user) do
    user && user.role in ["coordinator", "admin"]
  end

  defp admin?(user) do
    user && user.role == "admin"
  end

  defp role_label("admin"), do: "Administrador"
  defp role_label("coordinator"), do: "Coordenador"
  defp role_label("teacher"), do: "Professor"
  defp role_label(_), do: "Usuario"

  defp role_color("admin"), do: "bg-violet-500"
  defp role_color("coordinator"), do: "bg-teal-500"
  defp role_color("teacher"), do: "bg-sage-500"
  defp role_color(_), do: "bg-slate-400"

  defp show_mobile_menu do
    %JS{}
    |> JS.remove_class("hidden", to: "#sidebar-overlay")
    |> JS.remove_class("-translate-x-full", to: "#sidebar")
  end

  defp hide_mobile_menu do
    %JS{}
    |> JS.add_class("hidden", to: "#sidebar-overlay")
    |> JS.add_class("-translate-x-full", to: "#sidebar")
  end
end
