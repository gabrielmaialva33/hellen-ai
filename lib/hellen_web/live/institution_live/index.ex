defmodule HellenWeb.InstitutionLive.Index do
  @moduledoc """
  Coordinator Dashboard - Overview of institution statistics.
  Uses assign_async for non-blocking data loading and streams for activity feed.
  """
  use HellenWeb, :live_view

  alias Hellen.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    institution_id = user.institution_id

    if institution_id do
      institution = Accounts.get_institution!(institution_id)

      {:ok,
       socket
       |> assign(page_title: "Dashboard")
       |> assign(institution: institution)
       |> stream(:recent_activity, [])
       |> assign_async(:stats, fn -> load_stats(institution_id) end)
       |> assign_async(:chart_data, fn -> load_chart_data(institution_id) end)
       |> load_activity_async(institution_id)}
    else
      {:ok,
       socket
       |> assign(page_title: "Dashboard")
       |> assign(institution: nil)
       |> put_flash(:error, "Voce nao esta associado a nenhuma instituicao")}
    end
  end

  defp load_stats(institution_id) do
    stats = Accounts.get_institution_stats(institution_id)
    {:ok, %{stats: stats}}
  end

  defp load_chart_data(institution_id) do
    lessons_per_teacher = Accounts.get_lessons_per_teacher(institution_id)
    {:ok, %{lessons_per_teacher: lessons_per_teacher}}
  end

  defp load_activity_async(socket, institution_id) do
    if connected?(socket) do
      start_async(socket, :load_activity, fn ->
        Accounts.list_recent_institution_lessons(institution_id, limit: 10)
      end)
    else
      socket
    end
  end

  @impl true
  def handle_async(:load_activity, {:ok, lessons}, socket) do
    {:noreply, stream(socket, :recent_activity, lessons)}
  end

  def handle_async(:load_activity, {:exit, _reason}, socket) do
    {:noreply, put_flash(socket, :error, "Erro ao carregar atividade recente")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @institution do %>
        <!-- Header -->
        <.page_header title={@institution.name} description="Painel de acompanhamento da instituicao">
          <:actions>
            <.badge variant={plan_variant(@institution.plan)}>
              Plano <%= String.capitalize(@institution.plan || "free") %>
            </.badge>
          </:actions>
        </.page_header>
        <!-- Stats Cards -->
        <.async_result :let={data} assign={@stats}>
          <:loading>
            <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <.stat_skeleton :for={_ <- 1..4} />
            </div>
          </:loading>
          <:failed>
            <.alert variant="error">Erro ao carregar estatisticas</.alert>
          </:failed>

          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <.stat_card
              title="Professores"
              value={data.stats.teachers}
              icon="hero-users"
              variant="default"
            />
            <.stat_card
              title="Aulas"
              value={data.stats.lessons}
              icon="hero-academic-cap"
              variant="default"
            />
            <.stat_card
              title="Analises"
              value={data.stats.analyses}
              icon="hero-chart-bar"
              variant="success"
            />
            <.stat_card
              title="Alertas Pendentes"
              value={data.stats.alerts}
              icon="hero-bell-alert"
              variant={if data.stats.alerts > 0, do: "error", else: "default"}
            />
          </div>
          <!-- Score Overview -->
          <div :if={data.stats.avg_score} class="mt-4">
            <.card>
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm text-gray-500 dark:text-gray-400">Score Medio da Instituicao</p>
                  <p class="text-3xl font-bold text-gray-900 dark:text-white">
                    <%= data.stats.avg_score %><span class="text-lg text-gray-500">/10</span>
                  </p>
                </div>
                <div class={[
                  "p-3 rounded-full",
                  score_color_class(data.stats.avg_score)
                ]}>
                  <.icon name="hero-star" class="h-8 w-8 text-white" />
                </div>
              </div>
            </.card>
          </div>
        </.async_result>
        <!-- Charts Row -->
        <div class="grid gap-6 lg:grid-cols-2">
          <!-- Lessons per Teacher Chart -->
          <.card>
            <:header>
              <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
                Aulas por Professor
              </h2>
            </:header>
            <.async_result :let={data} assign={@chart_data}>
              <:loading>
                <div class="h-72 animate-pulse bg-gray-100 dark:bg-slate-700 rounded-lg"></div>
              </:loading>
              <:failed>
                <p class="text-gray-500 text-center py-8">Erro ao carregar grafico</p>
              </:failed>

              <div
                id="lessons-chart"
                phx-hook="CoordinatorBarChart"
                phx-update="ignore"
                data-chart-data={Jason.encode!(data.lessons_per_teacher)}
                class="h-72"
              >
              </div>
            </.async_result>
          </.card>
          <!-- Quick Actions -->
          <.card>
            <:header>
              <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
                Acoes Rapidas
              </h2>
            </:header>
            <div class="space-y-3">
              <.link
                navigate={~p"/institution/teachers"}
                class="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 dark:hover:bg-slate-700 transition-colors"
              >
                <div class="p-2 bg-indigo-100 dark:bg-indigo-900/30 rounded-lg">
                  <.icon name="hero-user-plus" class="h-5 w-5 text-indigo-600 dark:text-indigo-400" />
                </div>
                <div>
                  <p class="font-medium text-gray-900 dark:text-white">Gerenciar Equipe</p>
                  <p class="text-sm text-gray-500 dark:text-gray-400">
                    Convidar professores e gerenciar permissoes
                  </p>
                </div>
                <.icon name="hero-chevron-right" class="h-5 w-5 text-gray-400 ml-auto" />
              </.link>

              <.link
                navigate={~p"/alerts"}
                class="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 dark:hover:bg-slate-700 transition-colors"
              >
                <div class="p-2 bg-orange-100 dark:bg-orange-900/30 rounded-lg">
                  <.icon name="hero-bell-alert" class="h-5 w-5 text-orange-600 dark:text-orange-400" />
                </div>
                <div>
                  <p class="font-medium text-gray-900 dark:text-white">Ver Alertas</p>
                  <p class="text-sm text-gray-500 dark:text-gray-400">
                    Monitorar alertas de bullying e conformidade
                  </p>
                </div>
                <.icon name="hero-chevron-right" class="h-5 w-5 text-gray-400 ml-auto" />
              </.link>

              <.link
                navigate={~p"/institution/reports"}
                class="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 dark:hover:bg-slate-700 transition-colors"
              >
                <div class="p-2 bg-green-100 dark:bg-green-900/30 rounded-lg">
                  <.icon
                    name="hero-document-chart-bar"
                    class="h-5 w-5 text-green-600 dark:text-green-400"
                  />
                </div>
                <div>
                  <p class="font-medium text-gray-900 dark:text-white">Relatorios</p>
                  <p class="text-sm text-gray-500 dark:text-gray-400">
                    Gerar relatorios consolidados
                  </p>
                </div>
                <.icon name="hero-chevron-right" class="h-5 w-5 text-gray-400 ml-auto" />
              </.link>
            </div>
          </.card>
        </div>
        <!-- Recent Activity -->
        <.card>
          <:header>
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
                Atividade Recente
              </h2>
              <.link
                navigate={~p"/institution/teachers"}
                class="text-sm text-indigo-600 dark:text-indigo-400 hover:underline"
              >
                Ver todas
              </.link>
            </div>
          </:header>

          <div
            id="recent-activity"
            phx-update="stream"
            class="divide-y divide-gray-100 dark:divide-slate-700"
          >
            <div
              :for={{dom_id, lesson} <- @streams.recent_activity}
              id={dom_id}
              class="py-3 first:pt-0 last:pb-0"
            >
              <.activity_item lesson={lesson} />
            </div>
          </div>

          <.empty_state
            :if={Enum.empty?(@streams.recent_activity |> elem(1))}
            icon="hero-clipboard-document-list"
            title="Nenhuma atividade recente"
            description="As aulas dos professores aparecerao aqui."
          />
        </.card>
      <% else %>
        <!-- No Institution -->
        <.empty_state
          icon="hero-building-office"
          title="Sem instituicao vinculada"
          description="Voce precisa estar vinculado a uma instituicao para acessar o painel de coordenacao."
        />
      <% end %>
    </div>
    """
  end

  defp activity_item(assigns) do
    ~H"""
    <div class="flex items-center gap-4">
      <div class="flex-shrink-0">
        <div class="w-10 h-10 rounded-full bg-indigo-100 dark:bg-indigo-900/30 flex items-center justify-center">
          <span class="text-sm font-medium text-indigo-600 dark:text-indigo-400">
            <%= String.first(@lesson.user.name || "?") |> String.upcase() %>
          </span>
        </div>
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
          <%= @lesson.title || "Aula sem titulo" %>
        </p>
        <p class="text-sm text-gray-500 dark:text-gray-400">
          <%= @lesson.user.name || "Professor" %> - <%= format_relative_time(@lesson.inserted_at) %>
        </p>
      </div>
      <div class="flex-shrink-0">
        <.status_badge status={@lesson.status} />
      </div>
    </div>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "px-2 py-1 text-xs font-medium rounded-full",
      lesson_status_class(@status)
    ]}>
      <%= lesson_status_text(@status) %>
    </span>
    """
  end

  defp lesson_status_class("completed"),
    do: "bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400"

  defp lesson_status_class("analyzing"),
    do: "bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400"

  defp lesson_status_class("transcribing"),
    do: "bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-400"

  defp lesson_status_class("transcribed"),
    do: "bg-indigo-100 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-400"

  defp lesson_status_class("pending"),
    do: "bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400"

  defp lesson_status_class("failed"),
    do: "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400"

  defp lesson_status_class(_), do: "bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-400"

  defp lesson_status_text("completed"), do: "Concluida"
  defp lesson_status_text("analyzing"), do: "Analisando"
  defp lesson_status_text("transcribing"), do: "Transcrevendo"
  defp lesson_status_text("transcribed"), do: "Transcrita"
  defp lesson_status_text("pending"), do: "Pendente"
  defp lesson_status_text("failed"), do: "Falhou"
  defp lesson_status_text(_), do: "Desconhecido"

  defp plan_variant("enterprise"), do: "success"
  defp plan_variant("pro"), do: "processing"
  defp plan_variant(_), do: "default"

  defp score_color_class(score) when score >= 8, do: "bg-green-500"
  defp score_color_class(score) when score >= 6, do: "bg-yellow-500"
  defp score_color_class(_), do: "bg-red-500"

  defp stat_skeleton(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-gray-200 dark:border-slate-700 p-6 animate-pulse">
      <div class="flex items-center justify-between">
        <div class="space-y-2">
          <div class="h-4 w-20 bg-gray-200 dark:bg-slate-700 rounded"></div>
          <div class="h-8 w-12 bg-gray-200 dark:bg-slate-700 rounded"></div>
        </div>
        <div class="h-12 w-12 bg-gray-200 dark:bg-slate-700 rounded-full"></div>
      </div>
    </div>
    """
  end

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
