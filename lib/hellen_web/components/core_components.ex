defmodule HellenWeb.CoreComponents do
  @moduledoc """
  Provides core UI components with 2025 Educational Design System.

  Components included:
  - Flash messages
  - Buttons (primary, secondary, outline, ghost, danger)
  - Form inputs
  - Cards (default, elevated, glass)
  - Progress bars
  - Badges
  - Alerts
  - Modals
  - Navigation (navbar, sidebar)
  - Icons (Heroicons)
  - Stats cards
  - Avatar
  - Tabs
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
  Renders a button with modern 2025 styling.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="secondary">Send!</.button>
      <.button variant="primary" size="lg" icon="hero-plus">New Item</.button>
  """
  attr :type, :string, default: "button"
  attr :variant, :string, default: "primary", values: ~w(primary secondary outline ghost danger)
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :disabled, :boolean, default: false
  attr :icon, :string, default: nil
  attr :icon_position, :string, default: "left", values: ~w(left right)
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(form name value phx-click phx-disable-with)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class={[
        "inline-flex items-center justify-center gap-2 font-medium rounded-lg",
        "transition-all duration-200 ease-out",
        "focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-background",
        "disabled:opacity-50 disabled:cursor-not-allowed disabled:pointer-events-none",
        button_size(@size),
        button_variant(@variant),
        @class
      ]}
      {@rest}
    >
      <.icon :if={@icon && @icon_position == "left"} name={@icon} class={icon_size(@size)} />
      <%= render_slot(@inner_block) %>
      <.icon :if={@icon && @icon_position == "right"} name={@icon} class={icon_size(@size)} />
    </button>
    """
  end

  defp button_size("sm"), do: "px-3 py-1.5 text-sm"
  defp button_size("md"), do: "px-4 py-2 text-sm"
  defp button_size("lg"), do: "px-6 py-3 text-base"

  defp icon_size("sm"), do: "h-4 w-4"
  defp icon_size("md"), do: "h-4 w-4"
  defp icon_size("lg"), do: "h-5 w-5"

  defp button_variant("primary") do
    "bg-teal-600 text-white hover:bg-teal-700 focus:ring-teal-500 shadow-sm hover:shadow-md"
  end

  defp button_variant("secondary") do
    "bg-sage-500 text-white hover:bg-sage-600 focus:ring-sage-500 shadow-sm hover:shadow-md"
  end

  defp button_variant("outline") do
    "border-2 border-teal-600 text-teal-600 bg-transparent hover:bg-teal-600 hover:text-white focus:ring-teal-500 dark:border-teal-500 dark:text-teal-500 dark:hover:bg-teal-500"
  end

  defp button_variant("ghost") do
    "text-slate-600 dark:text-slate-300 bg-transparent hover:bg-slate-100 dark:hover:bg-slate-800 focus:ring-teal-500"
  end

  defp button_variant("danger") do
    "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500 shadow-sm hover:shadow-md"
  end

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
      <label class="flex items-center gap-3 text-sm font-medium text-slate-700 dark:text-slate-200 cursor-pointer">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="h-4 w-4 rounded border-slate-300 dark:border-slate-600 text-teal-600 focus:ring-teal-500 dark:bg-slate-800 transition-colors"
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
        class={[
          "mt-1.5 block w-full rounded-lg border-slate-300 dark:border-slate-600",
          "bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100",
          "shadow-sm focus:border-teal-500 focus:ring-teal-500 sm:text-sm",
          "transition-colors duration-200"
        ]}
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
          "mt-1.5 block w-full rounded-lg border-slate-300 dark:border-slate-600",
          "bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100",
          "shadow-sm focus:border-teal-500 focus:ring-teal-500 sm:text-sm",
          "transition-colors duration-200 placeholder:text-slate-400 dark:placeholder:text-slate-500",
          @errors != [] &&
            "border-red-500 text-red-900 dark:text-red-400 focus:border-red-500 focus:ring-red-500"
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
          "mt-1.5 block w-full rounded-lg border-slate-300 dark:border-slate-600",
          "bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100",
          "shadow-sm focus:border-teal-500 focus:ring-teal-500 sm:text-sm",
          "transition-colors duration-200 placeholder:text-slate-400 dark:placeholder:text-slate-500",
          @errors != [] &&
            "border-red-500 text-red-900 dark:text-red-400 focus:border-red-500 focus:ring-red-500"
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
    <label for={@for} class="block text-sm font-medium text-slate-700 dark:text-slate-200">
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
    <p class="mt-1.5 flex items-center gap-1.5 text-sm text-red-600 dark:text-red-400 phx-no-feedback:hidden">
      <.icon name="hero-exclamation-circle-mini" class="h-4 w-4 flex-none" />
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  # ============================================================================
  # CARDS
  # ============================================================================

  @doc """
  Renders a card component with multiple variants.

  ## Variants
  - `:default` - Simple bordered card
  - `:elevated` - Card with shadow and hover effect
  - `:glass` - Glassmorphism effect

  ## Examples

      <.card>Simple card</.card>
      <.card variant="elevated">
        <:header>Card Title</:header>
        Card content here
        <:footer>Footer actions</:footer>
      </.card>
  """
  attr :variant, :string, default: "default", values: ~w(default elevated glass)
  attr :padding, :string, default: "md", values: ~w(none sm md lg)
  attr :class, :string, default: nil
  attr :rest, :global

  slot :header
  slot :inner_block, required: true
  slot :footer

  def card(assigns) do
    ~H"""
    <div
      class={[
        "rounded-xl overflow-hidden",
        card_variant(@variant),
        @class
      ]}
      {@rest}
    >
      <div :if={@header != []} class={["border-b border-slate-200 dark:border-slate-700", card_padding(@padding)]}>
        <%= render_slot(@header) %>
      </div>
      <div class={card_padding(@padding)}>
        <%= render_slot(@inner_block) %>
      </div>
      <div :if={@footer != []} class={["border-t border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/50", card_padding(@padding)]}>
        <%= render_slot(@footer) %>
      </div>
    </div>
    """
  end

  defp card_variant("default") do
    "bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700"
  end

  defp card_variant("elevated") do
    "bg-white dark:bg-slate-800 shadow-card hover:shadow-card-hover transition-shadow duration-200"
  end

  defp card_variant("glass") do
    "bg-white/80 dark:bg-slate-800/80 backdrop-blur-md border border-white/20 dark:border-slate-700/50"
  end

  defp card_padding("none"), do: ""
  defp card_padding("sm"), do: "px-4 py-3"
  defp card_padding("md"), do: "px-6 py-4"
  defp card_padding("lg"), do: "px-8 py-6"

  # ============================================================================
  # STATS CARD
  # ============================================================================

  @doc """
  Renders a statistics card for dashboard KPIs.

  ## Examples

      <.stat_card
        title="Total Aulas"
        value="127"
        icon="hero-academic-cap"
        color="teal"
        trend={%{value: 12, direction: :up}}
      />
  """
  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, default: nil
  attr :variant, :string, default: "default", values: ~w(default success processing pending warning error)
  attr :color, :string, default: nil, doc: "Deprecated: use variant instead"
  attr :subtitle, :string, default: nil
  attr :trend, :map, default: nil, doc: "Map with :value and :direction (:up, :down, :stable)"
  attr :class, :string, default: nil

  def stat_card(assigns) do
    # Support both color (legacy) and variant (new) attributes
    assigns = assign_new(assigns, :effective_variant, fn ->
      assigns[:color] || assigns[:variant] || "default"
    end)

    ~H"""
    <div class={["bg-white dark:bg-slate-800 rounded-xl shadow-card hover:shadow-elevated border border-slate-200/50 dark:border-slate-700/50 transition-all duration-300 p-5 group", @class]}>
      <div class="flex items-start justify-between">
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-slate-500 dark:text-slate-400 truncate">
            <%= @title %>
          </p>
          <p class="mt-2 text-3xl font-bold text-slate-900 dark:text-white tracking-tight">
            <%= @value %>
          </p>
          <div :if={@subtitle || @trend} class="mt-2 flex items-center gap-2">
            <p :if={@subtitle} class="text-xs text-slate-500 dark:text-slate-400">
              <%= @subtitle %>
            </p>
            <span
              :if={@trend}
              class={[
                "inline-flex items-center gap-0.5 text-xs font-medium",
                trend_color(@trend.direction)
              ]}
            >
              <.icon name={trend_icon(@trend.direction)} class="h-3.5 w-3.5" />
              <%= @trend.value %>%
            </span>
          </div>
        </div>
        <div :if={@icon} class={[
          "flex-shrink-0 w-12 h-12 rounded-xl flex items-center justify-center transition-transform duration-300 group-hover:scale-110",
          stat_icon_bg(@effective_variant)
        ]}>
          <.icon name={@icon} class={"h-6 w-6 #{stat_icon_color(@effective_variant)}"} />
        </div>
      </div>
    </div>
    """
  end

  defp stat_icon_bg("success"), do: "bg-emerald-100 dark:bg-emerald-900/30"
  defp stat_icon_bg("processing"), do: "bg-cyan-100 dark:bg-cyan-900/30"
  defp stat_icon_bg("pending"), do: "bg-amber-100 dark:bg-amber-900/30"
  defp stat_icon_bg("warning"), do: "bg-ochre-100 dark:bg-ochre-900/30"
  defp stat_icon_bg("error"), do: "bg-red-100 dark:bg-red-900/30"
  defp stat_icon_bg("teal"), do: "bg-teal-100 dark:bg-teal-900/30"
  defp stat_icon_bg("sage"), do: "bg-sage-100 dark:bg-sage-900/30"
  defp stat_icon_bg("mint"), do: "bg-mint-100 dark:bg-mint-900/30"
  defp stat_icon_bg("ochre"), do: "bg-ochre-100 dark:bg-ochre-900/30"
  defp stat_icon_bg("violet"), do: "bg-violet-100 dark:bg-violet-900/30"
  defp stat_icon_bg("cyan"), do: "bg-cyan-100 dark:bg-cyan-900/30"
  defp stat_icon_bg(_), do: "bg-teal-100 dark:bg-teal-900/30"

  defp stat_icon_color("success"), do: "text-emerald-600 dark:text-emerald-400"
  defp stat_icon_color("processing"), do: "text-cyan-600 dark:text-cyan-400"
  defp stat_icon_color("pending"), do: "text-amber-600 dark:text-amber-400"
  defp stat_icon_color("warning"), do: "text-ochre-600 dark:text-ochre-400"
  defp stat_icon_color("error"), do: "text-red-600 dark:text-red-400"
  defp stat_icon_color("teal"), do: "text-teal-600 dark:text-teal-400"
  defp stat_icon_color("sage"), do: "text-sage-600 dark:text-sage-400"
  defp stat_icon_color("mint"), do: "text-mint-600 dark:text-mint-400"
  defp stat_icon_color("ochre"), do: "text-ochre-600 dark:text-ochre-400"
  defp stat_icon_color("violet"), do: "text-violet-600 dark:text-violet-400"
  defp stat_icon_color("cyan"), do: "text-cyan-600 dark:text-cyan-400"
  defp stat_icon_color(_), do: "text-teal-600 dark:text-teal-400"

  defp trend_color(:up), do: "text-emerald-600 dark:text-emerald-400"
  defp trend_color(:down), do: "text-red-600 dark:text-red-400"
  defp trend_color(:stable), do: "text-slate-500 dark:text-slate-400"

  defp trend_icon(:up), do: "hero-arrow-trending-up-mini"
  defp trend_icon(:down), do: "hero-arrow-trending-down-mini"
  defp trend_icon(:stable), do: "hero-minus-mini"

  # ============================================================================
  # PROGRESS
  # ============================================================================

  @doc """
  Renders a progress bar.

  ## Examples

      <.progress value={50} />
      <.progress value={75} color="teal" size="lg" />
  """
  attr :value, :integer, default: 0
  attr :max, :integer, default: 100
  attr :color, :string, default: "teal", values: ~w(teal sage emerald amber red violet)
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :class, :string, default: nil

  def progress(assigns) do
    assigns = assign(assigns, :percentage, min(100, max(0, assigns.value / assigns.max * 100)))

    ~H"""
    <div class={["w-full bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden", progress_height(@size), @class]}>
      <div
        class={["rounded-full transition-all duration-500 ease-out", progress_height(@size), progress_color(@color)]}
        style={"width: #{@percentage}%"}
      >
      </div>
    </div>
    """
  end

  defp progress_height("sm"), do: "h-1.5"
  defp progress_height("md"), do: "h-2"
  defp progress_height("lg"), do: "h-3"

  defp progress_color("teal"), do: "bg-teal-500"
  defp progress_color("sage"), do: "bg-sage-500"
  defp progress_color("emerald"), do: "bg-emerald-500"
  defp progress_color("amber"), do: "bg-amber-500"
  defp progress_color("red"), do: "bg-red-500"
  defp progress_color("violet"), do: "bg-violet-500"

  # ============================================================================
  # BADGES
  # ============================================================================

  @doc """
  Renders a status badge.

  ## Examples

      <.badge>Default</.badge>
      <.badge variant="success">Completed</.badge>
      <.badge variant="processing" dot>Em andamento</.badge>
  """
  attr :variant, :string,
    default: "default",
    values: ~w(default pending processing completed failed success warning error info alert)

  attr :dot, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium",
        badge_variant(@variant),
        @class
      ]}
      {@rest}
    >
      <span :if={@dot} class={["w-1.5 h-1.5 rounded-full", badge_dot(@variant)]}></span>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  defp badge_variant("default"), do: "bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300"
  defp badge_variant("pending"), do: "bg-ochre-100 text-ochre-700 dark:bg-ochre-900/30 dark:text-ochre-400"
  defp badge_variant("processing"), do: "bg-cyan-100 text-cyan-700 dark:bg-cyan-900/30 dark:text-cyan-400"
  defp badge_variant("completed"), do: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400"
  defp badge_variant("failed"), do: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"
  defp badge_variant("success"), do: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400"
  defp badge_variant("warning"), do: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"
  defp badge_variant("error"), do: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"
  defp badge_variant("info"), do: "bg-cyan-100 text-cyan-700 dark:bg-cyan-900/30 dark:text-cyan-400"
  defp badge_variant("alert"), do: "bg-violet-100 text-violet-700 dark:bg-violet-900/30 dark:text-violet-400"

  defp badge_dot("default"), do: "bg-slate-500"
  defp badge_dot("pending"), do: "bg-ochre-500"
  defp badge_dot("processing"), do: "bg-cyan-500 animate-pulse"
  defp badge_dot("completed"), do: "bg-emerald-500"
  defp badge_dot("failed"), do: "bg-red-500"
  defp badge_dot("success"), do: "bg-emerald-500"
  defp badge_dot("warning"), do: "bg-amber-500"
  defp badge_dot("error"), do: "bg-red-500"
  defp badge_dot("info"), do: "bg-cyan-500"
  defp badge_dot("alert"), do: "bg-violet-500"

  # ============================================================================
  # AVATAR
  # ============================================================================

  @doc """
  Renders an avatar component.

  ## Examples

      <.avatar name="John Doe" />
      <.avatar name="Jane" size="lg" src="/images/avatar.jpg" />
  """
  attr :name, :string, required: true
  attr :src, :string, default: nil
  attr :size, :string, default: "md", values: ~w(xs sm md lg xl)
  attr :class, :string, default: nil

  def avatar(assigns) do
    assigns = assign(assigns, :initials, get_initials(assigns.name))

    ~H"""
    <div class={["relative inline-flex items-center justify-center rounded-full font-medium overflow-hidden", avatar_size(@size), avatar_bg(), @class]}>
      <img :if={@src} src={@src} alt={@name} class="w-full h-full object-cover" />
      <span :if={!@src} class={avatar_text_size(@size)}>
        <%= @initials %>
      </span>
    </div>
    """
  end

  defp get_initials(name) when is_binary(name) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
  end

  defp get_initials(_), do: "?"

  defp avatar_size("xs"), do: "w-6 h-6"
  defp avatar_size("sm"), do: "w-8 h-8"
  defp avatar_size("md"), do: "w-10 h-10"
  defp avatar_size("lg"), do: "w-12 h-12"
  defp avatar_size("xl"), do: "w-16 h-16"

  defp avatar_text_size("xs"), do: "text-2xs"
  defp avatar_text_size("sm"), do: "text-xs"
  defp avatar_text_size("md"), do: "text-sm"
  defp avatar_text_size("lg"), do: "text-base"
  defp avatar_text_size("xl"), do: "text-lg"

  defp avatar_bg do
    "bg-gradient-to-br from-teal-500 to-teal-600 text-white"
  end

  # ============================================================================
  # TABS
  # ============================================================================

  @doc """
  Renders a tab navigation.

  ## Examples

      <.tabs active="overview">
        <:tab id="overview" icon="hero-home">Overview</:tab>
        <:tab id="details">Details</:tab>
        <:tab id="settings" icon="hero-cog-6-tooth">Settings</:tab>
      </.tabs>
  """
  attr :active, :string, required: true
  attr :class, :string, default: nil

  slot :tab, required: true do
    attr :id, :string, required: true
    attr :icon, :string
    attr :href, :string
  end

  def tabs(assigns) do
    ~H"""
    <div class={["flex gap-1 border-b border-slate-200 dark:border-slate-700", @class]}>
      <a
        :for={tab <- @tab}
        href={tab[:href] || "#"}
        phx-click={!tab[:href] && "tab_change"}
        phx-value-tab={tab.id}
        class={[
          "inline-flex items-center gap-2 px-4 py-2.5 text-sm font-medium -mb-px border-b-2 transition-colors",
          tab.id == @active && "text-teal-600 dark:text-teal-400 border-teal-600 dark:border-teal-400",
          tab.id != @active && "text-slate-500 dark:text-slate-400 border-transparent hover:text-slate-700 dark:hover:text-slate-200 hover:border-slate-300"
        ]}
      >
        <.icon :if={tab[:icon]} name={tab.icon} class="h-4 w-4" />
        <%= render_slot(tab) %>
      </a>
    </div>
    """
  end

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
        "p-4 rounded-xl mb-4",
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
        <div class="ml-3 flex-1">
          <h3 :if={@title} class="text-sm font-semibold"><%= @title %></h3>
          <div class={["text-sm", @title && "mt-1"]}>
            <%= render_slot(@inner_block) %>
          </div>
        </div>
        <button
          :if={@dismissible}
          type="button"
          class="ml-auto -mx-1.5 -my-1.5 p-1.5 rounded-lg hover:bg-black/10 transition-colors"
        >
          <.icon name="hero-x-mark-mini" class="h-5 w-5" />
        </button>
      </div>
    </div>
    """
  end

  defp alert_variant("info"), do: "bg-cyan-50 text-cyan-800 dark:bg-cyan-900/20 dark:text-cyan-300 border border-cyan-200 dark:border-cyan-800"
  defp alert_variant("success"), do: "bg-emerald-50 text-emerald-800 dark:bg-emerald-900/20 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800"
  defp alert_variant("warning"), do: "bg-amber-50 text-amber-800 dark:bg-amber-900/20 dark:text-amber-300 border border-amber-200 dark:border-amber-800"
  defp alert_variant("error"), do: "bg-red-50 text-red-800 dark:bg-red-900/20 dark:text-red-300 border border-red-200 dark:border-red-800"

  defp alert_icon("info"), do: "hero-information-circle-mini"
  defp alert_icon("success"), do: "hero-check-circle-mini"
  defp alert_icon("warning"), do: "hero-exclamation-triangle-mini"
  defp alert_icon("error"), do: "hero-x-circle-mini"

  # ============================================================================
  # EMPTY STATE
  # ============================================================================

  @doc """
  Renders an empty state placeholder.

  ## Examples

      <.empty_state
        icon="hero-document-text"
        title="Nenhuma aula encontrada"
        description="Comece criando sua primeira aula"
      >
        <.button icon="hero-plus">Nova Aula</.button>
      </.empty_state>
  """
  attr :icon, :string, default: nil
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :class, :string, default: nil

  slot :inner_block

  def empty_state(assigns) do
    ~H"""
    <div class={["flex flex-col items-center justify-center py-12 px-4 text-center", @class]}>
      <div :if={@icon} class="w-16 h-16 rounded-2xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center mb-4">
        <.icon name={@icon} class="h-8 w-8 text-slate-400 dark:text-slate-500" />
      </div>
      <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-2">
        <%= @title %>
      </h3>
      <p :if={@description} class="text-sm text-slate-500 dark:text-slate-400 max-w-sm mb-6">
        <%= @description %>
      </p>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

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
        class="bg-slate-900/60 dark:bg-slate-900/80 backdrop-blur-sm fixed inset-0 transition-opacity"
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
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="w-full max-w-lg">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-elevated rounded-2xl bg-white dark:bg-slate-800 p-6 transition"
            >
              <div class="absolute top-4 right-4">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="flex-none p-2 text-slate-400 hover:text-slate-500 dark:hover:text-slate-300 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
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
    <nav class="bg-white dark:bg-slate-900 shadow-sm border-b border-slate-200 dark:border-slate-700 transition-colors duration-200">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex items-center">
            <a href={if @current_user, do: "/dashboard", else: "/"} class="flex items-center gap-1">
              <span class="text-xl font-bold text-teal-600 dark:text-teal-400">Hellen</span>
              <span class="text-xs font-medium text-slate-500 dark:text-slate-400">AI</span>
            </a>
          </div>

          <div :if={@current_user} class="flex items-center gap-4">
            <a
              href="/lessons/new"
              class="text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white text-sm font-medium transition-colors"
            >
              Nova Aula
            </a>
            <button
              phx-hook="ThemeToggle"
              id="navbar-theme-toggle"
              class="p-2 text-slate-400 dark:text-slate-300 hover:text-slate-500 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              title="Alternar tema"
            >
              <.icon name="hero-sun" class="h-5 w-5 dark:hidden" />
              <.icon name="hero-moon" class="h-5 w-5 hidden dark:block" />
            </button>
            <div class="flex items-center gap-2">
              <.avatar name={@current_user.name || @current_user.email} size="sm" />
              <a
                href="/logout"
                class="text-slate-400 dark:text-slate-300 hover:text-slate-500 dark:hover:text-white transition-colors"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="h-5 w-5" />
              </a>
            </div>
          </div>

          <div :if={!@current_user} class="flex items-center gap-4">
            <button
              phx-hook="ThemeToggle"
              id="navbar-theme-toggle-guest"
              class="p-2 text-slate-400 dark:text-slate-300 hover:text-slate-500 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              title="Alternar tema"
            >
              <.icon name="hero-sun" class="h-5 w-5 dark:hidden" />
              <.icon name="hero-moon" class="h-5 w-5 hidden dark:block" />
            </button>
            <a
              href="/login"
              class="text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white text-sm font-medium transition-colors"
            >
              Entrar
            </a>
            <a href="/register" class="inline-flex items-center px-4 py-2 rounded-lg text-sm font-medium text-white bg-teal-600 hover:bg-teal-700 shadow-sm transition-colors">
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
    <nav class="sticky top-0 z-50 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-b border-slate-200/50 dark:border-slate-700/50 transition-all duration-300">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-16">
          <!-- Logo -->
          <div class="flex items-center">
            <a href={if @current_user, do: "/dashboard", else: "/"} class="flex items-center gap-1">
              <span class="text-xl font-bold text-teal-600 dark:text-teal-400">Hellen</span>
              <span class="text-xs font-medium text-slate-500 dark:text-slate-400">AI</span>
            </a>
          </div>
          <!-- Desktop Navigation (logged in) -->
          <div :if={@current_user} class="hidden md:flex items-center gap-6">
            <a
              href="/dashboard"
              class="text-slate-600 dark:text-slate-300 hover:text-teal-600 dark:hover:text-teal-400 text-sm font-medium transition-colors"
            >
              Dashboard
            </a>
            <a
              href="/lessons/new"
              class="inline-flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-semibold text-white bg-teal-600 hover:bg-teal-700 shadow-sm hover:shadow-md transition-all duration-200"
            >
              <.icon name="hero-plus" class="h-4 w-4" /> Nova Aula
            </a>
            <button
              phx-hook="ThemeToggle"
              id="app-theme-toggle"
              class="p-2 text-slate-400 dark:text-slate-300 hover:text-slate-600 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              title="Alternar tema"
            >
              <.icon name="hero-sun" class="h-5 w-5 dark:hidden" />
              <.icon name="hero-moon" class="h-5 w-5 hidden dark:block" />
            </button>
            <div class="flex items-center gap-3 pl-4 border-l border-slate-200 dark:border-slate-700">
              <.avatar name={@current_user.name || @current_user.email} />
              <span class="text-sm font-medium text-slate-700 dark:text-slate-200 hidden lg:block">
                <%= @current_user.name || @current_user.email %>
              </span>
              <a
                href="/logout"
                class="p-2 text-slate-400 dark:text-slate-300 hover:text-red-500 dark:hover:text-red-400 transition-colors"
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
              class="p-2 text-slate-400 dark:text-slate-300 hover:text-slate-600 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              title="Alternar tema"
            >
              <.icon name="hero-sun" class="h-5 w-5 dark:hidden" />
              <.icon name="hero-moon" class="h-5 w-5 hidden dark:block" />
            </button>
            <button
              type="button"
              class="p-2 text-slate-400 dark:text-slate-300 hover:text-slate-600 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              phx-click={JS.toggle(to: "#app-mobile-menu", in: "fade-in-scale", out: "fade-out-scale")}
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
              class="p-2 text-slate-400 dark:text-slate-300 hover:text-slate-500 dark:hover:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              title="Alternar tema"
            >
              <.icon name="hero-sun" class="h-5 w-5 dark:hidden" />
              <.icon name="hero-moon" class="h-5 w-5 hidden dark:block" />
            </button>
            <a
              href="/login"
              class="text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white text-sm font-medium transition-colors"
            >
              Entrar
            </a>
            <a
              href="/register"
              class="inline-flex items-center px-4 py-2 rounded-lg text-sm font-semibold text-white bg-teal-600 hover:bg-teal-700 shadow-sm transition-all duration-200"
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
        class="hidden md:hidden bg-white/95 dark:bg-slate-900/95 backdrop-blur-md border-t border-slate-200/50 dark:border-slate-700/50"
      >
        <div class="px-4 py-4 space-y-3">
          <div class="flex items-center gap-3 pb-3 border-b border-slate-200 dark:border-slate-700">
            <.avatar name={@current_user.name || @current_user.email} size="lg" />
            <div>
              <p class="text-sm font-medium text-slate-900 dark:text-white">
                <%= @current_user.name || "Usuario" %>
              </p>
              <p class="text-xs text-slate-500 dark:text-slate-400"><%= @current_user.email %></p>
            </div>
          </div>
          <a
            href="/dashboard"
            class="flex items-center gap-3 px-3 py-2 rounded-lg text-base font-medium text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
            phx-click={JS.hide(to: "#app-mobile-menu")}
          >
            <.icon name="hero-home" class="h-5 w-5" /> Dashboard
          </a>
          <a
            href="/lessons/new"
            class="flex items-center gap-3 px-3 py-2 rounded-lg text-base font-medium text-teal-600 dark:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-500/10 transition-colors"
            phx-click={JS.hide(to: "#app-mobile-menu")}
          >
            <.icon name="hero-plus-circle" class="h-5 w-5" /> Nova Aula
          </a>
          <a
            href="/logout"
            class="flex items-center gap-3 px-3 py-2 rounded-lg text-base font-medium text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-500/10 transition-colors"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="h-5 w-5" /> Sair
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
    <aside class="w-64 bg-slate-900 min-h-screen flex flex-col">
      <div class="p-5 border-b border-slate-800">
        <span class="text-xl font-bold text-teal-400">Hellen</span>
        <span class="ml-1 text-xs text-slate-500">Coordenador</span>
      </div>
      <nav class="flex-1 py-4 px-3 space-y-1">
        <a
          :for={item <- @item}
          href={item.path}
          class={[
            "flex items-center gap-3 px-3 py-2.5 text-sm font-medium rounded-lg transition-colors",
            item.path == @current_path && "bg-teal-600/20 text-teal-400",
            item.path != @current_path && "text-slate-400 hover:bg-slate-800 hover:text-white"
          ]}
        >
          <.icon :if={item[:icon]} name={item.icon} class="h-5 w-5" />
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
        "border-2 border-dashed border-slate-300 dark:border-slate-600 rounded-xl p-8",
        "text-center cursor-pointer transition-all duration-200",
        "hover:border-teal-400 hover:bg-teal-50 dark:hover:bg-teal-900/10",
        @class
      ]}
    >
      <.live_file_input upload={@upload} class="hidden" />
      <div class="space-y-3">
        <div class="w-14 h-14 mx-auto rounded-xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center">
          <.icon name="hero-cloud-arrow-up" class="h-7 w-7 text-slate-400" />
        </div>
        <div class="text-sm text-slate-600 dark:text-slate-400">
          <span class="font-semibold text-teal-600 dark:text-teal-400">Clique para enviar</span> ou arraste e solte
        </div>
        <p class="text-xs text-slate-500 dark:text-slate-500">
          <%= @accept %>
        </p>
      </div>

      <div :for={entry <- @upload.entries} class="mt-6 text-left">
        <div class="flex items-center justify-between text-sm mb-2">
          <span class="truncate text-slate-700 dark:text-slate-300"><%= entry.client_name %></span>
          <span class="text-teal-600 dark:text-teal-400 font-medium"><%= entry.progress %>%</span>
        </div>
        <.progress value={entry.progress} />
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
    <div class="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-700">
      <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-700">
        <thead class="bg-slate-50 dark:bg-slate-800/50">
          <tr>
            <th
              :for={col <- @col}
              class="px-4 py-3 text-left text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider"
            >
              <%= col[:label] %>
            </th>
            <th :if={@action != []} class="relative px-4 py-3">
              <span class="sr-only">Actions</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={match?(%Phoenix.LiveView.LiveStream{}, @rows) && "stream"}
          class="bg-white dark:bg-slate-800 divide-y divide-slate-200 dark:divide-slate-700"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors">
            <td
              :for={{col, _i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={[
                "px-4 py-3 text-sm text-slate-900 dark:text-slate-100",
                @row_click && "cursor-pointer"
              ]}
            >
              <%= render_slot(col, @row_item.(row)) %>
            </td>
            <td :if={@action != []} class="px-4 py-3 whitespace-nowrap text-right text-sm font-medium">
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
        <div :for={action <- @actions} class="flex items-center justify-end gap-4 pt-4">
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
        "fixed top-4 right-4 w-80 sm:w-96 z-50 rounded-xl p-4 shadow-elevated",
        @kind == :info && "bg-emerald-50 dark:bg-emerald-900/50 text-emerald-800 dark:text-emerald-200 ring-1 ring-emerald-500/20",
        @kind == :error && "bg-red-50 dark:bg-red-900/50 text-red-800 dark:text-red-200 ring-1 ring-red-500/20"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon name={if @kind == :info, do: "hero-check-circle-mini", else: "hero-x-circle-mini"} class="h-5 w-5" />
        <%= @title %>
      </p>
      <p class={["text-sm leading-5", @title && "mt-1"]}><%= msg %></p>
      <button type="button" class="absolute top-3 right-3 p-1 rounded-lg hover:bg-black/10 dark:hover:bg-white/10 transition-colors" aria-label="close">
        <.icon name="hero-x-mark-mini" class="h-4 w-4" />
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
      <.flash kind={:info} title="Sucesso!" flash={@flash} />
      <.flash kind={:error} title="Erro!" flash={@flash} />
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

  # ============================================================================
  # LOADING SKELETONS
  # ============================================================================

  @doc """
  Renders a skeleton loading placeholder.

  ## Examples

      <.skeleton class="h-4 w-3/4" />
      <.skeleton variant="circle" class="h-10 w-10" />
      <.skeleton variant="text" lines={3} />
  """
  attr :variant, :string, default: "rectangle", values: ~w(rectangle circle text avatar card stat)
  attr :class, :string, default: nil
  attr :lines, :integer, default: 3
  attr :animated, :boolean, default: true

  def skeleton(assigns) do
    ~H"""
    <div
      :if={@variant == "rectangle"}
      class={[
        "rounded-lg bg-slate-200 dark:bg-slate-700",
        @animated && "animate-pulse",
        @class
      ]}
    />

    <div
      :if={@variant == "circle"}
      class={[
        "rounded-full bg-slate-200 dark:bg-slate-700",
        @animated && "animate-pulse",
        @class
      ]}
    />

    <div :if={@variant == "text"} class={["space-y-2", @class]}>
      <div
        :for={i <- 1..@lines}
        class={[
          "h-4 rounded bg-slate-200 dark:bg-slate-700",
          @animated && "animate-pulse",
          i == @lines && "w-3/4"
        ]}
      />
    </div>

    <div
      :if={@variant == "avatar"}
      class={[
        "flex items-center gap-3",
        @class
      ]}
    >
      <div class={["w-10 h-10 rounded-full bg-slate-200 dark:bg-slate-700", @animated && "animate-pulse"]} />
      <div class="space-y-2 flex-1">
        <div class={["h-4 w-1/3 rounded bg-slate-200 dark:bg-slate-700", @animated && "animate-pulse"]} />
        <div class={["h-3 w-1/2 rounded bg-slate-200 dark:bg-slate-700", @animated && "animate-pulse"]} />
      </div>
    </div>

    <div
      :if={@variant == "card"}
      class={[
        "bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-5 space-y-4",
        @class
      ]}
    >
      <div class="flex items-center gap-3">
        <div class={["w-12 h-12 rounded-xl bg-slate-200 dark:bg-slate-700", @animated && "animate-pulse"]} />
        <div class="flex-1 space-y-2">
          <div class={["h-4 w-1/2 rounded bg-slate-200 dark:bg-slate-700", @animated && "animate-pulse"]} />
          <div class={["h-3 w-3/4 rounded bg-slate-200 dark:bg-slate-700", @animated && "animate-pulse"]} />
        </div>
      </div>
      <div class="space-y-2">
        <div class={["h-3 rounded bg-slate-200 dark:bg-slate-700", @animated && "animate-pulse"]} />
        <div class={["h-3 w-5/6 rounded bg-slate-200 dark:bg-slate-700", @animated && "animate-pulse"]} />
      </div>
    </div>

    <div
      :if={@variant == "stat"}
      class={[
        "bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-5",
        @class
      ]}
    >
      <div class="flex items-start justify-between">
        <div class="space-y-3 flex-1">
          <div class={["h-4 w-1/3 rounded bg-slate-200 dark:bg-slate-700", @animated && "animate-pulse"]} />
          <div class={["h-8 w-1/2 rounded bg-slate-200 dark:bg-slate-700", @animated && "animate-pulse"]} />
          <div class={["h-3 w-2/3 rounded bg-slate-200 dark:bg-slate-700", @animated && "animate-pulse"]} />
        </div>
        <div class={["w-12 h-12 rounded-xl bg-slate-200 dark:bg-slate-700", @animated && "animate-pulse"]} />
      </div>
    </div>
    """
  end

  @doc """
  Renders a loading spinner.

  ## Examples

      <.spinner />
      <.spinner size="lg" />
      <.spinner variant="dots" />
  """
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :variant, :string, default: "spinner", values: ~w(spinner dots bars)
  attr :class, :string, default: nil

  def spinner(assigns) do
    ~H"""
    <div
      :if={@variant == "spinner"}
      class={[
        "inline-block border-2 border-current border-t-transparent rounded-full animate-spin",
        spinner_size(@size),
        "text-teal-600 dark:text-teal-400",
        @class
      ]}
      role="status"
      aria-label="Loading"
    />

    <div
      :if={@variant == "dots"}
      class={["inline-flex items-center gap-1", @class]}
      role="status"
      aria-label="Loading"
    >
      <span class={["rounded-full bg-teal-600 dark:bg-teal-400 animate-bounce", dots_size(@size)]} style="animation-delay: 0ms" />
      <span class={["rounded-full bg-teal-600 dark:bg-teal-400 animate-bounce", dots_size(@size)]} style="animation-delay: 150ms" />
      <span class={["rounded-full bg-teal-600 dark:bg-teal-400 animate-bounce", dots_size(@size)]} style="animation-delay: 300ms" />
    </div>

    <div
      :if={@variant == "bars"}
      class={["inline-flex items-end gap-0.5", @class]}
      role="status"
      aria-label="Loading"
    >
      <span class={["bg-teal-600 dark:bg-teal-400 animate-pulse rounded-sm", bars_size(@size)]} style="animation-delay: 0ms" />
      <span class={["bg-teal-600 dark:bg-teal-400 animate-pulse rounded-sm", bars_size(@size)]} style="animation-delay: 100ms" />
      <span class={["bg-teal-600 dark:bg-teal-400 animate-pulse rounded-sm", bars_size(@size)]} style="animation-delay: 200ms" />
      <span class={["bg-teal-600 dark:bg-teal-400 animate-pulse rounded-sm", bars_size(@size)]} style="animation-delay: 300ms" />
    </div>
    """
  end

  defp spinner_size("sm"), do: "w-4 h-4"
  defp spinner_size("md"), do: "w-6 h-6"
  defp spinner_size("lg"), do: "w-8 h-8"

  defp dots_size("sm"), do: "w-1.5 h-1.5"
  defp dots_size("md"), do: "w-2 h-2"
  defp dots_size("lg"), do: "w-3 h-3"

  defp bars_size("sm"), do: "w-1 h-3"
  defp bars_size("md"), do: "w-1.5 h-4"
  defp bars_size("lg"), do: "w-2 h-5"

  @doc """
  Renders a loading overlay.

  ## Examples

      <.loading_overlay />
      <.loading_overlay message="Carregando dados..." />
  """
  attr :message, :string, default: nil
  attr :class, :string, default: nil

  def loading_overlay(assigns) do
    ~H"""
    <div class={[
      "absolute inset-0 z-10 flex flex-col items-center justify-center",
      "bg-white/80 dark:bg-slate-900/80 backdrop-blur-sm rounded-xl",
      @class
    ]}>
      <.spinner size="lg" />
      <p :if={@message} class="mt-3 text-sm text-slate-600 dark:text-slate-400"><%= @message %></p>
    </div>
    """
  end

  # ============================================================================
  # TOOLTIP
  # ============================================================================

  @doc """
  Renders a tooltip.

  ## Examples

      <.tooltip text="Hello world">
        <button>Hover me</button>
      </.tooltip>
  """
  attr :text, :string, required: true
  attr :position, :string, default: "top", values: ~w(top bottom left right)
  attr :class, :string, default: nil

  slot :inner_block, required: true

  def tooltip(assigns) do
    ~H"""
    <div class="relative group inline-block">
      <%= render_slot(@inner_block) %>
      <div class={[
        "absolute z-50 px-2 py-1 text-xs font-medium whitespace-nowrap rounded shadow-lg",
        "bg-slate-900 text-white dark:bg-slate-100 dark:text-slate-900",
        "opacity-0 invisible group-hover:opacity-100 group-hover:visible",
        "transition-all duration-200",
        tooltip_position(@position),
        @class
      ]}>
        <%= @text %>
        <div class={["absolute w-2 h-2 rotate-45 bg-slate-900 dark:bg-slate-100", tooltip_arrow(@position)]} />
      </div>
    </div>
    """
  end

  defp tooltip_position("top"), do: "bottom-full left-1/2 -translate-x-1/2 mb-2"
  defp tooltip_position("bottom"), do: "top-full left-1/2 -translate-x-1/2 mt-2"
  defp tooltip_position("left"), do: "right-full top-1/2 -translate-y-1/2 mr-2"
  defp tooltip_position("right"), do: "left-full top-1/2 -translate-y-1/2 ml-2"

  defp tooltip_arrow("top"), do: "top-full left-1/2 -translate-x-1/2 -translate-y-1/2"
  defp tooltip_arrow("bottom"), do: "bottom-full left-1/2 -translate-x-1/2 translate-y-1/2"
  defp tooltip_arrow("left"), do: "left-full top-1/2 -translate-y-1/2 -translate-x-1/2"
  defp tooltip_arrow("right"), do: "right-full top-1/2 -translate-y-1/2 translate-x-1/2"

  # ============================================================================
  # ANIMATED COUNTER
  # ============================================================================

  @doc """
  Renders an animated counter that counts up to a target value.
  Requires the AnimatedCounter hook to be enabled in app.js.

  ## Examples

      <.animated_counter value={1234} />
      <.animated_counter value={99.5} prefix="R$" suffix="%" />
  """
  attr :value, :any, required: true
  attr :prefix, :string, default: nil
  attr :suffix, :string, default: nil
  attr :duration, :integer, default: 1500
  attr :class, :string, default: nil

  def animated_counter(assigns) do
    ~H"""
    <span
      id={"counter-#{:erlang.unique_integer([:positive])}"}
      phx-hook="AnimatedCounter"
      data-target={@value}
      data-duration={@duration}
      data-prefix={@prefix || ""}
      data-suffix={@suffix || ""}
      class={["tabular-nums", @class]}
    >
      <%= @prefix %><span class="counter-value">0</span><%= @suffix %>
    </span>
    """
  end

  # ============================================================================
  # DROPDOWN MENU
  # ============================================================================

  @doc """
  Renders a dropdown menu.

  ## Examples

      <.dropdown id="user-menu">
        <:trigger>
          <button>Menu</button>
        </:trigger>
        <:item>Profile</:item>
        <:item>Settings</:item>
        <:divider />
        <:item variant="danger">Logout</:item>
      </.dropdown>
  """
  attr :id, :string, required: true
  attr :position, :string, default: "bottom-right", values: ~w(bottom-left bottom-right top-left top-right)
  attr :class, :string, default: nil

  slot :trigger, required: true
  slot :item do
    attr :href, :string
    attr :variant, :string
  end
  slot :divider

  def dropdown(assigns) do
    ~H"""
    <div class={["relative inline-block", @class]}>
      <div phx-click={JS.toggle(to: "##{@id}-menu", in: "animate-fade-in-scale", out: "animate-fade-out-scale")}>
        <%= render_slot(@trigger) %>
      </div>
      <div
        id={"#{@id}-menu"}
        class={[
          "absolute z-50 min-w-[180px] rounded-xl hidden",
          "bg-white dark:bg-slate-800 shadow-elevated",
          "border border-slate-200 dark:border-slate-700",
          "py-1 origin-top-right",
          dropdown_position(@position)
        ]}
        phx-click-away={JS.hide(to: "##{@id}-menu")}
      >
        <%= for {item, _idx} <- Enum.with_index(@item) do %>
          <.link
            :if={item[:href]}
            navigate={item[:href]}
            class={[
              "flex items-center gap-2 px-4 py-2 text-sm transition-colors",
              dropdown_item_variant(item[:variant])
            ]}
          >
            <%= render_slot(item) %>
          </.link>
          <button
            :if={!item[:href]}
            type="button"
            class={[
              "flex items-center gap-2 px-4 py-2 text-sm w-full text-left transition-colors",
              dropdown_item_variant(item[:variant])
            ]}
          >
            <%= render_slot(item) %>
          </button>
        <% end %>
        <div :for={_ <- @divider} class="my-1 border-t border-slate-200 dark:border-slate-700" />
      </div>
    </div>
    """
  end

  defp dropdown_position("bottom-right"), do: "right-0 mt-2"
  defp dropdown_position("bottom-left"), do: "left-0 mt-2"
  defp dropdown_position("top-right"), do: "right-0 bottom-full mb-2"
  defp dropdown_position("top-left"), do: "left-0 bottom-full mb-2"

  defp dropdown_item_variant("danger"), do: "text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20"
  defp dropdown_item_variant(_), do: "text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700"
end
