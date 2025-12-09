defmodule HellenWeb.LegalLive.SupportLive do
  @moduledoc """
  Support page for Hellen AI.
  Provides contact information and FAQ.
  """
  use HellenWeb, :live_view

  import HellenWeb.LandingComponents

  @whatsapp_number "5515997701743"
  @whatsapp_display "+55 15 99770-1743"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       whatsapp_number: @whatsapp_number,
       whatsapp_display: @whatsapp_display,
       expanded_faq: nil
     ), layout: {HellenWeb.Layouts, :landing}}
  end

  @impl true
  def handle_event("toggle_faq", %{"id" => id}, socket) do
    new_expanded =
      if socket.assigns.expanded_faq == id do
        nil
      else
        id
      end

    {:noreply, assign(socket, :expanded_faq, new_expanded)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <.landing_navbar />

      <main class="pt-24 pb-16">
        <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <!-- Header -->
          <div class="text-center mb-16">
            <div class="inline-flex items-center justify-center w-20 h-20 rounded-3xl bg-gradient-to-br from-emerald-500 to-teal-600 shadow-lg shadow-emerald-500/30 mb-6">
              <svg class="w-10 h-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192l-3.536 3.536M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z"
                />
              </svg>
            </div>
            <h1 class="text-4xl md:text-5xl font-bold text-slate-900 dark:text-white mb-4">
              Central de Suporte
            </h1>
            <p class="text-lg text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
              Estamos aqui para ajudar! Entre em contato conosco ou confira as perguntas frequentes.
            </p>
          </div>
          <!-- Contact Cards -->
          <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6 mb-16">
            <!-- WhatsApp Card -->
            <a
              href={"https://wa.me/#{@whatsapp_number}?text=Ol%C3%A1%21%20Preciso%20de%20ajuda%20com%20o%20Hellen%20AI."}
              target="_blank"
              rel="noopener noreferrer"
              class="group relative bg-gradient-to-br from-green-500 to-green-600 rounded-2xl p-6 text-white shadow-xl shadow-green-500/30 hover:shadow-2xl hover:shadow-green-500/40 transition-all duration-300 hover:-translate-y-1"
            >
              <div class="absolute top-4 right-4 w-12 h-12 rounded-full bg-white/20 flex items-center justify-center">
                <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
                </svg>
              </div>
              <div class="pr-16">
                <h3 class="text-xl font-bold mb-2">WhatsApp</h3>
                <p class="text-white/90 text-sm mb-4">
                  Atendimento rapido e direto pelo WhatsApp
                </p>
                <span class="inline-flex items-center gap-2 text-sm font-medium bg-white/20 rounded-full px-4 py-2">
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"
                    />
                  </svg>
                  <%= @whatsapp_display %>
                </span>
              </div>
              <div class="absolute bottom-0 right-0 opacity-10">
                <svg class="w-32 h-32" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
                </svg>
              </div>
            </a>
            <!-- Email Card -->
            <a
              href="mailto:suporte@hellen.ai"
              class="group relative bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200 dark:border-slate-700 shadow-xl hover:shadow-2xl transition-all duration-300 hover:-translate-y-1"
            >
              <div class="absolute top-4 right-4 w-12 h-12 rounded-full bg-teal-100 dark:bg-teal-900/50 flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-teal-600 dark:text-teal-400"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                  />
                </svg>
              </div>
              <div class="pr-16">
                <h3 class="text-xl font-bold text-slate-900 dark:text-white mb-2">E-mail</h3>
                <p class="text-slate-600 dark:text-slate-400 text-sm mb-4">
                  Para questoes mais detalhadas ou documentacao
                </p>
                <span class="inline-flex items-center gap-2 text-sm font-medium text-teal-600 dark:text-teal-400">
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                    />
                  </svg>
                  suporte@hellen.ai
                </span>
              </div>
            </a>
            <!-- Hours Card -->
            <div class="group relative bg-white dark:bg-slate-800 rounded-2xl p-6 border border-slate-200 dark:border-slate-700 shadow-xl md:col-span-2 lg:col-span-1">
              <div class="absolute top-4 right-4 w-12 h-12 rounded-full bg-amber-100 dark:bg-amber-900/50 flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-amber-600 dark:text-amber-400"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>
              <div class="pr-16">
                <h3 class="text-xl font-bold text-slate-900 dark:text-white mb-2">
                  Horario de Atendimento
                </h3>
                <p class="text-slate-600 dark:text-slate-400 text-sm mb-4">
                  Respondemos o mais rapido possivel
                </p>
                <div class="space-y-1 text-sm">
                  <p class="text-slate-700 dark:text-slate-300">
                    <span class="font-medium">Seg - Sex:</span> 09:00 - 18:00
                  </p>
                  <p class="text-slate-500 dark:text-slate-500">
                    Sabados, Domingos e Feriados: Fechado
                  </p>
                </div>
              </div>
            </div>
          </div>
          <!-- FAQ Section -->
          <div class="bg-white dark:bg-slate-900 rounded-2xl shadow-xl border border-slate-200 dark:border-slate-800 p-8 md:p-12">
            <div class="text-center mb-10">
              <h2 class="text-2xl md:text-3xl font-bold text-slate-900 dark:text-white mb-4">
                Perguntas Frequentes
              </h2>
              <p class="text-slate-600 dark:text-slate-400">
                Encontre respostas rapidas para as duvidas mais comuns
              </p>
            </div>

            <div class="max-w-3xl mx-auto space-y-4">
              <.faq_item
                id="faq-1"
                question="Como funciona o sistema de creditos?"
                expanded={@expanded_faq}
              >
                Cada analise de aula consome 1 credito. Voce pode adquirir pacotes de creditos na pagina de Billing. Ao criar uma nova aula e solicitar analise, 1 credito sera debitado. Caso ocorra alguma falha no processamento, o credito e automaticamente devolvido.
              </.faq_item>

              <.faq_item
                id="faq-2"
                question="Quais formatos de audio sao aceitos?"
                expanded={@expanded_faq}
              >
                Aceitamos os principais formatos de audio: MP3, WAV, M4A, OGG, WEBM e FLAC. O tamanho maximo por arquivo e de 200MB. Para melhores resultados, recomendamos gravacoes com boa qualidade de audio e minimo de ruido de fundo.
              </.faq_item>

              <.faq_item id="faq-3" question="Quanto tempo leva uma analise?" expanded={@expanded_faq}>
                O tempo de processamento varia de acordo com a duracao da aula. Em geral, uma aula de 50 minutos leva cerca de 5-10 minutos para ser transcrita e analisada. Voce recebera uma notificacao quando a analise estiver pronta.
              </.faq_item>

              <.faq_item id="faq-4" question="Meus dados estao seguros?" expanded={@expanded_faq}>
                Sim! Levamos a seguranca muito a serio. Todos os dados sao criptografados em transito e em repouso. As gravacoes sao armazenadas de forma segura e voce pode solicitar a exclusao a qualquer momento. Consulte nossa Politica de Privacidade para mais detalhes.
              </.faq_item>

              <.faq_item
                id="faq-5"
                question="Como a deteccao de bullying funciona?"
                expanded={@expanded_faq}
              >
                Nosso sistema de IA analisa o conteudo da transcricao em busca de padroes que possam indicar situacoes de bullying, conforme definido na Lei 13.185. Quando detectado, geramos um alerta com a severidade e o trecho relevante para que voce possa tomar as medidas necessarias.
              </.faq_item>

              <.faq_item
                id="faq-6"
                question="Posso cancelar minha conta e pedir reembolso?"
                expanded={@expanded_faq}
              >
                Voce pode cancelar sua conta a qualquer momento nas Configuracoes. Creditos nao utilizados nao sao reembolsaveis, porem permanecem disponiveis ate o cancelamento efetivo. Seus dados serao excluidos conforme nossa politica de retencao.
              </.faq_item>
            </div>
          </div>
          <!-- CTA Section -->
          <div class="mt-16 text-center">
            <p class="text-slate-600 dark:text-slate-400 mb-6">
              Nao encontrou o que procurava? Estamos aqui para ajudar!
            </p>
            <a
              href={"https://wa.me/#{@whatsapp_number}?text=Ol%C3%A1%21%20Preciso%20de%20ajuda%20com%20o%20Hellen%20AI."}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-3 px-8 py-4 bg-gradient-to-r from-green-500 to-green-600 text-white font-semibold rounded-xl shadow-lg shadow-green-500/30 hover:shadow-xl hover:shadow-green-500/40 transition-all duration-300 hover:-translate-y-0.5"
            >
              <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
              </svg>
              Falar pelo WhatsApp
            </a>
          </div>
        </div>
      </main>

      <.landing_footer />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :question, :string, required: true
  attr :expanded, :string, default: nil
  slot :inner_block, required: true

  defp faq_item(assigns) do
    ~H"""
    <div class="border border-slate-200 dark:border-slate-700 rounded-xl overflow-hidden">
      <button
        type="button"
        phx-click="toggle_faq"
        phx-value-id={@id}
        class="w-full flex items-center justify-between p-5 text-left bg-slate-50 dark:bg-slate-800/50 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
      >
        <span class="font-semibold text-slate-900 dark:text-white pr-4"><%= @question %></span>
        <svg
          class={[
            "w-5 h-5 text-slate-500 dark:text-slate-400 transition-transform duration-200 flex-shrink-0",
            @expanded == @id && "rotate-180"
          ]}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      <div class={[
        "overflow-hidden transition-all duration-200",
        @expanded == @id && "max-h-96",
        @expanded != @id && "max-h-0"
      ]}>
        <div class="p-5 pt-0 text-slate-600 dark:text-slate-400 leading-relaxed">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end
end
