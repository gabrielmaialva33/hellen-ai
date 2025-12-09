defmodule HellenWeb.LegalLive.PrivacyLive do
  @moduledoc """
  Privacy Policy page for Hellen AI.
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
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-violet-500 to-violet-600 shadow-lg shadow-violet-500/30 mb-6">
                <svg class="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                  />
                </svg>
              </div>
              <h1 class="text-3xl md:text-4xl font-bold text-slate-900 dark:text-white mb-4">
                Politica de Privacidade
              </h1>
              <p class="text-slate-600 dark:text-slate-400">
                Ultima atualizacao: <%= Date.utc_today() |> Calendar.strftime("%d de %B de %Y") %>
              </p>
            </div>

            <div class="prose prose-slate dark:prose-invert max-w-none">
              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-violet-100 dark:bg-violet-900/50 flex items-center justify-center text-violet-600 dark:text-violet-400 text-sm font-bold">
                    1
                  </span>
                  Introducao
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  A Hellen AI esta comprometida com a protecao da sua privacidade. Esta politica descreve como coletamos, usamos, armazenamos e protegemos suas informacoes pessoais em conformidade com a Lei Geral de Protecao de Dados (LGPD - Lei 13.709/2018).
                </p>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-violet-100 dark:bg-violet-900/50 flex items-center justify-center text-violet-600 dark:text-violet-400 text-sm font-bold">
                    2
                  </span>
                  Dados Coletados
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-4">
                  Coletamos os seguintes tipos de dados:
                </p>
                <div class="space-y-4 ml-4">
                  <div>
                    <h3 class="font-semibold text-slate-800 dark:text-slate-200 mb-2">
                      Dados de Cadastro:
                    </h3>
                    <ul class="list-disc list-inside text-slate-600 dark:text-slate-400 space-y-1">
                      <li>Nome completo</li>
                      <li>Endereco de e-mail</li>
                      <li>Instituicao de ensino (opcional)</li>
                      <li>Dados de autenticacao via Google/Firebase</li>
                    </ul>
                  </div>
                  <div>
                    <h3 class="font-semibold text-slate-800 dark:text-slate-200 mb-2">
                      Dados de Uso:
                    </h3>
                    <ul class="list-disc list-inside text-slate-600 dark:text-slate-400 space-y-1">
                      <li>Gravacoes de aulas enviadas para analise</li>
                      <li>Transcricoes geradas</li>
                      <li>Resultados de analises pedagogicas</li>
                      <li>Historico de transacoes de creditos</li>
                    </ul>
                  </div>
                </div>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-violet-100 dark:bg-violet-900/50 flex items-center justify-center text-violet-600 dark:text-violet-400 text-sm font-bold">
                    3
                  </span>
                  Finalidade do Tratamento
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-4">
                  Utilizamos seus dados para:
                </p>
                <ul class="list-disc list-inside text-slate-600 dark:text-slate-400 space-y-2 ml-4">
                  <li>Fornecer e melhorar nossos servicos de analise pedagogica</li>
                  <li>Processar transacoes de creditos</li>
                  <li>Enviar comunicacoes relevantes sobre o servico</li>
                  <li>Cumprir obrigacoes legais</li>
                  <li>Gerar insights agregados e anonimizados para melhoria da plataforma</li>
                </ul>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-violet-100 dark:bg-violet-900/50 flex items-center justify-center text-violet-600 dark:text-violet-400 text-sm font-bold">
                    4
                  </span>
                  Base Legal
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  O tratamento de dados e realizado com base no consentimento do usuario (Art. 7, I da LGPD) e na execucao de contrato (Art. 7, V da LGPD). Para dados sensiveis presentes em gravacoes, obtemos consentimento especifico.
                </p>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-violet-100 dark:bg-violet-900/50 flex items-center justify-center text-violet-600 dark:text-violet-400 text-sm font-bold">
                    5
                  </span>
                  Armazenamento e Seguranca
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-4">
                  Implementamos medidas tecnicas e organizacionais para proteger seus dados:
                </p>
                <ul class="list-disc list-inside text-slate-600 dark:text-slate-400 space-y-2 ml-4">
                  <li>Criptografia em transito (TLS/SSL) e em repouso</li>
                  <li>Armazenamento em servidores seguros (Cloudflare R2)</li>
                  <li>Controle de acesso baseado em funcoes</li>
                  <li>Monitoramento continuo de seguranca</li>
                  <li>Backups regulares com retencao adequada</li>
                </ul>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-violet-100 dark:bg-violet-900/50 flex items-center justify-center text-violet-600 dark:text-violet-400 text-sm font-bold">
                    6
                  </span>
                  Compartilhamento de Dados
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-4">
                  Podemos compartilhar dados com:
                </p>
                <ul class="list-disc list-inside text-slate-600 dark:text-slate-400 space-y-2 ml-4">
                  <li>
                    <strong>Processadores de IA:</strong>
                    NVIDIA e Groq para processamento de transcricao e analise
                  </li>
                  <li>
                    <strong>Processadores de pagamento:</strong> Stripe para transacoes de creditos
                  </li>
                  <li>
                    <strong>Autoridades:</strong> quando exigido por lei ou ordem judicial
                  </li>
                </ul>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed mt-4">
                  Nao vendemos nem compartilhamos seus dados para fins de marketing de terceiros.
                </p>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-violet-100 dark:bg-violet-900/50 flex items-center justify-center text-violet-600 dark:text-violet-400 text-sm font-bold">
                    7
                  </span>
                  Seus Direitos (LGPD)
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-4">
                  Como titular dos dados, voce tem direito a:
                </p>
                <ul class="list-disc list-inside text-slate-600 dark:text-slate-400 space-y-2 ml-4">
                  <li>Confirmar a existencia de tratamento de dados</li>
                  <li>Acessar seus dados pessoais</li>
                  <li>Corrigir dados incompletos ou desatualizados</li>
                  <li>Solicitar anonimizacao ou exclusao de dados</li>
                  <li>Solicitar portabilidade dos dados</li>
                  <li>Revogar o consentimento</li>
                </ul>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-violet-100 dark:bg-violet-900/50 flex items-center justify-center text-violet-600 dark:text-violet-400 text-sm font-bold">
                    8
                  </span>
                  Retencao de Dados
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Mantemos seus dados enquanto sua conta estiver ativa ou conforme necessario para fornecer servicos. Gravacoes de aulas sao mantidas por 90 dias apos a analise, podendo ser excluidas antecipadamente a pedido do usuario. Dados de transacoes sao mantidos conforme exigencias fiscais.
                </p>
              </section>

              <section class="mb-10">
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-violet-100 dark:bg-violet-900/50 flex items-center justify-center text-violet-600 dark:text-violet-400 text-sm font-bold">
                    9
                  </span>
                  Cookies
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Utilizamos cookies essenciais para funcionamento da plataforma (autenticacao e sessao). Nao utilizamos cookies de rastreamento ou publicidade.
                </p>
              </section>

              <section>
                <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                  <span class="w-8 h-8 rounded-lg bg-violet-100 dark:bg-violet-900/50 flex items-center justify-center text-violet-600 dark:text-violet-400 text-sm font-bold">
                    10
                  </span>
                  Contato do DPO
                </h2>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Para exercer seus direitos ou esclarecer duvidas sobre privacidade, entre em contato com nosso Encarregado de Protecao de Dados atraves da nossa <a
                    href="/support"
                    class="text-violet-600 dark:text-violet-400 hover:underline font-medium"
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
