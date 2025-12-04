defmodule HellenWeb.InstitutionLive.Reports do
  @moduledoc """
  Reports placeholder for coordinator consolidated reports.
  """
  use HellenWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Relatorios")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.page_header title="Relatorios" description="Relatorios consolidados da instituicao" />

      <.card>
        <div class="text-center py-12">
          <div class="mx-auto w-16 h-16 bg-indigo-100 dark:bg-indigo-900/30 rounded-full flex items-center justify-center mb-4">
            <.icon
              name="hero-document-chart-bar"
              class="h-8 w-8 text-indigo-600 dark:text-indigo-400"
            />
          </div>
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
            Em breve
          </h3>
          <p class="mt-2 text-gray-500 dark:text-gray-400 max-w-md mx-auto">
            Esta funcionalidade permitira gerar relatorios consolidados com metricas da instituicao,
            desempenho dos professores e evolucao temporal.
          </p>
          <div class="mt-6 flex flex-wrap justify-center gap-3">
            <div class="px-4 py-2 bg-gray-100 dark:bg-slate-700 rounded-lg">
              <p class="text-sm font-medium text-gray-600 dark:text-gray-400">Relatorio Mensal</p>
            </div>
            <div class="px-4 py-2 bg-gray-100 dark:bg-slate-700 rounded-lg">
              <p class="text-sm font-medium text-gray-600 dark:text-gray-400">Export PDF</p>
            </div>
            <div class="px-4 py-2 bg-gray-100 dark:bg-slate-700 rounded-lg">
              <p class="text-sm font-medium text-gray-600 dark:text-gray-400">Analise BNCC</p>
            </div>
          </div>
        </div>
      </.card>
    </div>
    """
  end
end
