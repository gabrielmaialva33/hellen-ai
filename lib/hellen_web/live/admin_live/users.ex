defmodule HellenWeb.AdminLive.Users do
  @moduledoc """
  Admin Users Management - View and manage all users.
  """
  use HellenWeb, :live_view

  alias Hellen.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {users, total} = Accounts.list_all_users(page: 1, per_page: 20)
    institutions = Accounts.list_institutions()

    {:ok,
     socket
     |> assign(page_title: "Usuarios - Admin")
     |> assign(users: users)
     |> assign(total: total)
     |> assign(page: 1)
     |> assign(per_page: 20)
     |> assign(institutions: institutions)
     |> assign(filter_role: nil)
     |> assign(filter_plan: nil)
     |> assign(filter_institution: nil)
     |> assign(search: "")
     |> assign(show_modal: false)
     |> assign(selected_user: nil)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    role = if params["role"] == "", do: nil, else: params["role"]
    plan = if params["plan"] == "", do: nil, else: params["plan"]
    institution_id = if params["institution_id"] == "", do: nil, else: params["institution_id"]
    search = params["search"] || ""

    {users, total} =
      Accounts.list_all_users(
        page: 1,
        per_page: socket.assigns.per_page,
        role: role,
        plan: plan,
        institution_id: institution_id,
        search: search
      )

    {:noreply,
     socket
     |> assign(users: users)
     |> assign(total: total)
     |> assign(page: 1)
     |> assign(filter_role: role)
     |> assign(filter_plan: plan)
     |> assign(filter_institution: institution_id)
     |> assign(search: search)}
  end

  def handle_event("load_more", _params, socket) do
    next_page = socket.assigns.page + 1

    {users, _total} =
      Accounts.list_all_users(
        page: next_page,
        per_page: socket.assigns.per_page,
        role: socket.assigns.filter_role,
        plan: socket.assigns.filter_plan,
        institution_id: socket.assigns.filter_institution,
        search: socket.assigns.search
      )

    {:noreply,
     socket
     |> assign(users: socket.assigns.users ++ users)
     |> assign(page: next_page)}
  end

  def handle_event("edit_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:noreply, socket |> assign(show_modal: true) |> assign(selected_user: user)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false, selected_user: nil)}
  end

  def handle_event("update_user", params, socket) do
    user = socket.assigns.selected_user

    with {:ok, user} <- maybe_update_role(user, params["role"]),
         {:ok, user} <- maybe_update_plan(user, params["plan"]),
         {:ok, _user} <- maybe_update_institution(user, params["institution_id"]) do
      # Reload users list
      {users, total} =
        Accounts.list_all_users(
          page: 1,
          per_page: socket.assigns.per_page,
          role: socket.assigns.filter_role,
          plan: socket.assigns.filter_plan,
          institution_id: socket.assigns.filter_institution,
          search: socket.assigns.search
        )

      {:noreply,
       socket
       |> assign(users: users)
       |> assign(total: total)
       |> assign(page: 1)
       |> assign(show_modal: false)
       |> assign(selected_user: nil)
       |> put_flash(:info, "Usuario atualizado com sucesso!")}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao atualizar usuario")}
    end
  end

  def handle_event("add_credits", %{"user_id" => user_id, "amount" => amount_str}, socket) do
    user = Accounts.get_user!(user_id)
    amount = String.to_integer(amount_str)

    case Accounts.admin_add_user_credits(user, amount) do
      {:ok, _user} ->
        {users, total} =
          Accounts.list_all_users(
            page: 1,
            per_page: socket.assigns.per_page,
            role: socket.assigns.filter_role,
            plan: socket.assigns.filter_plan,
            institution_id: socket.assigns.filter_institution,
            search: socket.assigns.search
          )

        {:noreply,
         socket
         |> assign(users: users)
         |> assign(total: total)
         |> assign(page: 1)
         |> put_flash(:info, "#{amount} creditos adicionados!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao adicionar creditos")}
    end
  end

  defp maybe_update_role(user, role) when role in ["teacher", "coordinator", "admin"] do
    if user.role != role do
      Accounts.admin_update_user_role(user, role)
    else
      {:ok, user}
    end
  end

  defp maybe_update_role(user, _), do: {:ok, user}

  defp maybe_update_plan(user, plan) when plan in ["free", "pro", "enterprise"] do
    if user.plan != plan do
      Accounts.admin_update_user_plan(user, plan)
    else
      {:ok, user}
    end
  end

  defp maybe_update_plan(user, _), do: {:ok, user}

  defp maybe_update_institution(user, institution_id) do
    institution_id = if institution_id == "", do: nil, else: institution_id

    if user.institution_id != institution_id do
      Accounts.admin_assign_user_to_institution(user, institution_id)
    else
      {:ok, user}
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
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Usuarios</h1>
          </div>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
            <%= @total %> usuarios no total
          </p>
        </div>
      </div>
      <!-- Filters -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-4">
        <form phx-change="filter" class="flex flex-wrap gap-4">
          <div class="flex-1 min-w-[200px]">
            <input
              type="text"
              name="search"
              value={@search}
              placeholder="Buscar por nome ou email..."
              phx-debounce="300"
              class="w-full rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>
          <select
            name="role"
            class="rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
          >
            <option value="">Todos os cargos</option>
            <option value="teacher" selected={@filter_role == "teacher"}>Professor</option>
            <option value="coordinator" selected={@filter_role == "coordinator"}>Coordenador</option>
            <option value="admin" selected={@filter_role == "admin"}>Admin</option>
          </select>
          <select
            name="plan"
            class="rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
          >
            <option value="">Todos os planos</option>
            <option value="free" selected={@filter_plan == "free"}>Free</option>
            <option value="pro" selected={@filter_plan == "pro"}>Pro</option>
            <option value="enterprise" selected={@filter_plan == "enterprise"}>Enterprise</option>
          </select>
          <select
            name="institution_id"
            class="rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
          >
            <option value="">Todas instituicoes</option>
            <option
              :for={inst <- @institutions}
              value={inst.id}
              selected={@filter_institution == inst.id}
            >
              <%= inst.name %>
            </option>
          </select>
        </form>
      </div>
      <!-- Users Table -->
      <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-slate-700">
          <thead class="bg-gray-50 dark:bg-slate-900/50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Usuario
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Cargo
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Plano
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Creditos
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Instituicao
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Criado em
              </th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                Acoes
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200 dark:divide-slate-700">
            <tr :for={user <- @users} class="hover:bg-gray-50 dark:hover:bg-slate-700/50">
              <td class="px-6 py-4">
                <div class="flex items-center gap-3">
                  <div class="w-8 h-8 rounded-full bg-gradient-to-br from-indigo-500 to-purple-500 flex items-center justify-center text-white font-medium text-sm">
                    <%= String.first(user.name || "U") |> String.upcase() %>
                  </div>
                  <div>
                    <p class="text-sm font-medium text-gray-900 dark:text-white"><%= user.name %></p>
                    <p class="text-xs text-gray-500 dark:text-gray-400"><%= user.email %></p>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4">
                <.badge variant={role_variant(user.role)}><%= role_label(user.role) %></.badge>
              </td>
              <td class="px-6 py-4">
                <.badge variant={plan_variant(user.plan)}><%= plan_label(user.plan) %></.badge>
              </td>
              <td class="px-6 py-4 text-sm text-gray-700 dark:text-gray-300">
                <%= user.credits %>
              </td>
              <td class="px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                <%= (user.institution && user.institution.name) || "-" %>
              </td>
              <td class="px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                <%= Calendar.strftime(user.inserted_at, "%d/%m/%Y") %>
              </td>
              <td class="px-6 py-4 text-right">
                <button
                  phx-click="edit_user"
                  phx-value-id={user.id}
                  class="text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300 text-sm font-medium"
                >
                  Editar
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <div :if={Enum.empty?(@users)} class="p-8 text-center text-gray-500 dark:text-gray-400">
          Nenhum usuario encontrado
        </div>
        <!-- Load More -->
        <div :if={length(@users) < @total} class="p-4 border-t border-gray-200 dark:border-slate-700">
          <button
            phx-click="load_more"
            class="w-full py-2 text-sm font-medium text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300"
          >
            Carregar mais (<%= @total - length(@users) %> restantes)
          </button>
        </div>
      </div>
      <!-- Edit Modal -->
      <div
        :if={@show_modal && @selected_user}
        class="fixed inset-0 z-50 overflow-y-auto"
        aria-modal="true"
      >
        <div class="flex min-h-screen items-center justify-center p-4">
          <div class="fixed inset-0 bg-black/50" phx-click="close_modal"></div>
          <div class="relative bg-white dark:bg-slate-800 rounded-xl shadow-xl max-w-md w-full p-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Editar Usuario</h3>
              <button
                phx-click="close_modal"
                class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>
            </div>

            <div class="mb-4">
              <div class="flex items-center gap-3">
                <div class="w-12 h-12 rounded-full bg-gradient-to-br from-indigo-500 to-purple-500 flex items-center justify-center text-white font-medium text-lg">
                  <%= String.first(@selected_user.name || "U") |> String.upcase() %>
                </div>
                <div>
                  <p class="text-lg font-medium text-gray-900 dark:text-white">
                    <%= @selected_user.name %>
                  </p>
                  <p class="text-sm text-gray-500 dark:text-gray-400"><%= @selected_user.email %></p>
                </div>
              </div>
            </div>

            <form phx-submit="update_user" class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Cargo
                </label>
                <select
                  name="role"
                  class="w-full rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
                >
                  <option value="teacher" selected={@selected_user.role == "teacher"}>
                    Professor
                  </option>
                  <option value="coordinator" selected={@selected_user.role == "coordinator"}>
                    Coordenador
                  </option>
                  <option value="admin" selected={@selected_user.role == "admin"}>
                    Administrador
                  </option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Plano
                </label>
                <select
                  name="plan"
                  class="w-full rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
                >
                  <option value="free" selected={@selected_user.plan == "free"}>Free</option>
                  <option value="pro" selected={@selected_user.plan == "pro"}>Pro</option>
                  <option value="enterprise" selected={@selected_user.plan == "enterprise"}>
                    Enterprise
                  </option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Instituicao
                </label>
                <select
                  name="institution_id"
                  class="w-full rounded-lg border-gray-300 dark:border-slate-600 dark:bg-slate-700 dark:text-white focus:ring-indigo-500 focus:border-indigo-500"
                >
                  <option value="">Sem instituicao</option>
                  <option
                    :for={inst <- @institutions}
                    value={inst.id}
                    selected={@selected_user.institution_id == inst.id}
                  >
                    <%= inst.name %>
                  </option>
                </select>
              </div>

              <div class="border-t border-gray-200 dark:border-slate-700 pt-4">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Creditos atuais: <span class="font-bold"><%= @selected_user.credits %></span>
                </label>
                <div class="flex gap-2">
                  <button
                    type="button"
                    phx-click="add_credits"
                    phx-value-user_id={@selected_user.id}
                    phx-value-amount="5"
                    class="px-3 py-1 text-xs font-medium text-emerald-700 dark:text-emerald-400 bg-emerald-100 dark:bg-emerald-900/30 rounded-full hover:bg-emerald-200 dark:hover:bg-emerald-900/50"
                  >
                    +5
                  </button>
                  <button
                    type="button"
                    phx-click="add_credits"
                    phx-value-user_id={@selected_user.id}
                    phx-value-amount="10"
                    class="px-3 py-1 text-xs font-medium text-emerald-700 dark:text-emerald-400 bg-emerald-100 dark:bg-emerald-900/30 rounded-full hover:bg-emerald-200 dark:hover:bg-emerald-900/50"
                  >
                    +10
                  </button>
                  <button
                    type="button"
                    phx-click="add_credits"
                    phx-value-user_id={@selected_user.id}
                    phx-value-amount="50"
                    class="px-3 py-1 text-xs font-medium text-emerald-700 dark:text-emerald-400 bg-emerald-100 dark:bg-emerald-900/30 rounded-full hover:bg-emerald-200 dark:hover:bg-emerald-900/50"
                  >
                    +50
                  </button>
                </div>
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
                  Salvar Alteracoes
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp role_label("teacher"), do: "Professor"
  defp role_label("coordinator"), do: "Coordenador"
  defp role_label("admin"), do: "Admin"
  defp role_label(_), do: "Usuario"

  defp role_variant("coordinator"), do: "warning"
  defp role_variant("admin"), do: "error"
  defp role_variant(_), do: "default"

  defp plan_label("free"), do: "Free"
  defp plan_label("pro"), do: "Pro"
  defp plan_label("enterprise"), do: "Enterprise"
  defp plan_label(_), do: "Plano"

  defp plan_variant("pro"), do: "success"
  defp plan_variant("enterprise"), do: "processing"
  defp plan_variant(_), do: "default"
end
