defmodule HellenWeb.OnboardingLive do
  @moduledoc """
  Onboarding wizard for new users.
  Multi-step wizard to collect user preferences and introduce the platform.
  """
  use HellenWeb, :live_view

  alias Hellen.Accounts

  @subjects [
    {"Portugues", "portugues"},
    {"Matematica", "matematica"},
    {"Historia", "historia"},
    {"Geografia", "geografia"},
    {"Ciencias", "ciencias"},
    {"Biologia", "biologia"},
    {"Fisica", "fisica"},
    {"Quimica", "quimica"},
    {"Ingles", "ingles"},
    {"Artes", "artes"},
    {"Educacao Fisica", "educacao_fisica"},
    {"Filosofia", "filosofia"},
    {"Sociologia", "sociologia"},
    {"Outra", "outra"}
  ]

  @grade_levels [
    {"Educacao Infantil", "infantil"},
    {"1o ao 5o ano (Fund. I)", "fundamental_1"},
    {"6o ao 9o ano (Fund. II)", "fundamental_2"},
    {"Ensino Medio", "medio"},
    {"EJA", "eja"},
    {"Ensino Superior", "superior"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # If onboarding is already completed, redirect to dashboard
    if user.onboarding_completed do
      {:ok, push_navigate(socket, to: ~p"/dashboard")}
    else
      {:ok,
       socket
       |> assign(page_title: "Bem-vindo ao Hellen AI")
       |> assign(step: user.onboarding_step || 0)
       |> assign(subjects: @subjects)
       |> assign(grade_levels: @grade_levels)
       |> assign(selected_subject: user.subject)
       |> assign(selected_grade: user.grade_level)
       |> assign(saving: false)}
    end
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    new_step = min(socket.assigns.step + 1, 3)
    save_step(socket, new_step)
  end

  def handle_event("prev_step", _params, socket) do
    new_step = max(socket.assigns.step - 1, 0)
    {:noreply, assign(socket, step: new_step)}
  end

  def handle_event("select_subject", %{"subject" => subject}, socket) do
    {:noreply, assign(socket, selected_subject: subject)}
  end

  def handle_event("select_grade", %{"grade" => grade}, socket) do
    {:noreply, assign(socket, selected_grade: grade)}
  end

  def handle_event("complete_onboarding", _params, socket) do
    user = socket.assigns.current_user

    attrs = %{
      onboarding_completed: true,
      onboarding_step: 3,
      subject: socket.assigns.selected_subject,
      grade_level: socket.assigns.selected_grade
    }

    case Accounts.update_user_onboarding(user, attrs) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Bem-vindo ao Hellen AI! Sua conta esta pronta.")
         |> push_navigate(to: ~p"/dashboard")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Erro ao salvar. Tente novamente.")}
    end
  end

  def handle_event("skip_onboarding", _params, socket) do
    user = socket.assigns.current_user

    case Accounts.update_user_onboarding(user, %{onboarding_completed: true}) do
      {:ok, _user} ->
        {:noreply, push_navigate(socket, to: ~p"/dashboard")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Erro ao salvar. Tente novamente.")}
    end
  end

  defp save_step(socket, new_step) do
    user = socket.assigns.current_user

    attrs =
      %{onboarding_step: new_step}
      |> maybe_add_subject(socket.assigns.selected_subject)
      |> maybe_add_grade(socket.assigns.selected_grade)

    case Accounts.update_user_onboarding(user, attrs) do
      {:ok, _user} ->
        {:noreply, assign(socket, step: new_step)}

      {:error, _changeset} ->
        {:noreply, assign(socket, step: new_step)}
    end
  end

  defp maybe_add_subject(attrs, nil), do: attrs
  defp maybe_add_subject(attrs, subject), do: Map.put(attrs, :subject, subject)

  defp maybe_add_grade(attrs, nil), do: attrs
  defp maybe_add_grade(attrs, grade), do: Map.put(attrs, :grade_level, grade)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 via-white to-teal-50/30 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800 flex items-center justify-center p-4">
      <div class="w-full max-w-2xl">
        <!-- Progress Bar -->
        <div class="mb-8">
          <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
              Passo <%= @step + 1 %> de 4
            </span>
            <button
              phx-click="skip_onboarding"
              class="text-sm text-slate-500 hover:text-slate-700 dark:hover:text-slate-300 transition-colors"
            >
              Pular configuracao
            </button>
          </div>
          <div class="h-2 bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden">
            <div
              class="h-full bg-gradient-to-r from-teal-500 to-emerald-500 rounded-full transition-all duration-500 ease-out"
              style={"width: #{(@step + 1) * 25}%"}
            >
            </div>
          </div>
        </div>
        <!-- Card Container -->
        <div class="bg-white dark:bg-slate-800 rounded-3xl shadow-xl border border-slate-200/50 dark:border-slate-700/50 overflow-hidden">
          <!-- Step Content -->
          <div class="p-8 sm:p-10">
            <%= case @step do %>
              <% 0 -> %>
                <.step_welcome name={@current_user.name} />
              <% 1 -> %>
                <.step_subject subjects={@subjects} selected={@selected_subject} />
              <% 2 -> %>
                <.step_grade grade_levels={@grade_levels} selected={@selected_grade} />
              <% 3 -> %>
                <.step_tutorial />
            <% end %>
          </div>
          <!-- Navigation -->
          <div class="px-8 sm:px-10 pb-8 sm:pb-10 flex items-center justify-between">
            <button
              :if={@step > 0}
              phx-click="prev_step"
              class="inline-flex items-center gap-2 px-5 py-2.5 text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors"
            >
              <.icon name="hero-arrow-left" class="h-5 w-5" /> Voltar
            </button>
            <div :if={@step == 0}></div>

            <%= if @step < 3 do %>
              <button
                phx-click="next_step"
                class="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-teal-600 to-emerald-600 text-white font-semibold rounded-xl shadow-lg hover:shadow-xl hover:from-teal-500 hover:to-emerald-500 transition-all duration-200"
              >
                Continuar <.icon name="hero-arrow-right" class="h-5 w-5" />
              </button>
            <% else %>
              <button
                phx-click="complete_onboarding"
                class="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-teal-600 to-emerald-600 text-white font-semibold rounded-xl shadow-lg hover:shadow-xl hover:from-teal-500 hover:to-emerald-500 transition-all duration-200"
              >
                Comecar a usar <.icon name="hero-rocket-launch" class="h-5 w-5" />
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Step Components

  defp step_welcome(assigns) do
    ~H"""
    <div class="text-center">
      <!-- Animated Icon -->
      <div class="relative mx-auto w-24 h-24 mb-8">
        <div class="absolute inset-0 bg-gradient-to-br from-teal-400 to-emerald-500 rounded-3xl rotate-6 opacity-20">
        </div>
        <div class="relative w-full h-full bg-gradient-to-br from-teal-500 to-emerald-600 rounded-3xl flex items-center justify-center shadow-xl">
          <.icon name="hero-sparkles" class="h-12 w-12 text-white" />
        </div>
      </div>

      <h1 class="text-3xl sm:text-4xl font-bold text-slate-900 dark:text-white mb-4">
        Ola, <%= @name || "Professor" %>!
      </h1>
      <p class="text-lg text-slate-600 dark:text-slate-400 mb-8 max-w-md mx-auto">
        Bem-vindo ao <span class="font-semibold text-teal-600 dark:text-teal-400">Hellen AI</span>,
        sua assistente pedagogica com inteligencia artificial.
      </p>
      <!-- Features Preview -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 text-left">
        <div class="p-4 rounded-2xl bg-slate-50 dark:bg-slate-700/50">
          <div class="w-10 h-10 rounded-xl bg-teal-100 dark:bg-teal-900/50 flex items-center justify-center mb-3">
            <.icon name="hero-microphone" class="h-5 w-5 text-teal-600 dark:text-teal-400" />
          </div>
          <h3 class="font-semibold text-slate-900 dark:text-white text-sm mb-1">
            Transcricao Automatica
          </h3>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            Converta audio em texto em minutos
          </p>
        </div>
        <div class="p-4 rounded-2xl bg-slate-50 dark:bg-slate-700/50">
          <div class="w-10 h-10 rounded-xl bg-emerald-100 dark:bg-emerald-900/50 flex items-center justify-center mb-3">
            <.icon name="hero-document-check" class="h-5 w-5 text-emerald-600 dark:text-emerald-400" />
          </div>
          <h3 class="font-semibold text-slate-900 dark:text-white text-sm mb-1">
            Analise BNCC
          </h3>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            Alinhamento automatico com competencias
          </p>
        </div>
        <div class="p-4 rounded-2xl bg-slate-50 dark:bg-slate-700/50">
          <div class="w-10 h-10 rounded-xl bg-violet-100 dark:bg-violet-900/50 flex items-center justify-center mb-3">
            <.icon name="hero-shield-check" class="h-5 w-5 text-violet-600 dark:text-violet-400" />
          </div>
          <h3 class="font-semibold text-slate-900 dark:text-white text-sm mb-1">
            Deteccao de Bullying
          </h3>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            Ambiente escolar mais seguro
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp step_subject(assigns) do
    ~H"""
    <div>
      <div class="text-center mb-8">
        <div class="w-16 h-16 mx-auto rounded-2xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30 flex items-center justify-center mb-4">
          <.icon name="hero-academic-cap" class="h-8 w-8 text-teal-600 dark:text-teal-400" />
        </div>
        <h2 class="text-2xl font-bold text-slate-900 dark:text-white mb-2">
          Qual e sua disciplina principal?
        </h2>
        <p class="text-slate-600 dark:text-slate-400">
          Isso nos ajuda a personalizar suas analises
        </p>
      </div>

      <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
        <button
          :for={{label, value} <- @subjects}
          phx-click="select_subject"
          phx-value-subject={value}
          class={[
            "p-4 rounded-xl border-2 text-left transition-all duration-200",
            if(@selected == value,
              do: "border-teal-500 bg-teal-50 dark:bg-teal-900/30 ring-2 ring-teal-500/20",
              else:
                "border-slate-200 dark:border-slate-600 hover:border-slate-300 dark:hover:border-slate-500 hover:bg-slate-50 dark:hover:bg-slate-700/50"
            )
          ]}
        >
          <span class={[
            "font-medium text-sm",
            if(@selected == value,
              do: "text-teal-700 dark:text-teal-300",
              else: "text-slate-700 dark:text-slate-300"
            )
          ]}>
            <%= label %>
          </span>
        </button>
      </div>
    </div>
    """
  end

  defp step_grade(assigns) do
    ~H"""
    <div>
      <div class="text-center mb-8">
        <div class="w-16 h-16 mx-auto rounded-2xl bg-gradient-to-br from-emerald-100 to-cyan-100 dark:from-emerald-900/30 dark:to-cyan-900/30 flex items-center justify-center mb-4">
          <.icon name="hero-user-group" class="h-8 w-8 text-emerald-600 dark:text-emerald-400" />
        </div>
        <h2 class="text-2xl font-bold text-slate-900 dark:text-white mb-2">
          Para qual nivel voce leciona?
        </h2>
        <p class="text-slate-600 dark:text-slate-400">
          Ajustamos a analise para sua realidade
        </p>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <button
          :for={{label, value} <- @grade_levels}
          phx-click="select_grade"
          phx-value-grade={value}
          class={[
            "p-5 rounded-xl border-2 text-left transition-all duration-200",
            if(@selected == value,
              do:
                "border-emerald-500 bg-emerald-50 dark:bg-emerald-900/30 ring-2 ring-emerald-500/20",
              else:
                "border-slate-200 dark:border-slate-600 hover:border-slate-300 dark:hover:border-slate-500 hover:bg-slate-50 dark:hover:bg-slate-700/50"
            )
          ]}
        >
          <span class={[
            "font-medium",
            if(@selected == value,
              do: "text-emerald-700 dark:text-emerald-300",
              else: "text-slate-700 dark:text-slate-300"
            )
          ]}>
            <%= label %>
          </span>
        </button>
      </div>
    </div>
    """
  end

  defp step_tutorial(assigns) do
    ~H"""
    <div>
      <div class="text-center mb-8">
        <div class="w-16 h-16 mx-auto rounded-2xl bg-gradient-to-br from-violet-100 to-purple-100 dark:from-violet-900/30 dark:to-purple-900/30 flex items-center justify-center mb-4">
          <.icon name="hero-rocket-launch" class="h-8 w-8 text-violet-600 dark:text-violet-400" />
        </div>
        <h2 class="text-2xl font-bold text-slate-900 dark:text-white mb-2">
          Tudo pronto!
        </h2>
        <p class="text-slate-600 dark:text-slate-400">
          Veja como e facil usar o Hellen AI
        </p>
      </div>
      <!-- Quick Tutorial Steps -->
      <div class="space-y-4">
        <div class="flex items-start gap-4 p-4 rounded-xl bg-slate-50 dark:bg-slate-700/50">
          <div class="w-8 h-8 rounded-full bg-teal-600 text-white flex items-center justify-center flex-shrink-0 font-bold text-sm">
            1
          </div>
          <div>
            <h3 class="font-semibold text-slate-900 dark:text-white mb-1">
              Envie sua aula
            </h3>
            <p class="text-sm text-slate-600 dark:text-slate-400">
              Faca upload de um arquivo de audio (MP3, WAV, M4A) ou grave diretamente.
            </p>
          </div>
        </div>

        <div class="flex items-start gap-4 p-4 rounded-xl bg-slate-50 dark:bg-slate-700/50">
          <div class="w-8 h-8 rounded-full bg-emerald-600 text-white flex items-center justify-center flex-shrink-0 font-bold text-sm">
            2
          </div>
          <div>
            <h3 class="font-semibold text-slate-900 dark:text-white mb-1">
              Aguarde a analise
            </h3>
            <p class="text-sm text-slate-600 dark:text-slate-400">
              Nossa IA transcreve e analisa sua aula em poucos minutos.
            </p>
          </div>
        </div>

        <div class="flex items-start gap-4 p-4 rounded-xl bg-slate-50 dark:bg-slate-700/50">
          <div class="w-8 h-8 rounded-full bg-violet-600 text-white flex items-center justify-center flex-shrink-0 font-bold text-sm">
            3
          </div>
          <div>
            <h3 class="font-semibold text-slate-900 dark:text-white mb-1">
              Receba insights
            </h3>
            <p class="text-sm text-slate-600 dark:text-slate-400">
              Veja competencias BNCC, alertas de bullying e recomendacoes pedagogicas.
            </p>
          </div>
        </div>
      </div>
      <!-- Bonus -->
      <div class="mt-6 p-4 rounded-xl bg-gradient-to-r from-amber-50 to-orange-50 dark:from-amber-900/20 dark:to-orange-900/20 border border-amber-200/50 dark:border-amber-800/50">
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-xl bg-amber-100 dark:bg-amber-900/50 flex items-center justify-center flex-shrink-0">
            <.icon name="hero-gift" class="h-5 w-5 text-amber-600 dark:text-amber-400" />
          </div>
          <div>
            <p class="font-semibold text-amber-800 dark:text-amber-200">
              Voce ganhou 2 creditos de boas-vindas!
            </p>
            <p class="text-sm text-amber-700 dark:text-amber-300">
              Use para analisar suas primeiras aulas gratuitamente.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
