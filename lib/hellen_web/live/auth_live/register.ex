defmodule HellenWeb.AuthLive.Register do
  use HellenWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Redirect if already logged in
    if socket.assigns[:current_user] do
      {:ok, push_navigate(socket, to: ~p"/")}
    else
      {:ok, assign(socket, page_title: "Criar Conta", page_subtitle: "Cadastre-se para começar")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form action={~p"/session/register"} method="post" class="space-y-6">
      <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />

      <div>
        <label for="name" class="block text-sm font-medium text-gray-700">Nome</label>
        <input
          type="text"
          name="name"
          id="name"
          placeholder="Seu nome"
          required
          autocomplete="name"
          class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
        />
      </div>

      <div>
        <label for="email" class="block text-sm font-medium text-gray-700">Email</label>
        <input
          type="email"
          name="email"
          id="email"
          placeholder="seu@email.com"
          required
          autocomplete="email"
          class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
        />
      </div>

      <div>
        <label for="password" class="block text-sm font-medium text-gray-700">Senha</label>
        <input
          type="password"
          name="password"
          id="password"
          placeholder="Sua senha (min. 8 caracteres)"
          required
          minlength="8"
          autocomplete="new-password"
          class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
        />
      </div>

      <div>
        <.button type="submit" class="w-full">
          Criar Conta
        </.button>
      </div>
    </form>

    <div class="mt-6">
      <div class="relative">
        <div class="absolute inset-0 flex items-center">
          <div class="w-full border-t border-gray-300"></div>
        </div>
        <div class="relative flex justify-center text-sm">
          <span class="bg-white px-2 text-gray-500">Ou</span>
        </div>
      </div>

      <div class="mt-6 text-center">
        <p class="text-sm text-gray-600">
          Já tem uma conta?
          <.link navigate={~p"/login"} class="font-medium text-indigo-600 hover:text-indigo-500">
            Entrar
          </.link>
        </p>
      </div>
    </div>
    """
  end
end
