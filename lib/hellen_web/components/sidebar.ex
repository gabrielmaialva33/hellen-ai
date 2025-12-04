defmodule HellenWeb.Sidebar do
  @moduledoc """
  Sidebar navigation component for the app layout.
  Includes:
  - Logo and branding
  - Main navigation menu
  - Coordinator-only menu (when applicable)
  - User profile section
  - Theme toggle
  - Mobile hamburger menu
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

  slot :notification_bell

  def sidebar(assigns) do
    ~H"""
    <!-- Mobile Menu Button -->
    <div class="lg:hidden fixed top-4 left-4 z-50">
      <button
        type="button"
        phx-click={show_mobile_menu()}
        class="p-2 rounded-lg bg-white dark:bg-slate-800 shadow-lg border border-gray-200 dark:border-slate-700"
      >
        <.icon name="hero-bars-3" class="h-6 w-6 text-gray-600 dark:text-gray-300" />
      </button>
    </div>
    <!-- Mobile Overlay -->
    <div
      id="sidebar-overlay"
      class="hidden lg:hidden fixed inset-0 bg-black/50 z-40"
      phx-click={hide_mobile_menu()}
    >
    </div>
    <!-- Sidebar -->
    <aside
      id="sidebar"
      class="fixed inset-y-0 left-0 z-50 w-64 bg-white dark:bg-slate-900 border-r border-gray-200 dark:border-slate-700 transform -translate-x-full lg:translate-x-0 transition-transform duration-300 ease-in-out flex flex-col"
    >
      <!-- Logo -->
      <div class="h-16 flex items-center justify-between px-4 border-b border-gray-200 dark:border-slate-700">
        <a href="/dashboard" class="flex items-center">
          <span class="text-xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 dark:from-indigo-400 dark:to-purple-400 bg-clip-text text-transparent">
            Hellen
          </span>
          <span class="ml-1 text-xs font-medium text-gray-500 dark:text-gray-400">AI</span>
        </a>
        <!-- Mobile close button -->
        <button
          type="button"
          phx-click={hide_mobile_menu()}
          class="lg:hidden p-1 rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800"
        >
          <.icon name="hero-x-mark" class="h-5 w-5 text-gray-500 dark:text-gray-400" />
        </button>
      </div>
      <!-- Navigation -->
      <nav class="flex-1 overflow-y-auto py-4 px-3">
        <!-- Main Menu -->
        <div class="space-y-1">
          <p class="px-3 text-xs font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-2">
            Principal
          </p>
          <.nav_item
            path={~p"/dashboard"}
            icon="hero-home"
            label="Inicio"
            current_path={@current_path}
          />
          <.nav_item
            path={~p"/lessons/new"}
            icon="hero-plus-circle"
            label="Nova Aula"
            current_path={@current_path}
          />
          <.nav_item
            path={~p"/aulas"}
            icon="hero-academic-cap"
            label="Minhas Aulas"
            current_path={@current_path}
          />
        </div>
        <!-- Future Features (Disabled) -->
        <div class="mt-6 space-y-1">
          <p class="px-3 text-xs font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-2">
            Em Breve
          </p>
          <.nav_item_disabled icon="hero-document-text" label="Planejamentos" />
          <.nav_item_disabled icon="hero-clipboard-document-list" label="Provas" />
          <.nav_item_disabled icon="hero-chart-bar" label="Relatorios" />
        </div>
        <!-- Coordinator Menu (conditional) -->
        <div :if={coordinator?(@current_user)} class="mt-6 space-y-1">
          <p class="px-3 text-xs font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-2">
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
      </nav>
      <!-- User Section -->
      <div class="border-t border-gray-200 dark:border-slate-700 p-4">
        <div class="flex items-center gap-3 mb-3">
          <div class="w-9 h-9 rounded-full bg-gradient-to-br from-indigo-500 to-purple-500 flex items-center justify-center text-white font-medium text-sm">
            <%= String.first(@current_user.name || @current_user.email) |> String.upcase() %>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
              <%= @current_user.name || "Usuario" %>
            </p>
            <p class="text-xs text-gray-500 dark:text-gray-400 truncate">
              <%= role_label(@current_user.role) %>
            </p>
          </div>
        </div>

        <div class="flex items-center justify-between">
          <!-- Notification Bell (from slot) -->
          <%= render_slot(@notification_bell) %>
          <!-- Theme Toggle -->
          <button
            type="button"
            id="sidebar-theme-toggle"
            phx-hook="ThemeToggle"
            class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors"
            title="Alternar tema"
          >
            <.icon name="hero-moon" class="h-5 w-5 text-gray-500 dark:text-gray-400 dark:hidden" />
            <.icon name="hero-sun" class="h-5 w-5 text-gray-500 dark:text-gray-400 hidden dark:block" />
          </button>
          <!-- Logout -->
          <a
            href="/logout"
            class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors text-gray-500 dark:text-gray-400 hover:text-red-500 dark:hover:text-red-400"
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

  defp nav_item(assigns) do
    is_active = String.starts_with?(assigns.current_path, assigns.path)
    assigns = assign(assigns, :is_active, is_active)

    ~H"""
    <a
      href={@path}
      class={[
        "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
        @is_active &&
          "bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300",
        !@is_active &&
          "text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-slate-800"
      ]}
    >
      <.icon name={@icon} class="h-5 w-5" />
      <span class="flex-1"><%= @label %></span>
      <span
        :if={@badge}
        class="px-2 py-0.5 text-xs font-medium bg-indigo-100 dark:bg-indigo-900/50 text-indigo-600 dark:text-indigo-400 rounded-full"
      >
        <%= @badge %>
      </span>
    </a>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp nav_item_disabled(assigns) do
    ~H"""
    <div class="flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium text-gray-400 dark:text-gray-600 cursor-not-allowed">
      <.icon name={@icon} class="h-5 w-5" />
      <span class="flex-1"><%= @label %></span>
      <span class="px-1.5 py-0.5 text-xs bg-gray-100 dark:bg-slate-800 text-gray-400 dark:text-gray-600 rounded">
        soon
      </span>
    </div>
    """
  end

  defp coordinator?(user) do
    user && user.role in ["coordinator", "admin"]
  end

  defp role_label("admin"), do: "Administrador"
  defp role_label("coordinator"), do: "Coordenador"
  defp role_label("teacher"), do: "Professor"
  defp role_label(_), do: "Usuario"

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
