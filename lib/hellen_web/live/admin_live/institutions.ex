defmodule HellenWeb.AdminLive.Institutions do
  @moduledoc """
  Admin Institutions Management - View and manage all institutions.
  """
  use HellenWeb, :live_view

  alias Hellen.Accounts

  @impl true
  def mount(_params, _session, socket) do
    institutions = Accounts.list_institutions_with_stats()

    {:ok,
     socket
     |> assign(page_title: "Instituicoes - Admin")
     |> assign(institutions: institutions)
     |> assign(show_modal: false)
     |> assign(selected_institution: nil)
     |> assign(form: to_form(%{"name" => "", "slug" => ""}))}
  end

  @impl true
  def handle_event("show_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(show_modal: true)
     |> assign(selected_institution: nil)
     |> assign(form: to_form(%{"name" => "", "slug" => ""}))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false, selected_institution: nil)}
  end

  def handle_event("create_institution", %{"name" => name, "slug" => slug}, socket) do
    case Accounts.create_institution(%{name: name, slug: slug}) do
      {:ok, _institution} ->
        institutions = Accounts.list_institutions_with_stats()

        {:noreply,
         socket
         |> assign(institutions: institutions)
         |> assign(show_modal: false)
         |> put_flash(:info, "Instituicao criada com sucesso!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Erro ao criar instituicao")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <div class="flex items-center gap-2">
            <.link
              navigate={~p"/admin"}
              class="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
            >
              <.icon name="hero-arrow-left" class="h-5 w-5" />
            </.link>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Instituicoes</h1>
          </div>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
            Gerenciar todas as instituicoes da plataforma
          </p>
        </div>
        <button
          phx-click="show_create_modal"
          class="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700"
        >
          <.icon name="hero-plus" class="h-4 w-4 inline mr-1" /> Nova Instituicao
        </button>
      </div>
      <!-- Institutions Table -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-slate-700">
          <thead class="bg-gray-50 dark:bg-slate-900/50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Instituicao
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Usuarios
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Aulas
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Analises
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Criada em
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 dark:divide-slate-700">
            <tr :for={item <- @institutions} class="hover:bg-gray-50 dark:hover:bg-slate-700/50">
              <td class="px-6 py-4">
                <div>
                  <p class="text-sm font-medium text-gray-900 dark:text-white">
                    <%= item.institution.name %>
                  </p>
                  <p class="text-xs text-gray-500 dark:text-gray-400"><%= item.institution.slug %></p>
                </div>
              </td>
              <td class="px-6 py-4 text-sm text-gray-700 dark:text-gray-300">
                <%= item.users_count %>
              </td>
              <td class="px-6 py-4 text-sm text-gray-700 dark:text-gray-300">
                <%= item.lessons_count %>
              </td>
              <td class="px-6 py-4 text-sm text-gray-700 dark:text-gray-300">
                <%= item.analyses_count %>
              </td>
              <td class="px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                <%= Calendar.strftime(item.institution.inserted_at, "%d/%m/%Y") %>
              </td>
            </tr>
          </tbody>
        </table>

        <div :if={Enum.empty?(@institutions)} class="p-8 text-center text-gray-500 dark:text-gray-400">
          Nenhuma instituicao cadastrada
        </div>
      </div>
      <!-- Create Modal -->
      <div :if={@show_modal} class="fixed inset-0 z-50 overflow-y-auto" aria-modal="true">
        <div class="flex min-h-screen items-center justify-center p-4">
          <div class="fixed inset-0 bg-black/50" phx-click="close_modal"></div>
          <div class="relative bg-white dark:bg-slate-800 rounded-xl shadow-xl max-w-md w-full p-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Nova Instituicao</h3>
              <button
                phx-click="close_modal"
                class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>
            </div>

            <form phx-submit="create_institution" class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Nome
                </label>
                <input
                  type="text"
                  name="name"
                  required
                  class="w-full rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
                  placeholder="Nome da instituicao"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Slug
                </label>
                <input
                  type="text"
                  name="slug"
                  required
                  pattern="[a-z0-9-]+"
                  class="w-full rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
                  placeholder="nome-da-instituicao"
                />
                <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                  Apenas letras minusculas, numeros e hifens
                </p>
              </div>
              <div class="flex justify-end gap-3 pt-4">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-200 bg-gray-100 dark:bg-slate-700 rounded-lg hover:bg-gray-200 dark:hover:bg-slate-600"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  class="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700"
                >
                  Criar Instituicao
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
