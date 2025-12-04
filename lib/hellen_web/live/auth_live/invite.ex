defmodule HellenWeb.AuthLive.Invite do
  @moduledoc """
  Invitation acceptance page - allows users to accept team invitations.
  """
  use HellenWeb, :live_view

  alias Hellen.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    invitation = Accounts.get_invitation_by_token(token)

    cond do
      is_nil(invitation) ->
        {:ok,
         socket
         |> assign(page_title: "Convite Invalido")
         |> assign(status: :not_found)
         |> assign(invitation: nil)}

      invitation.accepted_at ->
        {:ok,
         socket
         |> assign(page_title: "Convite ja Aceito")
         |> assign(status: :already_accepted)
         |> assign(invitation: invitation)}

      invitation.revoked_at ->
        {:ok,
         socket
         |> assign(page_title: "Convite Revogado")
         |> assign(status: :revoked)
         |> assign(invitation: invitation)}

      Hellen.Accounts.Invitation.expired?(invitation) ->
        {:ok,
         socket
         |> assign(page_title: "Convite Expirado")
         |> assign(status: :expired)
         |> assign(invitation: invitation)}

      true ->
        {:ok,
         socket
         |> assign(page_title: "Aceitar Convite")
         |> assign(status: :valid)
         |> assign(invitation: invitation)
         |> assign(token: token)
         |> assign(form: to_form(%{"name" => invitation.name || "", "password" => ""}))}
    end
  end

  @impl true
  def handle_event("accept_invitation", params, socket) do
    user_attrs = %{
      name: params["name"],
      email: socket.assigns.invitation.email,
      password: params["password"]
    }

    case Accounts.accept_invitation(socket.assigns.token, user_attrs) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Convite aceito! Faca login para continuar.")
         |> redirect(to: ~p"/login")}

      {:error, :already_accepted} ->
        {:noreply,
         socket
         |> assign(status: :already_accepted)
         |> put_flash(:error, "Este convite ja foi aceito.")}

      {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
        {:noreply, put_flash(socket, :error, "Erro ao criar conta. Verifique os dados.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Erro ao aceitar convite.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 px-4">
      <div class="w-full max-w-md">
        <!-- Invalid/Not Found -->
        <div
          :if={@status == :not_found}
          class="bg-white dark:bg-slate-800 rounded-2xl shadow-xl p-8 text-center"
        >
          <div class="w-16 h-16 mx-auto rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center mb-4">
            <.icon name="hero-x-circle" class="h-8 w-8 text-red-600 dark:text-red-400" />
          </div>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white mb-2">
            Convite nao encontrado
          </h1>
          <p class="text-gray-500 dark:text-gray-400 mb-6">
            Este link de convite e invalido ou nao existe.
          </p>
          <.link
            navigate={~p"/login"}
            class="inline-flex items-center px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700"
          >
            Ir para Login
          </.link>
        </div>
        <!-- Already Accepted -->
        <div
          :if={@status == :already_accepted}
          class="bg-white dark:bg-slate-800 rounded-2xl shadow-xl p-8 text-center"
        >
          <div class="w-16 h-16 mx-auto rounded-full bg-emerald-100 dark:bg-emerald-900/30 flex items-center justify-center mb-4">
            <.icon name="hero-check-circle" class="h-8 w-8 text-emerald-600 dark:text-emerald-400" />
          </div>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white mb-2">Convite ja aceito</h1>
          <p class="text-gray-500 dark:text-gray-400 mb-6">
            Este convite ja foi aceito. Faca login para acessar sua conta.
          </p>
          <.link
            navigate={~p"/login"}
            class="inline-flex items-center px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700"
          >
            Ir para Login
          </.link>
        </div>
        <!-- Revoked -->
        <div
          :if={@status == :revoked}
          class="bg-white dark:bg-slate-800 rounded-2xl shadow-xl p-8 text-center"
        >
          <div class="w-16 h-16 mx-auto rounded-full bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center mb-4">
            <.icon name="hero-no-symbol" class="h-8 w-8 text-amber-600 dark:text-amber-400" />
          </div>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white mb-2">Convite revogado</h1>
          <p class="text-gray-500 dark:text-gray-400 mb-6">
            Este convite foi cancelado pelo coordenador.
          </p>
          <.link
            navigate={~p"/login"}
            class="inline-flex items-center px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700"
          >
            Ir para Login
          </.link>
        </div>
        <!-- Expired -->
        <div
          :if={@status == :expired}
          class="bg-white dark:bg-slate-800 rounded-2xl shadow-xl p-8 text-center"
        >
          <div class="w-16 h-16 mx-auto rounded-full bg-gray-100 dark:bg-gray-900/30 flex items-center justify-center mb-4">
            <.icon name="hero-clock" class="h-8 w-8 text-gray-600 dark:text-gray-400" />
          </div>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white mb-2">Convite expirado</h1>
          <p class="text-gray-500 dark:text-gray-400 mb-6">
            Este convite expirou. Entre em contato com o coordenador para um novo convite.
          </p>
          <.link
            navigate={~p"/login"}
            class="inline-flex items-center px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700"
          >
            Ir para Login
          </.link>
        </div>
        <!-- Valid Invitation -->
        <div :if={@status == :valid} class="bg-white dark:bg-slate-800 rounded-2xl shadow-xl p-8">
          <div class="text-center mb-6">
            <div class="w-16 h-16 mx-auto rounded-full bg-indigo-100 dark:bg-indigo-900/30 flex items-center justify-center mb-4">
              <.icon name="hero-envelope-open" class="h-8 w-8 text-indigo-600 dark:text-indigo-400" />
            </div>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white mb-2">Voce foi convidado!</h1>
            <p class="text-gray-500 dark:text-gray-400">
              <%= (@invitation.invited_by && @invitation.invited_by.name) || "Um coordenador" %> convidou voce para participar de
            </p>
            <p class="text-lg font-semibold text-indigo-600 dark:text-indigo-400 mt-1">
              <%= @invitation.institution.name %>
            </p>
          </div>

          <div class="bg-gray-50 dark:bg-slate-900/50 rounded-lg p-4 mb-6">
            <div class="flex items-center justify-between text-sm">
              <span class="text-gray-500 dark:text-gray-400">Email</span>
              <span class="font-medium text-gray-900 dark:text-white"><%= @invitation.email %></span>
            </div>
            <div class="flex items-center justify-between text-sm mt-2">
              <span class="text-gray-500 dark:text-gray-400">Cargo</span>
              <span class="font-medium text-gray-900 dark:text-white">
                <%= role_label(@invitation.role) %>
              </span>
            </div>
            <div class="flex items-center justify-between text-sm mt-2">
              <span class="text-gray-500 dark:text-gray-400">Expira em</span>
              <span class="font-medium text-gray-900 dark:text-white">
                <%= format_expires(@invitation.expires_at) %>
              </span>
            </div>
          </div>

          <form phx-submit="accept_invitation" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Seu nome
              </label>
              <input
                type="text"
                name="name"
                required
                value={@invitation.name || ""}
                class="w-full rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
                placeholder="Nome completo"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Criar senha
              </label>
              <input
                type="password"
                name="password"
                required
                minlength="8"
                class="w-full rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
                placeholder="Minimo 8 caracteres"
              />
            </div>

            <button
              type="submit"
              class="w-full py-3 px-4 bg-indigo-600 text-white font-medium rounded-lg hover:bg-indigo-700 transition-colors"
            >
              Aceitar Convite e Criar Conta
            </button>
          </form>

          <p class="mt-4 text-center text-sm text-gray-500 dark:text-gray-400">
            Ja tem uma conta?
            <.link navigate={~p"/login"} class="text-indigo-600 dark:text-indigo-400 hover:underline">
              Faca login
            </.link>
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp role_label("teacher"), do: "Professor"
  defp role_label("coordinator"), do: "Coordenador"
  defp role_label(_), do: "Usuario"

  defp format_expires(datetime) do
    diff = DateTime.diff(datetime, DateTime.utc_now(), :day)

    cond do
      diff <= 0 -> "Hoje"
      diff == 1 -> "Amanha"
      true -> "#{diff} dias"
    end
  end
end
