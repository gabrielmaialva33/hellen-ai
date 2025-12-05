defmodule HellenWeb.SettingsLive.Index do
  @moduledoc """
  Settings LiveView - Profile, notification preferences, and security settings.
  """
  use HellenWeb, :live_view

  alias Hellen.Accounts
  alias Hellen.Accounts.User
  alias Hellen.Notifications

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    {:ok, preferences} = Notifications.get_or_create_preferences(user.id)

    {:ok,
     socket
     |> assign(page_title: "Configuracoes")
     |> assign(active_tab: "profile")
     |> assign(preferences: preferences)
     |> assign_profile_form(user)
     |> assign_password_form()
     |> assign_preferences_form(preferences)}
  end

  defp assign_profile_form(socket, user) do
    changeset = User.profile_changeset(user, %{})
    assign(socket, profile_form: to_form(changeset))
  end

  defp assign_password_form(socket) do
    assign(socket,
      password_form:
        to_form(%{"current_password" => "", "new_password" => "", "confirm_password" => ""})
    )
  end

  defp assign_preferences_form(socket, preferences) do
    changeset = Notifications.Preference.changeset(preferences, %{})
    assign(socket, preferences_form: to_form(changeset))
  end

  # PWA OfflineIndicator hook events - ignore silently
  @impl true
  def handle_event("online", _params, socket), do: {:noreply, socket}
  def handle_event("offline", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_event("validate_profile", %{"user" => params}, socket) do
    changeset =
      socket.assigns.current_user
      |> User.profile_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, profile_form: to_form(changeset))}
  end

  def handle_event("save_profile", %{"user" => params}, socket) do
    case Accounts.update_user_profile(socket.assigns.current_user, params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(current_user: user)
         |> assign_profile_form(user)
         |> put_flash(:info, "Perfil atualizado com sucesso!")}

      {:error, changeset} ->
        {:noreply, assign(socket, profile_form: to_form(changeset))}
    end
  end

  def handle_event("save_password", params, socket) do
    %{
      "current_password" => current,
      "new_password" => new_password,
      "confirm_password" => confirm
    } = params

    cond do
      new_password != confirm ->
        {:noreply, put_flash(socket, :error, "As senhas nao coincidem")}

      String.length(new_password) < 8 ->
        {:noreply, put_flash(socket, :error, "A nova senha deve ter pelo menos 8 caracteres")}

      true ->
        case Accounts.change_user_password(socket.assigns.current_user, current, new_password) do
          {:ok, _user} ->
            {:noreply,
             socket
             |> assign_password_form()
             |> put_flash(:info, "Senha alterada com sucesso!")}

          {:error, :invalid_password} ->
            {:noreply, put_flash(socket, :error, "Senha atual incorreta")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Erro ao alterar senha")}
        end
    end
  end

  def handle_event("save_preferences", %{"preference" => params}, socket) do
    case Notifications.update_preferences(socket.assigns.current_user.id, params) do
      {:ok, preferences} ->
        {:noreply,
         socket
         |> assign(preferences: preferences)
         |> assign_preferences_form(preferences)
         |> put_flash(:info, "Preferencias atualizadas!")}

      {:error, changeset} ->
        {:noreply, assign(socket, preferences_form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-6 animate-fade-in">
      <!-- Header -->
      <div class="flex items-start gap-4">
        <div class="flex-shrink-0 w-12 h-12 rounded-xl bg-teal-500/10 dark:bg-teal-500/20 flex items-center justify-center">
          <.icon name="hero-cog-6-tooth" class="h-6 w-6 text-teal-600 dark:text-teal-400" />
        </div>
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900 dark:text-white tracking-tight">
            Configuracoes
          </h1>
          <p class="mt-1 text-slate-500 dark:text-slate-400">
            Gerencie seu perfil, preferencias e seguranca
          </p>
        </div>
      </div>

      <!-- Tabs -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-card border border-slate-200/50 dark:border-slate-700/50 p-1.5">
        <nav class="flex gap-1">
          <.tab_button active={@active_tab == "profile"} tab="profile" icon="hero-user">
            Perfil
          </.tab_button>
          <.tab_button active={@active_tab == "notifications"} tab="notifications" icon="hero-bell">
            Notificacoes
          </.tab_button>
          <.tab_button active={@active_tab == "security"} tab="security" icon="hero-shield-check">
            Seguranca
          </.tab_button>
        </nav>
      </div>

      <!-- Tab Content -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-card border border-slate-200/50 dark:border-slate-700/50 p-6 animate-fade-in-up">
        <!-- Profile Tab -->
        <div :if={@active_tab == "profile"} class="space-y-6">
          <div class="flex items-center gap-5 pb-6 border-b border-slate-200 dark:border-slate-700">
            <div class="relative group">
              <div class="h-20 w-20 rounded-2xl bg-gradient-to-br from-teal-500 to-teal-600 flex items-center justify-center text-white text-2xl font-bold shadow-lg group-hover:shadow-teal-500/25 transition-all duration-300">
                <%= String.first(@current_user.name || "U") |> String.upcase() %>
              </div>
              <div class="absolute -bottom-1 -right-1 w-6 h-6 rounded-lg bg-emerald-500 flex items-center justify-center">
                <.icon name="hero-check-mini" class="h-4 w-4 text-white" />
              </div>
            </div>
            <div>
              <h3 class="text-xl font-bold text-slate-900 dark:text-white">
                <%= @current_user.name %>
              </h3>
              <p class="text-sm text-slate-500 dark:text-slate-400 mb-2">
                <%= @current_user.email %>
              </p>
              <div class="flex items-center gap-2">
                <.badge variant={role_variant(@current_user.role)}>
                  <%= role_label(@current_user.role) %>
                </.badge>
                <.badge variant="default"><%= plan_label(@current_user.plan) %></.badge>
              </div>
            </div>
          </div>

          <.form
            for={@profile_form}
            phx-change="validate_profile"
            phx-submit="save_profile"
            class="space-y-5"
          >
            <div class="grid sm:grid-cols-2 gap-4">
              <.input field={@profile_form[:name]} type="text" label="Nome" required />
              <.input field={@profile_form[:email]} type="email" label="Email" required />
            </div>

            <div class="pt-4 flex justify-end">
              <.button type="submit" icon="hero-check" phx-disable-with="Salvando...">
                Salvar Alteracoes
              </.button>
            </div>
          </.form>
        </div>

        <!-- Notifications Tab -->
        <div :if={@active_tab == "notifications"} class="space-y-6">
          <div class="flex items-center gap-3 pb-4 border-b border-slate-200 dark:border-slate-700">
            <div class="w-10 h-10 rounded-xl bg-violet-100 dark:bg-violet-900/30 flex items-center justify-center">
              <.icon name="hero-envelope" class="h-5 w-5 text-violet-600 dark:text-violet-400" />
            </div>
            <div>
              <h3 class="text-lg font-semibold text-slate-900 dark:text-white">Preferencias de Email</h3>
              <p class="text-sm text-slate-500 dark:text-slate-400">
                Escolha quais notificacoes deseja receber por email
              </p>
            </div>
          </div>

          <.form for={@preferences_form} phx-submit="save_preferences" class="space-y-2">
            <.preference_toggle
              field={@preferences_form[:email_critical_alerts]}
              label="Alertas Criticos"
              description="Receba emails imediatos para alertas de alta severidade"
              color="red"
            />
            <.preference_toggle
              field={@preferences_form[:email_high_alerts]}
              label="Alertas de Alta Severidade"
              description="Notificacoes de alertas importantes"
              color="amber"
            />
            <.preference_toggle
              field={@preferences_form[:email_analysis_complete]}
              label="Analise Concluida"
              description="Receba um email quando sua aula for analisada"
              color="emerald"
            />
            <.preference_toggle
              field={@preferences_form[:email_weekly_summary]}
              label="Resumo Semanal"
              description="Receba um resumo semanal das suas aulas"
              color="teal"
            />

            <div class="!mt-8 pt-6 border-t border-slate-200 dark:border-slate-700">
              <div class="flex items-center gap-3 mb-4">
                <div class="w-10 h-10 rounded-xl bg-cyan-100 dark:bg-cyan-900/30 flex items-center justify-center">
                  <.icon name="hero-bell-alert" class="h-5 w-5 text-cyan-600 dark:text-cyan-400" />
                </div>
                <h3 class="text-lg font-semibold text-slate-900 dark:text-white">
                  Notificacoes In-App
                </h3>
              </div>
              <.preference_toggle
                field={@preferences_form[:inapp_all_alerts]}
                label="Todos os Alertas"
                description="Mostrar notificacoes de alertas na interface"
                color="violet"
              />
              <.preference_toggle
                field={@preferences_form[:inapp_analysis_complete]}
                label="Analise Concluida"
                description="Notificar quando uma analise terminar"
                color="teal"
              />
            </div>

            <div class="!mt-6 pt-4 flex justify-end">
              <.button type="submit" icon="hero-check" phx-disable-with="Salvando...">
                Salvar Preferencias
              </.button>
            </div>
          </.form>
        </div>

        <!-- Security Tab -->
        <div :if={@active_tab == "security"} class="space-y-6">
          <div class="flex items-center gap-3 pb-4 border-b border-slate-200 dark:border-slate-700">
            <div class="w-10 h-10 rounded-xl bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center">
              <.icon name="hero-key" class="h-5 w-5 text-amber-600 dark:text-amber-400" />
            </div>
            <div>
              <h3 class="text-lg font-semibold text-slate-900 dark:text-white">Alterar Senha</h3>
              <p class="text-sm text-slate-500 dark:text-slate-400">
                Atualize sua senha regularmente para manter sua conta segura
              </p>
            </div>
          </div>

          <form phx-submit="save_password" class="space-y-5">
            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                Senha Atual
              </label>
              <input
                type="password"
                name="current_password"
                required
                class="w-full rounded-xl border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-700/50 text-slate-900 dark:text-white px-4 py-3 focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-all duration-200"
              />
            </div>

            <div class="grid sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                  Nova Senha
                </label>
                <input
                  type="password"
                  name="new_password"
                  required
                  minlength="8"
                  class="w-full rounded-xl border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-700/50 text-slate-900 dark:text-white px-4 py-3 focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-all duration-200"
                />
                <p class="mt-2 text-xs text-slate-500 dark:text-slate-400 flex items-center gap-1">
                  <.icon name="hero-information-circle-mini" class="h-4 w-4" />
                  Minimo de 8 caracteres
                </p>
              </div>

              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                  Confirmar Nova Senha
                </label>
                <input
                  type="password"
                  name="confirm_password"
                  required
                  class="w-full rounded-xl border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-700/50 text-slate-900 dark:text-white px-4 py-3 focus:ring-2 focus:ring-teal-500/20 focus:border-teal-500 transition-all duration-200"
                />
              </div>
            </div>

            <div class="pt-4 flex justify-end">
              <.button type="submit" icon="hero-lock-closed" phx-disable-with="Alterando...">
                Alterar Senha
              </.button>
            </div>
          </form>

          <!-- Security Info -->
          <div class="mt-8 p-4 rounded-xl bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-600">
            <div class="flex items-start gap-3">
              <div class="flex-shrink-0 w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-900/30 flex items-center justify-center">
                <.icon name="hero-shield-check" class="h-4 w-4 text-teal-600 dark:text-teal-400" />
              </div>
              <div>
                <h4 class="text-sm font-semibold text-slate-900 dark:text-white">Dicas de Seguranca</h4>
                <ul class="mt-2 text-xs text-slate-500 dark:text-slate-400 space-y-1">
                  <li class="flex items-center gap-1.5">
                    <.icon name="hero-check-mini" class="h-3 w-3 text-emerald-500" />
                    Use uma combinacao de letras, numeros e simbolos
                  </li>
                  <li class="flex items-center gap-1.5">
                    <.icon name="hero-check-mini" class="h-3 w-3 text-emerald-500" />
                    Evite informacoes pessoais faceis de adivinhar
                  </li>
                  <li class="flex items-center gap-1.5">
                    <.icon name="hero-check-mini" class="h-3 w-3 text-emerald-500" />
                    Nao reutilize senhas de outros sites
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Component helpers

  attr :active, :boolean, required: true
  attr :tab, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp tab_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="change_tab"
      phx-value-tab={@tab}
      class={[
        "flex-1 flex items-center justify-center gap-2 py-3 px-4 rounded-lg font-medium text-sm transition-all duration-200",
        if(@active,
          do: "bg-teal-500 text-white shadow-sm",
          else: "text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700"
        )
      ]}
    >
      <.icon name={@icon} class="h-5 w-5" />
      <span class="hidden sm:inline"><%= render_slot(@inner_block) %></span>
    </button>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :description, :string, required: true
  attr :color, :string, default: "teal"

  defp preference_toggle(assigns) do
    ~H"""
    <div class="flex items-center justify-between py-4 px-4 -mx-4 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors group">
      <div class="flex items-center gap-3">
        <div class={["w-2 h-2 rounded-full", toggle_dot_color(@color)]}></div>
        <div>
          <label class="font-medium text-slate-900 dark:text-white cursor-pointer"><%= @label %></label>
          <p class="text-sm text-slate-500 dark:text-slate-400"><%= @description %></p>
        </div>
      </div>
      <label class="relative inline-flex items-center cursor-pointer flex-shrink-0">
        <input
          type="checkbox"
          name={@field.name}
          value="true"
          checked={Phoenix.HTML.Form.normalize_value("checkbox", @field.value)}
          class="sr-only peer"
        />
        <input type="hidden" name={@field.name} value="false" />
        <div class={[
          "w-12 h-7 rounded-full peer transition-colors duration-200",
          "bg-slate-200 dark:bg-slate-600",
          "peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-teal-500/20",
          "peer-checked:after:translate-x-5 peer-checked:after:border-white",
          "after:content-[''] after:absolute after:top-[2px] after:left-[2px]",
          "after:bg-white after:rounded-full after:h-6 after:w-6 after:shadow-sm",
          "after:transition-all after:duration-200",
          toggle_checked_color(@color)
        ]}>
        </div>
      </label>
    </div>
    """
  end

  defp toggle_dot_color("red"), do: "bg-red-500"
  defp toggle_dot_color("amber"), do: "bg-amber-500"
  defp toggle_dot_color("emerald"), do: "bg-emerald-500"
  defp toggle_dot_color("violet"), do: "bg-violet-500"
  defp toggle_dot_color("cyan"), do: "bg-cyan-500"
  defp toggle_dot_color(_), do: "bg-teal-500"

  defp toggle_checked_color("red"), do: "peer-checked:bg-red-500"
  defp toggle_checked_color("amber"), do: "peer-checked:bg-amber-500"
  defp toggle_checked_color("emerald"), do: "peer-checked:bg-emerald-500"
  defp toggle_checked_color("violet"), do: "peer-checked:bg-violet-500"
  defp toggle_checked_color("cyan"), do: "peer-checked:bg-cyan-500"
  defp toggle_checked_color(_), do: "peer-checked:bg-teal-500"

  defp role_label("teacher"), do: "Professor"
  defp role_label("coordinator"), do: "Coordenador"
  defp role_label("admin"), do: "Administrador"
  defp role_label(_), do: "Usuario"

  defp role_variant("coordinator"), do: "warning"
  defp role_variant("admin"), do: "error"
  defp role_variant(_), do: "default"

  defp plan_label("free"), do: "Plano Free"
  defp plan_label("pro"), do: "Plano Pro"
  defp plan_label("enterprise"), do: "Enterprise"
  defp plan_label(_), do: "Plano"
end
