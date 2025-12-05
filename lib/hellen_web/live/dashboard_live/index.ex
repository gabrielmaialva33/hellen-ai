defmodule HellenWeb.DashboardLive.Index do
  @moduledoc """
  Dashboard LiveView - Quick actions and overview.
  2025 Design with teal/sage color palette.

  Uses LiveView 1.1 patterns:
  - assign_async for stats (non-blocking)
  - streams for lesson list (memory efficient)
  """
  use HellenWeb, :live_view

  alias Hellen.Lessons

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(page_title: "Dashboard")
     |> assign(greeting: get_greeting())
     |> stream(:recent_lessons, [])
     |> assign_async(:stats, fn -> load_stats(user.id) end)
     |> load_lessons_async(user.id)}
  end

  defp load_lessons_async(socket, user_id) do
    if connected?(socket) do
      start_async(socket, :load_lessons, fn ->
        Lessons.list_lessons_by_user(user_id, limit: 5)
      end)
    else
      socket
    end
  end

  # PWA OfflineIndicator hook events - ignore silently
  @impl true
  def handle_event("online", _params, socket), do: {:noreply, socket}
  def handle_event("offline", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_async(:load_lessons, {:ok, lessons}, socket) do
    {:noreply, stream(socket, :recent_lessons, lessons)}
  end

  def handle_async(:load_lessons, {:exit, _reason}, socket) do
    {:noreply, put_flash(socket, :error, "Erro ao carregar aulas")}
  end

  defp load_stats(user_id) do
    lessons = Lessons.list_lessons_by_user(user_id)

    {:ok,
     %{
       stats: %{
         total: length(lessons),
         completed: Enum.count(lessons, &(&1.status == "completed")),
         processing:
           Enum.count(lessons, &(&1.status in ["transcribing", "analyzing", "transcribed"])),
         pending: Enum.count(lessons, &(&1.status == "pending"))
       }
     }}
  end

  defp get_greeting do
    hour = DateTime.utc_now() |> DateTime.to_time() |> Map.get(:hour)

    cond do
      hour >= 5 and hour < 12 -> "Bom dia"
      hour >= 12 and hour < 18 -> "Boa tarde"
      true -> "Boa noite"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8 animate-fade-in">
      <!-- Welcome Header -->
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900 dark:text-white tracking-tight">
            <%= @greeting %>, <%= @current_user.name || "Professor" %>!
          </h1>
          <p class="mt-1 text-slate-500 dark:text-slate-400">
            Bem-vindo ao Hellen AI. O que deseja fazer hoje?
          </p>
        </div>
        <div class="flex items-center gap-3">
          <.link navigate={~p"/lessons/new"}>
            <.button icon="hero-plus">
              Nova Aula
            </.button>
          </.link>
        </div>
      </div>

      <!-- Quick Actions -->
      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <.quick_action_card
          title="Nova Aula"
          description="Enviar gravacao para analise"
          icon="hero-plus-circle"
          href={~p"/lessons/new"}
          variant="primary"
        />

        <.quick_action_card
          title="Minhas Aulas"
          description="Ver todas as aulas"
          icon="hero-academic-cap"
          href={~p"/aulas"}
        />

        <.async_result :let={data} assign={@stats}>
          <:loading>
            <div class="bg-white dark:bg-slate-800 rounded-xl p-6 border border-slate-200 dark:border-slate-700 animate-pulse">
              <div class="flex items-center gap-4">
                <div class="h-14 w-14 bg-slate-200 dark:bg-slate-700 rounded-xl"></div>
                <div class="space-y-2">
                  <div class="h-5 w-24 bg-slate-200 dark:bg-slate-700 rounded"></div>
                  <div class="h-4 w-16 bg-slate-200 dark:bg-slate-700 rounded"></div>
                </div>
              </div>
            </div>
          </:loading>
          <:failed>
            <div class="bg-white dark:bg-slate-800 rounded-xl p-6 border border-slate-200 dark:border-slate-700">
              <p class="text-slate-500">Erro ao carregar</p>
            </div>
          </:failed>

          <.quick_action_card
            :if={data.pending > 0}
            title={"#{data.pending} Pendentes"}
            description="Aulas aguardando analise"
            icon="hero-clock"
            href={~p"/aulas?status=pending"}
            variant="highlight"
          />

          <.quick_action_card
            :if={data.pending == 0}
            title="Tudo em dia!"
            description="Nenhuma aula pendente"
            icon="hero-check-circle"
            href={~p"/aulas"}
          />
        </.async_result>
      </div>

      <!-- Stats Overview -->
      <.async_result :let={data} assign={@stats}>
        <:loading>
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <.stat_skeleton :for={_ <- 1..4} />
          </div>
        </:loading>
        <:failed>
          <.alert variant="error">Erro ao carregar estatisticas</.alert>
        </:failed>

        <div>
          <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
            Visao Geral
          </h2>
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <.stat_card
              title="Total de Aulas"
              value={data.total}
              icon="hero-academic-cap"
              subtitle="todas as aulas enviadas"
            />
            <.stat_card
              title="Concluidas"
              value={data.completed}
              icon="hero-check-circle"
              variant="success"
              subtitle="analises finalizadas"
            />
            <.stat_card
              title="Em Progresso"
              value={data.processing}
              icon="hero-arrow-path"
              variant="processing"
              subtitle="processando agora"
            />
            <.stat_card
              title="Pendentes"
              value={data.pending}
              icon="hero-clock"
              variant="pending"
              subtitle="aguardando inicio"
            />
          </div>
        </div>
      </.async_result>

      <!-- Recent Lessons -->
      <div>
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-slate-900 dark:text-white">
            Aulas Recentes
          </h2>
          <.link
            navigate={~p"/aulas"}
            class="text-sm font-medium text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300 transition-colors flex items-center gap-1"
          >
            Ver todas
            <.icon name="hero-arrow-right-mini" class="h-4 w-4" />
          </.link>
        </div>

        <div id="recent-lessons-container" phx-update="stream" class="space-y-3">
          <div
            :for={{dom_id, lesson} <- @streams.recent_lessons}
            id={dom_id}
            class="animate-fade-in-up"
            style={"animation-delay: #{Enum.find_index(Map.keys(@streams.recent_lessons), &(&1 == dom_id)) * 50}ms"}
          >
            <.lesson_card lesson={lesson} />
          </div>
        </div>

        <.empty_state
          :if={match?(%{ok?: true, result: %{total: 0}}, @stats)}
          icon="hero-document-text"
          title="Nenhuma aula ainda"
          description="Comece enviando sua primeira aula para analise pedagogica com IA."
        >
          <.link navigate={~p"/lessons/new"}>
            <.button icon="hero-plus">
              Criar Nova Aula
            </.button>
          </.link>
        </.empty_state>
      </div>

      <!-- Credits Card -->
      <div class="bg-gradient-to-br from-slate-800 to-slate-900 dark:from-slate-900 dark:to-slate-950 rounded-2xl p-6 text-white">
        <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl bg-teal-500/20 flex items-center justify-center">
              <.icon name="hero-bolt" class="h-6 w-6 text-teal-400" />
            </div>
            <div>
              <p class="text-slate-400 text-sm">Creditos disponiveis</p>
              <p class="text-3xl font-bold"><%= @current_user.credits || 0 %></p>
            </div>
          </div>
          <.link navigate={~p"/billing"}>
            <.button variant="secondary" class="bg-white/10 hover:bg-white/20 border-white/20 text-white">
              <.icon name="hero-shopping-cart" class="h-4 w-4 mr-2" />
              Comprar mais
            </.button>
          </.link>
        </div>
        <p class="mt-4 text-sm text-slate-400">
          Cada analise de aula consome 1 credito. <.link navigate={~p"/billing"} class="text-teal-400 hover:text-teal-300 underline">Ver planos</.link>
        </p>
      </div>
    </div>
    """
  end

  defp stat_skeleton(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-800 rounded-xl shadow-card border border-slate-200/50 dark:border-slate-700/50 p-6 animate-pulse">
      <div class="flex items-start justify-between">
        <div class="space-y-3 flex-1">
          <div class="h-4 w-20 bg-slate-200 dark:bg-slate-700 rounded"></div>
          <div class="h-8 w-12 bg-slate-200 dark:bg-slate-700 rounded"></div>
          <div class="h-3 w-24 bg-slate-200 dark:bg-slate-700 rounded"></div>
        </div>
        <div class="h-12 w-12 bg-slate-200 dark:bg-slate-700 rounded-xl"></div>
      </div>
    </div>
    """
  end
end
