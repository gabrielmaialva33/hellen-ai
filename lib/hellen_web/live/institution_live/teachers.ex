defmodule HellenWeb.InstitutionLive.Teachers do
  use HellenWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Professores")
     |> put_flash(:info, "Área de coordenadores em desenvolvimento")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="text-center py-12">
      <.icon name="hero-users" class="mx-auto h-16 w-16 text-gray-400" />
      <h2 class="mt-4 text-xl font-semibold text-gray-900">Gerenciar Professores</h2>
      <p class="mt-2 text-gray-500">Esta funcionalidade estará disponível em breve.</p>
    </div>
    """
  end
end
