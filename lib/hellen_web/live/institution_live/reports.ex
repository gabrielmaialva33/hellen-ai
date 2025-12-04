defmodule HellenWeb.InstitutionLive.Reports do
  @moduledoc """
  Reports page for coordinator - generates PDF reports.
  Supports monthly institution reports, teacher reports, and analysis exports.
  """
  use HellenWeb, :live_view

  alias Hellen.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    institution_id = user.institution_id

    if institution_id do
      teachers = Accounts.list_users_by_institution(institution_id)
      current_date = Date.utc_today()

      {:ok,
       socket
       |> assign(page_title: "Relatorios")
       |> assign(institution_id: institution_id)
       |> assign(teachers: teachers)
       |> assign(selected_type: nil)
       |> assign(selected_month: current_date.month)
       |> assign(selected_year: current_date.year)
       |> assign(selected_teacher_id: nil)
       |> assign(generating: false)}
    else
      {:ok,
       socket
       |> assign(page_title: "Relatorios")
       |> assign(teachers: [])
       |> put_flash(:error, "Voce nao esta associado a nenhuma instituicao")}
    end
  end

  @impl true
  def handle_event("select_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, selected_type: type)}
  end

  def handle_event("update_month", %{"month" => month}, socket) do
    {:noreply, assign(socket, selected_month: String.to_integer(month))}
  end

  def handle_event("update_year", %{"year" => year}, socket) do
    {:noreply, assign(socket, selected_year: String.to_integer(year))}
  end

  def handle_event("update_teacher", %{"teacher_id" => teacher_id}, socket) do
    {:noreply, assign(socket, selected_teacher_id: teacher_id)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply,
     socket
     |> assign(selected_type: nil)
     |> assign(selected_teacher_id: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.page_header title="Relatorios" description="Gere relatorios consolidados da sua instituicao" />

      <%= if @selected_type do %>
        <!-- Report Configuration -->
        <.card>
          <div class="space-y-6">
            <!-- Back button -->
            <button
              type="button"
              phx-click="clear_selection"
              class="flex items-center gap-2 text-sm text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300"
            >
              <.icon name="hero-arrow-left" class="h-4 w-4" />
              Voltar
            </button>

            <div class="flex items-center gap-4">
              <div class={[
                "p-3 rounded-xl",
                report_icon_bg(@selected_type)
              ]}>
                <.icon name={report_icon(@selected_type)} class="h-6 w-6 text-white" />
              </div>
              <div>
                <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
                  <%= report_title(@selected_type) %>
                </h2>
                <p class="text-sm text-gray-500 dark:text-gray-400">
                  <%= report_description(@selected_type) %>
                </p>
              </div>
            </div>

            <!-- Configuration Form -->
            <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <!-- Month Selection -->
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Mes
                </label>
                <select
                  phx-change="update_month"
                  name="month"
                  class="w-full rounded-lg border border-gray-300 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-gray-900 dark:text-white"
                >
                  <%= for {name, num} <- months() do %>
                    <option value={num} selected={@selected_month == num}><%= name %></option>
                  <% end %>
                </select>
              </div>

              <!-- Year Selection -->
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Ano
                </label>
                <select
                  phx-change="update_year"
                  name="year"
                  class="w-full rounded-lg border border-gray-300 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-gray-900 dark:text-white"
                >
                  <%= for year <- years() do %>
                    <option value={year} selected={@selected_year == year}><%= year %></option>
                  <% end %>
                </select>
              </div>

              <!-- Teacher Selection (for teacher report) -->
              <%= if @selected_type == "teacher" do %>
                <div>
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Professor
                  </label>
                  <select
                    phx-change="update_teacher"
                    name="teacher_id"
                    class="w-full rounded-lg border border-gray-300 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-gray-900 dark:text-white"
                  >
                    <option value="">Selecione um professor</option>
                    <%= for teacher <- @teachers do %>
                      <option value={teacher.id} selected={@selected_teacher_id == teacher.id}>
                        <%= teacher.name || teacher.email %>
                      </option>
                    <% end %>
                  </select>
                </div>
              <% end %>
            </div>

            <!-- Generate Button -->
            <div class="flex justify-end pt-4 border-t border-gray-100 dark:border-slate-700">
              <.link
                href={download_url(@selected_type, assigns)}
                target="_blank"
                class={[
                  "inline-flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors",
                  can_generate?(@selected_type, assigns) && "bg-indigo-600 hover:bg-indigo-700 text-white",
                  !can_generate?(@selected_type, assigns) && "bg-gray-200 dark:bg-slate-600 text-gray-400 dark:text-gray-500 cursor-not-allowed pointer-events-none"
                ]}
              >
                <.icon name="hero-document-arrow-down" class="h-5 w-5" />
                Gerar PDF
              </.link>
            </div>
          </div>
        </.card>
      <% else %>
        <!-- Report Type Selection -->
        <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <!-- Monthly Report -->
          <button
            type="button"
            phx-click="select_type"
            phx-value-type="monthly"
            class="group bg-white dark:bg-slate-800 rounded-xl border border-gray-200 dark:border-slate-700 p-6 text-left hover:border-indigo-300 dark:hover:border-indigo-600 hover:shadow-md transition-all"
          >
            <div class="flex items-start gap-4">
              <div class="p-3 bg-indigo-100 dark:bg-indigo-900/30 rounded-xl group-hover:bg-indigo-200 dark:group-hover:bg-indigo-900/50 transition-colors">
                <.icon
                  name="hero-chart-bar"
                  class="h-6 w-6 text-indigo-600 dark:text-indigo-400"
                />
              </div>
              <div>
                <h3 class="font-semibold text-gray-900 dark:text-white">Relatorio Mensal</h3>
                <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                  Visao geral da instituicao com metricas, ranking de professores e alertas.
                </p>
              </div>
            </div>
          </button>

          <!-- Teacher Report -->
          <button
            type="button"
            phx-click="select_type"
            phx-value-type="teacher"
            class="group bg-white dark:bg-slate-800 rounded-xl border border-gray-200 dark:border-slate-700 p-6 text-left hover:border-green-300 dark:hover:border-green-600 hover:shadow-md transition-all"
          >
            <div class="flex items-start gap-4">
              <div class="p-3 bg-green-100 dark:bg-green-900/30 rounded-xl group-hover:bg-green-200 dark:group-hover:bg-green-900/50 transition-colors">
                <.icon name="hero-user" class="h-6 w-6 text-green-600 dark:text-green-400" />
              </div>
              <div>
                <h3 class="font-semibold text-gray-900 dark:text-white">Relatorio do Professor</h3>
                <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                  Performance individual com historico de scores e competencias.
                </p>
              </div>
            </div>
          </button>

          <!-- Analysis Export (Coming Soon) -->
          <div class="bg-white dark:bg-slate-800 rounded-xl border border-gray-200 dark:border-slate-700 p-6 opacity-60">
            <div class="flex items-start gap-4">
              <div class="p-3 bg-purple-100 dark:bg-purple-900/30 rounded-xl">
                <.icon
                  name="hero-document-text"
                  class="h-6 w-6 text-purple-600 dark:text-purple-400"
                />
              </div>
              <div>
                <h3 class="font-semibold text-gray-900 dark:text-white">
                  Export de Analise
                  <span class="ml-2 text-xs font-normal text-gray-400">(via aula)</span>
                </h3>
                <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                  Acesse a pagina da aula para exportar uma analise especifica em PDF.
                </p>
              </div>
            </div>
          </div>
        </div>

        <!-- Info Card -->
        <.card>
          <div class="flex items-start gap-4">
            <div class="p-2 bg-blue-100 dark:bg-blue-900/30 rounded-lg">
              <.icon name="hero-information-circle" class="h-5 w-5 text-blue-600 dark:text-blue-400" />
            </div>
            <div>
              <h3 class="font-medium text-gray-900 dark:text-white">Sobre os Relatorios</h3>
              <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                Os relatorios sao gerados em formato PDF e incluem dados do periodo selecionado.
                Voce pode utiliza-los para apresentacoes, prestacao de contas e acompanhamento pedagogico.
              </p>
              <ul class="mt-3 space-y-1 text-sm text-gray-500 dark:text-gray-400">
                <li class="flex items-center gap-2">
                  <.icon name="hero-check" class="h-4 w-4 text-green-500" />
                  Metricas consolidadas da instituicao
                </li>
                <li class="flex items-center gap-2">
                  <.icon name="hero-check" class="h-4 w-4 text-green-500" />
                  Ranking de performance dos professores
                </li>
                <li class="flex items-center gap-2">
                  <.icon name="hero-check" class="h-4 w-4 text-green-500" />
                  Cobertura de competencias BNCC
                </li>
                <li class="flex items-center gap-2">
                  <.icon name="hero-check" class="h-4 w-4 text-green-500" />
                  Resumo de alertas de conformidade
                </li>
              </ul>
            </div>
          </div>
        </.card>
      <% end %>
    </div>
    """
  end

  # Helpers

  defp months do
    [
      {"Janeiro", 1},
      {"Fevereiro", 2},
      {"Marco", 3},
      {"Abril", 4},
      {"Maio", 5},
      {"Junho", 6},
      {"Julho", 7},
      {"Agosto", 8},
      {"Setembro", 9},
      {"Outubro", 10},
      {"Novembro", 11},
      {"Dezembro", 12}
    ]
  end

  defp years do
    current_year = Date.utc_today().year
    Enum.to_list((current_year - 2)..current_year)
  end

  defp report_title("monthly"), do: "Relatorio Mensal da Instituicao"
  defp report_title("teacher"), do: "Relatorio Individual do Professor"
  defp report_title(_), do: "Relatorio"

  defp report_description("monthly"),
    do: "Estatisticas gerais, ranking de professores e alertas do periodo."

  defp report_description("teacher"),
    do: "Performance, historico de scores e competencias BNCC do professor."

  defp report_description(_), do: ""

  defp report_icon("monthly"), do: "hero-chart-bar"
  defp report_icon("teacher"), do: "hero-user"
  defp report_icon(_), do: "hero-document"

  defp report_icon_bg("monthly"), do: "bg-indigo-600"
  defp report_icon_bg("teacher"), do: "bg-green-600"
  defp report_icon_bg(_), do: "bg-gray-600"

  defp can_generate?("teacher", assigns) do
    assigns.selected_teacher_id != nil && assigns.selected_teacher_id != ""
  end

  defp can_generate?(_, _), do: true

  defp download_url("monthly", assigns) do
    ~p"/reports/download/monthly?month=#{assigns.selected_month}&year=#{assigns.selected_year}"
  end

  defp download_url("teacher", assigns) do
    if assigns.selected_teacher_id do
      ~p"/reports/download/teacher/#{assigns.selected_teacher_id}?month=#{assigns.selected_month}&year=#{assigns.selected_year}"
    else
      "#"
    end
  end

  defp download_url(_, _), do: "#"
end
