defmodule HellenWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  Components included:
  - Flash messages
  - Buttons
  - Form inputs
  - Cards
  - Progress bars
  - Badges
  - Alerts
  - Modals
  - Navigation (navbar, sidebar)
  - Icons (Heroicons)
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  import Phoenix.HTML.Form

  # ============================================================================
  # ICONS
  # ============================================================================

  @doc """
  Renders a Heroicon.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  # ============================================================================
  # BUTTONS
  # ============================================================================

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="secondary">Send!</.button>
  """
  attr :type, :string, default: "button"
  attr :variant, :string, default: "primary", values: ~w(primary secondary danger ghost)
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(form name value phx-click phx-disable-with)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class={[
        "inline-flex items-center justify-center font-medium rounded-lg",
        "focus:outline-none focus:ring-2 focus:ring-offset-2",
        "transition-colors duration-200",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        button_size(@size),
        button_variant(@variant),
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp button_size("sm"), do: "px-3 py-1.5 text-sm"
  defp button_size("md"), do: "px-4 py-2 text-sm"
  defp button_size("lg"), do: "px-6 py-3 text-base"

  defp button_variant("primary"),
    do: "bg-indigo-600 text-white hover:bg-indigo-700 focus:ring-indigo-500"

  defp button_variant("secondary"),
    do: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 focus:ring-indigo-500"

  defp button_variant("danger"), do: "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500"
  defp button_variant("ghost"), do: "text-gray-600 hover:bg-gray-100 focus:ring-gray-500"

  # ============================================================================
  # FORM INPUTS
  # ============================================================================

  @doc """
  Renders an input with label and error messages.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div phx-feedback-for={@name}>
      <label class="flex items-center gap-2 text-sm font-medium text-gray-700">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
          {@rest}
        />
        <%= @label %>
      </label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= options_for_select(@options, @value) %>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "mt-1 block w-full rounded-lg border-gray-300 shadow-sm",
          "focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm",
          @errors != [] &&
            "border-red-300 text-red-900 placeholder-red-300 focus:border-red-500 focus:ring-red-500"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-1 block w-full rounded-lg border-gray-300 shadow-sm",
          "focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm",
          @errors != [] &&
            "border-red-300 text-red-900 placeholder-red-300 focus:border-red-500 focus:ring-red-500"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-medium text-gray-700">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-1 flex gap-1 text-sm leading-6 text-red-600 phx-no-feedback:hidden">
      <.icon name="hero-exclamation-circle-mini" class="h-5 w-5 flex-none" />
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  # ============================================================================
  # CARDS
  # ============================================================================

  @doc """
  Renders a card component.

  ## Examples

      <.card>
        <:header>Card Title</:header>
        Card content here
      </.card>
  """
  attr :class, :string, default: nil
  attr :rest, :global

  slot :header
  slot :inner_block, required: true
  slot :footer

  def card(assigns) do
    ~H"""
    <div
      class={["bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden", @class]}
      {@rest}
    >
      <div :if={@header != []} class="px-6 py-4 border-b border-gray-200">
        <%= render_slot(@header) %>
      </div>
      <div class="px-6 py-4">
        <%= render_slot(@inner_block) %>
      </div>
      <div :if={@footer != []} class="px-6 py-4 bg-gray-50 border-t border-gray-200">
        <%= render_slot(@footer) %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # PROGRESS
  # ============================================================================

  @doc """
  Renders a progress bar.

  ## Examples

      <.progress value={50} />
      <.progress value={75} color="green" />
  """
  attr :value, :integer, default: 0
  attr :max, :integer, default: 100
  attr :color, :string, default: "indigo", values: ~w(indigo green red yellow)
  attr :class, :string, default: nil

  def progress(assigns) do
    assigns = assign(assigns, :percentage, min(100, max(0, assigns.value / assigns.max * 100)))

    ~H"""
    <div class={["w-full bg-gray-200 rounded-full h-2.5", @class]}>
      <div
        class={["h-2.5 rounded-full transition-all duration-300", progress_color(@color)]}
        style={"width: #{@percentage}%"}
      >
      </div>
    </div>
    """
  end

  defp progress_color("indigo"), do: "bg-indigo-600"
  defp progress_color("green"), do: "bg-green-600"
  defp progress_color("red"), do: "bg-red-600"
  defp progress_color("yellow"), do: "bg-yellow-500"

  # ============================================================================
  # BADGES
  # ============================================================================

  @doc """
  Renders a status badge.

  ## Examples

      <.badge>Default</.badge>
      <.badge variant="success">Completed</.badge>
      <.badge variant="warning">Processing</.badge>
  """
  attr :variant, :string,
    default: "default",
    values: ~w(default pending processing completed failed success warning error)

  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
        badge_variant(@variant),
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  defp badge_variant("default"), do: "bg-gray-100 text-gray-800"
  defp badge_variant("pending"), do: "bg-gray-100 text-gray-800"
  defp badge_variant("processing"), do: "bg-yellow-100 text-yellow-800"
  defp badge_variant("completed"), do: "bg-green-100 text-green-800"
  defp badge_variant("failed"), do: "bg-red-100 text-red-800"
  defp badge_variant("success"), do: "bg-green-100 text-green-800"
  defp badge_variant("warning"), do: "bg-yellow-100 text-yellow-800"
  defp badge_variant("error"), do: "bg-red-100 text-red-800"

  # ============================================================================
  # ALERTS
  # ============================================================================

  @doc """
  Renders an alert message.

  ## Examples

      <.alert variant="info">Information message</.alert>
      <.alert variant="error" title="Error occurred">Something went wrong</.alert>
  """
  attr :variant, :string, default: "info", values: ~w(info success warning error)
  attr :title, :string, default: nil
  attr :dismissible, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def alert(assigns) do
    ~H"""
    <div
      class={[
        "p-4 rounded-lg mb-4",
        alert_variant(@variant),
        @class
      ]}
      role="alert"
      {@rest}
    >
      <div class="flex">
        <div class="flex-shrink-0">
          <.icon name={alert_icon(@variant)} class="h-5 w-5" />
        </div>
        <div class="ml-3">
          <h3 :if={@title} class="text-sm font-medium"><%= @title %></h3>
          <div class={["text-sm", @title && "mt-2"]}>
            <%= render_slot(@inner_block) %>
          </div>
        </div>
        <button
          :if={@dismissible}
          type="button"
          class="ml-auto -mx-1.5 -my-1.5 p-1.5 rounded-lg hover:bg-black/10"
        >
          <.icon name="hero-x-mark-mini" class="h-5 w-5" />
        </button>
      </div>
    </div>
    """
  end

  defp alert_variant("info"), do: "bg-blue-50 text-blue-800 border border-blue-200"
  defp alert_variant("success"), do: "bg-green-50 text-green-800 border border-green-200"
  defp alert_variant("warning"), do: "bg-yellow-50 text-yellow-800 border border-yellow-200"
  defp alert_variant("error"), do: "bg-red-50 text-red-800 border border-red-200"

  defp alert_icon("info"), do: "hero-information-circle-mini"
  defp alert_icon("success"), do: "hero-check-circle-mini"
  defp alert_icon("warning"), do: "hero-exclamation-triangle-mini"
  defp alert_icon("error"), do: "hero-x-circle-mini"

  # ============================================================================
  # MODALS
  # ============================================================================

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        Are you sure?
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is a modal.
      </.modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-gray-900/50 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-lg p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-lg rounded-xl bg-white p-6 transition"
            >
              <div class="absolute top-4 right-4">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="flex-none p-2 text-gray-400 hover:text-gray-500"
                  aria-label="close"
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                <%= render_slot(@inner_block) %>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # NAVIGATION
  # ============================================================================

  @doc """
  Renders the main navbar.

  ## Examples

      <.navbar current_user={@current_user} />
  """
  attr :current_user, :map, default: nil

  def navbar(assigns) do
    ~H"""
    <nav class="bg-white dark:bg-slate-900 shadow-sm border-b border-gray-200 dark:border-slate-700 transition-colors duration-200">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex items-center">
            <a href={if @current_user, do: "/dashboard", else: "/"} class="flex items-center">
              <span class="text-xl font-bold text-indigo-600 dark:text-indigo-400">Hellen</span>
              <span class="ml-1 text-xs text-gray-500 dark:text-gray-400">AI</span>
            </a>
          </div>

          <div :if={@current_user} class="flex items-center gap-4">
            <a
              href="/lessons/new"
              class="text-gray-600 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white text-sm font-medium"
            >
              Nova Aula
            </a>
            <button
              phx-click={JS.dispatch("click", to: "#theme-wrapper")}
              class="p-2 text-gray-400 dark:text-gray-300 hover:text-gray-500 dark:hover:text-white rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors"
              title="Alternar tema"
            >
              <.icon name="hero-sun" class="h-5 w-5 dark:hidden" />
              <.icon name="hero-moon" class="h-5 w-5 hidden dark:block" />
            </button>
            <div class="flex items-center gap-2">
              <span class="text-sm text-gray-600 dark:text-gray-300">
                <%= @current_user.name || @current_user.email %>
              </span>
              <a
                href="/logout"
                class="text-gray-400 dark:text-gray-300 hover:text-gray-500 dark:hover:text-white"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="h-5 w-5" />
              </a>
            </div>
          </div>

          <div :if={!@current_user} class="flex items-center gap-4">
            <button
              phx-click={JS.dispatch("click", to: "#theme-wrapper")}
              class="p-2 text-gray-400 dark:text-gray-300 hover:text-gray-500 dark:hover:text-white rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors"
              title="Alternar tema"
            >
              <.icon name="hero-sun" class="h-5 w-5 dark:hidden" />
              <.icon name="hero-moon" class="h-5 w-5 hidden dark:block" />
            </button>
            <a
              href="/login"
              class="text-gray-600 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white text-sm font-medium"
            >
              Entrar
            </a>
            <a href="/register" class="btn btn-primary text-sm">
              Criar Conta
            </a>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  @doc """
  Renders the app navbar with modern styling (for logged-in area).

  ## Examples

      <.app_navbar current_user={@current_user} />
  """
  attr :current_user, :map, default: nil

  def app_navbar(assigns) do
    ~H"""
    <nav class="sticky top-0 z-50 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-b border-gray-200/50 dark:border-slate-700/50 transition-all duration-300">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-16">
          <!-- Logo -->
          <div class="flex items-center">
            <a href={if @current_user, do: "/dashboard", else: "/"} class="flex items-center group">
              <span class="text-xl font-bold bg-gradient-to-r from-indigo-600 to-purple-600 dark:from-indigo-400 dark:to-purple-400 bg-clip-text text-transparent">
                Hellen
              </span>
              <span class="ml-1 text-xs font-medium text-gray-500 dark:text-gray-400">AI</span>
            </a>
          </div>
          <!-- Desktop Navigation (logged in) -->
          <div :if={@current_user} class="hidden md:flex items-center gap-6">
            <a
              href="/dashboard"
              class="text-gray-600 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 text-sm font-medium transition-colors"
            >
              Dashboard
            </a>
            <a
              href="/lessons/new"
              class="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold text-white bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 shadow-md shadow-indigo-500/20 hover:shadow-indigo-500/30 transition-all duration-200"
            >
              <.icon name="hero-plus" class="h-4 w-4" /> Nova Aula
            </a>
            <button
              phx-hook="ThemeToggle"
              id="app-theme-toggle"
              class="p-2 text-gray-400 dark:text-gray-300 hover:text-gray-600 dark:hover:text-white rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors"
              title="Alternar tema"
            >
              <.icon name="hero-sun" class="h-5 w-5 dark:hidden" />
              <.icon name="hero-moon" class="h-5 w-5 hidden dark:block" />
            </button>
            <div class="flex items-center gap-3 pl-4 border-l border-gray-200 dark:border-slate-700">
              <div class="w-8 h-8 rounded-full bg-gradient-to-br from-indigo-500 to-purple-500 flex items-center justify-center text-white text-sm font-semibold">
                <%= String.first(@current_user.name || @current_user.email) |> String.upcase() %>
              </div>
              <span class="text-sm font-medium text-gray-700 dark:text-gray-200 hidden lg:block">
                <%= @current_user.name || @current_user.email %>
              </span>
              <a
                href="/logout"
                class="p-2 text-gray-400 dark:text-gray-300 hover:text-red-500 dark:hover:text-red-400 transition-colors"
                title="Sair"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="h-5 w-5" />
              </a>
            </div>
          </div>
          <!-- Mobile menu button -->
          <div :if={@current_user} class="flex md:hidden items-center gap-2">
            <button
              phx-hook="ThemeToggle"
              id="app-theme-toggle-mobile"
              class="p-2 text-gray-400 dark:text-gray-300 hover:text-gray-600 dark:hover:text-white rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors"
              title="Alternar tema"
            >
              <.icon name="hero-sun" class="h-5 w-5 dark:hidden" />
              <.icon name="hero-moon" class="h-5 w-5 hidden dark:block" />
            </button>
            <button
              type="button"
              class="p-2 text-gray-400 dark:text-gray-300 hover:text-gray-600 dark:hover:text-white rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors"
              phx-click={
                JS.toggle(to: "#app-mobile-menu", in: "fade-in-scale", out: "fade-out-scale")
              }
              aria-expanded="false"
              aria-controls="app-mobile-menu"
            >
              <span class="sr-only">Abrir menu</span>
              <.icon name="hero-bars-3" class="h-6 w-6" />
            </button>
          </div>
          <!-- Desktop Navigation (not logged in) -->
          <div :if={!@current_user} class="flex items-center gap-4">
            <button
              phx-hook="ThemeToggle"
              id="app-theme-toggle-guest"
              class="p-2 text-gray-400 dark:text-gray-300 hover:text-gray-500 dark:hover:text-white rounded-lg hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors"
              title="Alternar tema"
            >
              <.icon name="hero-sun" class="h-5 w-5 dark:hidden" />
              <.icon name="hero-moon" class="h-5 w-5 hidden dark:block" />
            </button>
            <a
              href="/login"
              class="text-gray-600 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white text-sm font-medium transition-colors"
            >
              Entrar
            </a>
            <a
              href="/register"
              class="inline-flex items-center px-4 py-2 rounded-xl text-sm font-semibold text-white bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 shadow-md shadow-indigo-500/20 transition-all duration-200"
            >
              Criar Conta
            </a>
          </div>
        </div>
      </div>
      <!-- Mobile menu (logged in) -->
      <div
        :if={@current_user}
        id="app-mobile-menu"
        class="hidden md:hidden bg-white/95 dark:bg-slate-900/95 backdrop-blur-md border-t border-gray-200/50 dark:border-slate-700/50"
      >
        <div class="px-4 py-4 space-y-3">
          <div class="flex items-center gap-3 pb-3 border-b border-gray-200 dark:border-slate-700">
            <div class="w-10 h-10 rounded-full bg-gradient-to-br from-indigo-500 to-purple-500 flex items-center justify-center text-white font-semibold">
              <%= String.first(@current_user.name || @current_user.email) |> String.upcase() %>
            </div>
            <div>
              <p class="text-sm font-medium text-gray-900 dark:text-white">
                <%= @current_user.name || "Usuário" %>
              </p>
              <p class="text-xs text-gray-500 dark:text-gray-400"><%= @current_user.email %></p>
            </div>
          </div>
          <a
            href="/dashboard"
            class="block px-3 py-2 rounded-lg text-base font-medium text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-slate-800 transition-colors"
            phx-click={JS.hide(to: "#app-mobile-menu")}
          >
            <.icon name="hero-home" class="h-5 w-5 inline mr-2" /> Dashboard
          </a>
          <a
            href="/lessons/new"
            class="block px-3 py-2 rounded-lg text-base font-medium text-indigo-600 dark:text-indigo-400 hover:bg-indigo-50 dark:hover:bg-indigo-500/10 transition-colors"
            phx-click={JS.hide(to: "#app-mobile-menu")}
          >
            <.icon name="hero-plus-circle" class="h-5 w-5 inline mr-2" /> Nova Aula
          </a>
          <a
            href="/logout"
            class="block px-3 py-2 rounded-lg text-base font-medium text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-500/10 transition-colors"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="h-5 w-5 inline mr-2" /> Sair
          </a>
        </div>
      </div>
    </nav>
    """
  end

  @doc """
  Renders a sidebar for coordinators.

  ## Examples

      <.sidebar current_path={@current_path}>
        <:item path="/" icon="hero-home">Dashboard</:item>
        <:item path="/teachers" icon="hero-users">Professores</:item>
      </.sidebar>
  """
  attr :current_path, :string, default: "/"

  slot :item, required: true do
    attr :path, :string, required: true
    attr :icon, :string
  end

  def sidebar(assigns) do
    ~H"""
    <aside class="w-64 bg-gray-900 min-h-screen">
      <div class="p-4">
        <span class="text-xl font-bold text-white">Hellen</span>
        <span class="ml-1 text-xs text-gray-400">Coordenador</span>
      </div>
      <nav class="mt-4">
        <a
          :for={item <- @item}
          href={item.path}
          class={[
            "flex items-center px-4 py-3 text-sm font-medium",
            item.path == @current_path && "bg-gray-800 text-white",
            item.path != @current_path && "text-gray-300 hover:bg-gray-800 hover:text-white"
          ]}
        >
          <.icon :if={item[:icon]} name={item.icon} class="h-5 w-5 mr-3" />
          <%= render_slot(item) %>
        </a>
      </nav>
    </aside>
    """
  end

  # ============================================================================
  # FILE UPLOAD
  # ============================================================================

  @doc """
  Renders a file upload dropzone for LiveView uploads.

  ## Examples

      <.dropzone upload={@uploads.audio} />
  """
  attr :upload, :map, required: true
  attr :accept, :string, default: "audio/*,video/*"
  attr :class, :string, default: nil

  def dropzone(assigns) do
    ~H"""
    <div
      id={"dropzone-#{@upload.ref}"}
      phx-hook="DropZone"
      phx-drop-target={@upload.ref}
      class={[
        "border-2 border-dashed border-gray-300 rounded-lg p-8",
        "text-center cursor-pointer transition-colors duration-200",
        "hover:border-indigo-400 hover:bg-indigo-50",
        @class
      ]}
    >
      <.live_file_input upload={@upload} class="hidden" />
      <div class="space-y-2">
        <.icon name="hero-cloud-arrow-up" class="mx-auto h-12 w-12 text-gray-400" />
        <div class="text-sm text-gray-600">
          <span class="font-semibold text-indigo-600">Clique para enviar</span> ou arraste e solte
        </div>
        <p class="text-xs text-gray-500">
          <%= @accept %>
        </p>
      </div>

      <div :for={entry <- @upload.entries} class="mt-4">
        <div class="flex items-center justify-between text-sm">
          <span class="truncate"><%= entry.client_name %></span>
          <span><%= entry.progress %>%</span>
        </div>
        <.progress value={entry.progress} class="mt-1" />
      </div>
    </div>
    """
  end

  # ============================================================================
  # TABLES
  # ============================================================================

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="Name"><%= user.name %></:col>
        <:col :let={user} label="Email"><%= user.email %></:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th
              :for={col <- @col}
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >
              <%= col[:label] %>
            </th>
            <th :if={@action != []} class="relative px-6 py-3">
              <span class="sr-only">Actions</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="bg-white divide-y divide-gray-200"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="hover:bg-gray-50">
            <td
              :for={{col, _i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={[
                "px-6 py-4 whitespace-nowrap text-sm text-gray-900",
                @row_click && "cursor-pointer"
              ]}
            >
              <%= render_slot(col, @row_item.(row)) %>
            </td>
            <td :if={@action != []} class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
              <%= for action <- @action do %>
                <%= render_slot(action, @row_item.(row)) %>
              <% end %>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  # ============================================================================
  # SIMPLE FORM
  # ============================================================================

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="space-y-6">
        <%= render_slot(@inner_block, f) %>
        <div :for={action <- @actions} class="flex items-center justify-end gap-4">
          <%= render_slot(action, f) %>
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders flash notices.
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <%= @title %>
      </p>
      <p class="mt-2 text-sm leading-5"><%= msg %></p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label="close">
        <span class="sr-only">Close</span> &times;
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
    </div>
    """
  end

  defp hide(js, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(HellenWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(HellenWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Shows a modal by ID.
  """
  def show_modal(id) when is_binary(id) do
    JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  @doc """
  Hides a modal by ID.
  """
  def hide_modal(id) when is_binary(id) do
    JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  # Note: focus_wrap is provided by Phoenix.Component, no need to define it here
end
