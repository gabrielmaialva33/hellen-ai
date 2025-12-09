defmodule HellenWeb.LandingLive do
  @moduledoc """
  Landing page LiveView for Hellen AI.
  Displays marketing content and converts visitors to users.
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
    <div class="min-h-screen" phx-hook="ScrollAnimation" id="landing-scroll">
      <.landing_navbar />

      <main>
        <.hero_section />
        <.impact_metrics />
        <.how_it_works />
        <.features_section />
        <.pricing_section />
        <.testimonials_section />
        <.faq_section />
        <.cta_section />
      </main>

      <.landing_footer />
    </div>
    """
  end
end
