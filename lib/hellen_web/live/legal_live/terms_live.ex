defmodule HellenWeb.LegalLive.TermsLive do
  @moduledoc """
  Terms of Service page for Hellen AI.
  """
  use HellenWeb, :live_view

  import HellenWeb.LandingComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, layout: {HellenWeb.Layouts, :landing}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <.landing_navbar />

      <main class="pt-24 pb-16">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="bg-white dark:bg-slate-900 rounded-2xl shadow-xl border border-slate-200 dark:border-slate-800 p-8 md:p-12">
            <div class="text-center mb-12">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-teal-500 to-teal-600 shadow-lg shadow-teal-500/30 mb-6">
                <svg class="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                  />
                </svg>
              </div>
              <h1 class="text-3xl md:text-4xl font-bold text-slate-900 dark:text-white mb-4">
                Termos de Uso
              </h1>
              <p class="text-slate-600 dark:text-slate-400">
                Ultima atualizacao: <%= Date.utc_today() |> Calendar.strftime("%d de %B de %Y") %>
              </p>
            </div>

            <div class="prose prose-slate dark:prose-invert max-w-none">
              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-900/50 flex items-center justify-center text-teal-600 dark:text-teal-400 text-sm font-bold">
                    1
                  </span>
                  Aceitacao dos Termos
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Ao acessar e utilizar a plataforma Hellen AI, voce concorda em cumprir e estar vinculado a estes Termos de Uso. Se voce nao concordar com qualquer parte destes termos, nao devera utilizar nossos servicos.
                </p>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-900/50 flex items-center justify-center text-teal-600 dark:text-teal-400 text-sm font-bold">
                    2
                  </span>
                  Descricao do Servico
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-4">
                  O Hellen AI e uma plataforma de analise pedagogica que utiliza inteligencia artificial para:
                </p>
                <ul class="list-disc list-inside text-slate-600 dark:text-slate-400 space-y-2 ml-4">
                  <li>Transcrever gravacoes de aulas</li>
                  <li>Analisar o conteudo pedagogico com base na BNCC</li>
                  <li>Identificar potenciais situacoes de bullying conforme a Lei 13.185</li>
                  <li>Gerar relatorios e recomendacoes pedagogicas</li>
                </ul>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-900/50 flex items-center justify-center text-teal-600 dark:text-teal-400 text-sm font-bold">
                    3
                  </span>
                  Cadastro e Conta
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Para utilizar o Hellen AI, voce deve criar uma conta fornecendo informacoes precisas e completas. Voce e responsavel por manter a confidencialidade de suas credenciais de acesso e por todas as atividades que ocorram em sua conta.
                </p>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-900/50 flex items-center justify-center text-teal-600 dark:text-teal-400 text-sm font-bold">
                    4
                  </span>
                  Sistema de Creditos
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-4">
                  O Hellen AI opera com um sistema de creditos:
                </p>
                <ul class="list-disc list-inside text-slate-600 dark:text-slate-400 space-y-2 ml-4">
                  <li>Cada analise de aula consome 1 credito</li>
                  <li>
                    Creditos podem ser adquiridos atraves de pacotes disponiveis na plataforma
                  </li>
                  <li>Creditos nao expiram e nao sao reembolsaveis</li>
                  <li>Em caso de falha na analise, os creditos sao automaticamente restituidos</li>
                </ul>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-900/50 flex items-center justify-center text-teal-600 dark:text-teal-400 text-sm font-bold">
                    5
                  </span>
                  Uso Aceitavel
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-4">
                  Voce concorda em nao utilizar o Hellen AI para:
                </p>
                <ul class="list-disc list-inside text-slate-600 dark:text-slate-400 space-y-2 ml-4">
                  <li>Fins ilegais ou nao autorizados</li>
                  <li>Violar direitos de propriedade intelectual</li>
                  <li>Transmitir conteudo ofensivo, difamatorio ou ilegal</li>
                  <li>Interferir no funcionamento da plataforma</li>
                  <li>Coletar dados de outros usuarios sem autorizacao</li>
                </ul>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-900/50 flex items-center justify-center text-teal-600 dark:text-teal-400 text-sm font-bold">
                    6
                  </span>
                  Propriedade Intelectual
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Todo o conteudo da plataforma Hellen AI, incluindo textos, graficos, logotipos, icones e software, e de propriedade da Hellen AI ou de seus licenciadores. O conteudo das aulas enviadas permanece de propriedade do usuario.
                </p>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-900/50 flex items-center justify-center text-teal-600 dark:text-teal-400 text-sm font-bold">
                    7
                  </span>
                  Limitacao de Responsabilidade
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  O Hellen AI e fornecido "como esta". Nao garantimos que o servico sera ininterrupto ou livre de erros. As analises geradas pela IA sao sugestoes e nao substituem o julgamento profissional do educador.
                </p>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-900/50 flex items-center justify-center text-teal-600 dark:text-teal-400 text-sm font-bold">
                    8
                  </span>
                  Alteracoes nos Termos
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Reservamo-nos o direito de modificar estes termos a qualquer momento. Alteracoes significativas serao comunicadas por e-mail ou atraves de aviso na plataforma. O uso continuado apos as alteracoes constitui aceitacao dos novos termos.
                </p>
              </section>

              <section>
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-teal-100 dark:bg-teal-900/50 flex items-center justify-center text-teal-600 dark:text-teal-400 text-sm font-bold">
                    9
                  </span>
                  Contato
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Para duvidas sobre estes termos, entre em contato atraves da nossa <a
                    href="/support"
                    class="text-teal-600 dark:text-teal-400 hover:underline font-medium"
                  >
                    pagina de suporte
                  </a>.
                </p>
              </section>
            </div>
          </div>
        </div>
      </main>

      <.landing_footer />
    </div>
    """
  end
end
