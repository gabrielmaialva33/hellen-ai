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
    <div class="max-w-4xl mx-auto space-y-6">
      <!-- Header -->
      <div>
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Configuracoes</h1>
        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
          Gerencie seu perfil, preferencias e seguranca
        </p>
      </div>
      <!-- Tabs -->
      <div class="border-b border-gray-200 dark:border-slate-700">
        <nav class="flex space-x-8">
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
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6">
        <!-- Profile Tab -->
        <div :if={@active_tab == "profile"} class="space-y-6">
          <div class="flex items-center gap-4 mb-6">
            <div class="h-20 w-20 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white text-2xl font-bold">
              <%= String.first(@current_user.name || "U") |> String.upcase() %>
            </div>
            <div>
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                <%= @current_user.name %>
              </h3>
              <div class="flex items-center gap-2 mt-1">
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
            class="space-y-4"
          >
            <.input field={@profile_form[:name]} type="text" label="Nome" required />
            <.input field={@profile_form[:email]} type="email" label="Email" required />

            <div class="pt-4">
              <.button type="submit" phx-disable-with="Salvando...">
                Salvar Alteracoes
              </.button>
            </div>
          </.form>
        </div>
        <!-- Notifications Tab -->
        <div :if={@active_tab == "notifications"} class="space-y-6">
          <div>
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Preferencias de Email</h3>
            <p class="text-sm text-gray-500 dark:text-gray-400">
              Escolha quais notificacoes deseja receber por email
            </p>
          </div>

          <.form for={@preferences_form} phx-submit="save_preferences" class="space-y-4">
            <.preference_toggle
              field={@preferences_form[:email_critical_alerts]}
              label="Alertas Criticos"
              description="Receba emails imediatos para alertas de alta severidade"
            />
            <.preference_toggle
              field={@preferences_form[:email_high_alerts]}
              label="Alertas de Alta Severidade"
              description="Notificacoes de alertas importantes"
            />
            <.preference_toggle
              field={@preferences_form[:email_analysis_complete]}
              label="Analise Concluida"
              description="Receba um email quando sua aula for analisada"
            />
            <.preference_toggle
              field={@preferences_form[:email_weekly_summary]}
              label="Resumo Semanal"
              description="Receba um resumo semanal das suas aulas"
            />

            <div class="border-t border-gray-200 dark:border-slate-700 pt-6 mt-6">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
                Notificacoes In-App
              </h3>
              <.preference_toggle
                field={@preferences_form[:inapp_all_alerts]}
                label="Todos os Alertas"
                description="Mostrar notificacoes de alertas na interface"
              />
              <.preference_toggle
                field={@preferences_form[:inapp_analysis_complete]}
                label="Analise Concluida"
                description="Notificar quando uma analise terminar"
              />
            </div>

            <div class="pt-4">
              <.button type="submit" phx-disable-with="Salvando...">
                Salvar Preferencias
              </.button>
            </div>
          </.form>
        </div>
        <!-- Security Tab -->
        <div :if={@active_tab == "security"} class="space-y-6">
          <div>
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Alterar Senha</h3>
            <p class="text-sm text-gray-500 dark:text-gray-400">
              Atualize sua senha regularmente para manter sua conta segura
            </p>
          </div>

          <form phx-submit="save_password" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Senha Atual
              </label>
              <input
                type="password"
                name="current_password"
                required
                class="w-full rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Nova Senha
              </label>
              <input
                type="password"
                name="new_password"
                required
                minlength="8"
                class="w-full rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
              />
              <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">Minimo de 8 caracteres</p>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Confirmar Nova Senha
              </label>
              <input
                type="password"
                name="confirm_password"
                required
                class="w-full rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
              />
            </div>

            <div class="pt-4">
              <.button type="submit" phx-disable-with="Alterando...">
                Alterar Senha
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # Component helpers

  defp tab_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="change_tab"
      phx-value-tab={@tab}
      class={[
        "flex items-center gap-2 py-4 px-1 border-b-2 font-medium text-sm transition-colors",
        if(@active,
          do: "border-indigo-500 text-indigo-600 dark:text-indigo-400",
          else:
            "border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:border-gray-300 dark:hover:border-slate-600"
        )
      ]}
    >
      <.icon name={@icon} class="h-5 w-5" />
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp preference_toggle(assigns) do
    ~H"""
    <div class="flex items-center justify-between py-3">
      <div>
        <label class="font-medium text-gray-900 dark:text-white"><%= @label %></label>
        <p class="text-sm text-gray-500 dark:text-gray-400"><%= @description %></p>
      </div>
      <label class="relative inline-flex items-center cursor-pointer">
        <input
          type="checkbox"
          name={@field.name}
          value="true"
          checked={Phoenix.HTML.Form.normalize_value("checkbox", @field.value)}
          class="sr-only peer"
        />
        <input type="hidden" name={@field.name} value="false" />
        <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-indigo-300 dark:peer-focus:ring-indigo-800 rounded-full peer dark:bg-slate-700 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-slate-600 peer-checked:bg-indigo-600">
        </div>
      </label>
    </div>
    """
  end

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
