defmodule HellenWeb.InstitutionLive.Teachers do
  @moduledoc """
  Teacher management for coordinators.
  List teachers with stats, invite new teachers, and manage roles.
  """
  use HellenWeb, :live_view

  alias Hellen.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    institution_id = user.institution_id

    if institution_id do
      {:ok,
       socket
       |> assign(page_title: "Equipe")
       |> assign(institution_id: institution_id)
       |> assign(filter_role: "all")
       |> assign(show_invite_modal: false)
       |> assign(show_remove_modal: false)
       |> assign(selected_teacher: nil)
       |> assign(invite_form: to_form(%{"name" => "", "email" => ""}))
       |> load_teachers_async(institution_id)}
    else
      {:ok,
       socket
       |> assign(page_title: "Equipe")
       |> assign(teachers: [])
       |> put_flash(:error, "Voce nao esta associado a nenhuma instituicao")}
    end
  end

  defp load_teachers_async(socket, institution_id) do
    if connected?(socket) do
      start_async(socket, :load_teachers, fn ->
        Accounts.list_teachers_with_stats(institution_id)
      end)
    else
      assign(socket, teachers: [])
    end
  end

  @impl true
  def handle_async(:load_teachers, {:ok, teachers}, socket) do
    {:noreply, assign(socket, teachers: teachers)}
  end

  def handle_async(:load_teachers, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(teachers: [])
     |> put_flash(:error, "Erro ao carregar professores")}
  end

  @impl true
  def handle_event("filter_role", %{"role" => role}, socket) do
    {:noreply, assign(socket, filter_role: role)}
  end

  def handle_event("open_invite_modal", _params, socket) do
    {:noreply, assign(socket, show_invite_modal: true)}
  end

  def handle_event("close_invite_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(show_invite_modal: false)
     |> assign(invite_form: to_form(%{"name" => "", "email" => ""}))}
  end

  def handle_event("invite_teacher", %{"name" => name, "email" => email}, socket) do
    institution_id = socket.assigns.institution_id

    case Accounts.invite_teacher_to_institution(institution_id, %{name: name, email: email}) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(show_invite_modal: false)
         |> assign(invite_form: to_form(%{"name" => "", "email" => ""}))
         |> put_flash(:info, "Professor convidado com sucesso!")
         |> load_teachers_async(institution_id)}

      {:error, changeset} ->
        errors = format_errors(changeset)

        {:noreply,
         socket
         |> put_flash(:error, "Erro ao convidar: #{errors}")}
    end
  end

  def handle_event("toggle_role", %{"id" => teacher_id}, socket) do
    teacher_data = Enum.find(socket.assigns.teachers, &(&1.user.id == teacher_id))

    if teacher_data do
      new_role = if teacher_data.user.role == "teacher", do: "coordinator", else: "teacher"

      case Accounts.update_user_role(teacher_data.user, new_role) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Permissao alterada com sucesso!")
           |> load_teachers_async(socket.assigns.institution_id)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erro ao alterar permissao")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("open_remove_modal", %{"id" => teacher_id}, socket) do
    teacher_data = Enum.find(socket.assigns.teachers, &(&1.user.id == teacher_id))

    {:noreply,
     socket
     |> assign(show_remove_modal: true)
     |> assign(selected_teacher: teacher_data)}
  end

  def handle_event("close_remove_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(show_remove_modal: false)
     |> assign(selected_teacher: nil)}
  end

  def handle_event("confirm_remove", _params, socket) do
    teacher_data = socket.assigns.selected_teacher

    if teacher_data do
      case Accounts.remove_teacher_from_institution(teacher_data.user) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> assign(show_remove_modal: false)
           |> assign(selected_teacher: nil)
           |> put_flash(:info, "Professor removido da instituicao")
           |> load_teachers_async(socket.assigns.institution_id)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erro ao remover professor")}
      end
    else
      {:noreply, socket}
    end
  end

  defp format_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end

  defp filtered_teachers(teachers, "all"), do: teachers
  defp filtered_teachers(teachers, role), do: Enum.filter(teachers, &(&1.user.role == role))

  @impl true
  def render(assigns) do
    filtered = filtered_teachers(assigns[:teachers] || [], assigns.filter_role)
    assigns = assign(assigns, :filtered_teachers, filtered)

    ~H"""
    <div class="space-y-6">
      <.page_header title="Equipe" description="Gerencie os professores da sua instituicao">
        <:actions>
          <.button phx-click="open_invite_modal">
            <.icon name="hero-plus" class="h-4 w-4 mr-2" /> Convidar Professor
          </.button>
        </:actions>
      </.page_header>
      <!-- Filters -->
      <div class="flex items-center gap-2">
        <span class="text-sm text-gray-500 dark:text-gray-400">Filtrar por:</span>
        <button
          :for={
            {value, label} <- [
              {"all", "Todos"},
              {"teacher", "Professores"},
              {"coordinator", "Coordenadores"}
            ]
          }
          type="button"
          phx-click="filter_role"
          phx-value-role={value}
          class={[
            "px-3 py-1.5 text-sm rounded-lg transition-colors",
            @filter_role == value &&
              "bg-indigo-100 dark:bg-indigo-900/50 text-indigo-700 dark:text-indigo-300 font-medium",
            @filter_role != value &&
              "bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-slate-600"
          ]}
        >
          <%= label %>
        </button>
      </div>
      <!-- Teachers List -->
      <div class="space-y-4">
        <.teacher_card
          :for={teacher <- @filtered_teachers}
          teacher={teacher}
          current_user={@current_user}
        />

        <.empty_state
          :if={length(@filtered_teachers) == 0 && length(@teachers) > 0}
          icon="hero-funnel"
          title="Nenhum resultado"
          description="Nenhum professor corresponde ao filtro selecionado."
        />

        <.empty_state
          :if={length(@teachers) == 0}
          icon="hero-users"
          title="Nenhum professor"
          description="Convide professores para sua instituicao."
        >
          <.button phx-click="open_invite_modal">
            <.icon name="hero-plus" class="h-4 w-4 mr-2" /> Convidar Professor
          </.button>
        </.empty_state>
      </div>
      <!-- Invite Modal -->
      <.modal
        :if={@show_invite_modal}
        id="invite-modal"
        show
        on_cancel={JS.push("close_invite_modal")}
      >
        <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
          Convidar Professor
        </h2>

        <.form for={@invite_form} phx-submit="invite_teacher" class="space-y-4">
          <.input field={@invite_form[:name]} type="text" label="Nome" required />
          <.input field={@invite_form[:email]} type="email" label="Email" required />

          <p class="text-sm text-gray-500 dark:text-gray-400">
            O professor recebera um convite para criar sua conta na plataforma.
          </p>

          <div class="flex justify-end gap-3 pt-4">
            <.button type="button" variant="ghost" phx-click="close_invite_modal">
              Cancelar
            </.button>
            <.button type="submit">
              Enviar Convite
            </.button>
          </div>
        </.form>
      </.modal>
      <!-- Remove Confirmation Modal -->
      <.modal
        :if={@show_remove_modal}
        id="remove-modal"
        show
        on_cancel={JS.push("close_remove_modal")}
      >
        <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
          Remover Professor
        </h2>

        <div class="space-y-4">
          <p class="text-gray-600 dark:text-gray-400">
            Tem certeza que deseja remover
            <span class="font-semibold text-gray-900 dark:text-white">
              <%= @selected_teacher && @selected_teacher.user.name %>
            </span>
            da instituicao?
          </p>
          <p class="text-sm text-gray-500 dark:text-gray-400">
            O professor perdera acesso aos recursos da instituicao, mas suas aulas serao mantidas.
          </p>

          <div class="flex justify-end gap-3 pt-4">
            <.button type="button" variant="ghost" phx-click="close_remove_modal">
              Cancelar
            </.button>
            <.button type="button" variant="danger" phx-click="confirm_remove">
              Remover
            </.button>
          </div>
        </div>
      </.modal>
    </div>
    """
  end

  defp teacher_card(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl border border-gray-200 dark:border-slate-700 p-4">
      <div class="flex items-start gap-4">
        <!-- Avatar -->
        <div class="flex-shrink-0">
          <div class="w-12 h-12 rounded-full bg-indigo-100 dark:bg-indigo-900/30 flex items-center justify-center">
            <span class="text-lg font-medium text-indigo-600 dark:text-indigo-400">
              <%= String.first(@teacher.user.name || "?") |> String.upcase() %>
            </span>
          </div>
        </div>
        <!-- Info -->
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2 flex-wrap">
            <h3 class="font-semibold text-gray-900 dark:text-white truncate">
              <%= @teacher.user.name || "Sem nome" %>
            </h3>
            <.role_badge role={@teacher.user.role} />
          </div>
          <p class="text-sm text-gray-500 dark:text-gray-400 truncate">
            <%= @teacher.user.email %>
          </p>
          <!-- Stats -->
          <div class="mt-2 flex items-center gap-4 text-sm text-gray-500 dark:text-gray-400">
            <span class="flex items-center gap-1">
              <.icon name="hero-academic-cap" class="h-4 w-4" />
              <%= @teacher.lessons_count %> aulas
            </span>
            <span class="flex items-center gap-1">
              <.icon name="hero-chart-bar" class="h-4 w-4" />
              <%= @teacher.analyses_count %> analises
            </span>
            <span :if={@teacher.avg_score} class="flex items-center gap-1">
              <.icon name="hero-star" class="h-4 w-4" /> Score: <%= @teacher.avg_score %>
            </span>
          </div>
          <!-- Last Activity -->
          <p :if={@teacher.last_activity} class="mt-1 text-xs text-gray-400 dark:text-gray-500">
            Ultima atividade: <%= format_relative_time(@teacher.last_activity) %>
          </p>
        </div>
        <!-- Actions -->
        <div :if={@teacher.user.id != @current_user.id} class="flex-shrink-0 flex items-center gap-2">
          <button
            type="button"
            phx-click="toggle_role"
            phx-value-id={@teacher.user.id}
            class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-slate-700 text-gray-500 dark:text-gray-400"
            title={
              if @teacher.user.role == "teacher", do: "Tornar coordenador", else: "Tornar professor"
            }
          >
            <.icon name="hero-arrow-path" class="h-5 w-5" />
          </button>
          <button
            type="button"
            phx-click="open_remove_modal"
            phx-value-id={@teacher.user.id}
            class="p-2 rounded-lg hover:bg-red-100 dark:hover:bg-red-900/30 text-gray-500 hover:text-red-600 dark:text-gray-400 dark:hover:text-red-400"
            title="Remover da instituicao"
          >
            <.icon name="hero-user-minus" class="h-5 w-5" />
          </button>
        </div>
        <!-- Self indicator -->
        <div :if={@teacher.user.id == @current_user.id} class="flex-shrink-0">
          <span class="px-2 py-1 text-xs font-medium rounded-full bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400">
            Voce
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp role_badge(assigns) do
    ~H"""
    <span class={[
      "px-2 py-0.5 text-xs font-medium rounded-full",
      @role == "coordinator" &&
        "bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-400",
      @role == "teacher" && "bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400",
      @role == "admin" && "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400"
    ]}>
      <%= role_label(@role) %>
    </span>
    """
  end

  defp role_label("coordinator"), do: "Coordenador"
  defp role_label("teacher"), do: "Professor"
  defp role_label("admin"), do: "Admin"
  defp role_label(_), do: "Desconhecido"

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "agora"
      diff < 3600 -> "ha #{div(diff, 60)} min"
      diff < 86_400 -> "ha #{div(diff, 3600)} h"
      diff < 604_800 -> "ha #{div(diff, 86_400)} d"
      true -> Calendar.strftime(datetime, "%d/%m/%Y")
    end
  end
end
