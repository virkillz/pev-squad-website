defmodule PevSquadWeb.RiderLive.Featured do
  use PevSquadWeb, :live_view

  alias PevSquad.Riders

  import PevSquadWeb.RiderComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:riders}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">03 / Verified &amp; seasoned</span>
          <span class="tag-scribble">earned it</span>
        </div>
        <h1 class="page-title lines-2">Featured<br />Riders</h1>
        <p class="page-intro">
          Featured Riders are seasoned members with the mileage and track record to back a star rating. They're the ones whose reviews carry the most weight across the squad.
        </p>
      </section>

      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">On the panel</span>
            <h2 class="section-title">The Riders</h2>
          </div>
        </div>
        <div :if={@riders != []} class="grid grid-3">
          <.rider_card :for={rider <- @riders} rider={rider} />
        </div>
        <p :if={@riders == []} class="section-lede">
          The panel is being picked. Check back soon.
        </p>
      </section>

      <section class="band band-orange">
        <div class="section-head">
          <div>
            <span class="eyebrow">How to get the badge</span>
            <h2 class="section-title">The Bar</h2>
          </div>
        </div>
        <div class="grid grid-3 grid-rule">
          <div class="pillar">
            <div class="pillar-num">01 / MILEAGE</div>
            <h3>5,000 km min</h3>
            <p>Verified riding history on at least one performance-class PEV.</p>
          </div>
          <div class="pillar">
            <div class="pillar-num">02 / TIME IN SQUAD</div>
            <h3>1 Year Active</h3>
            <p>Consistent participation in rides, meetups, and community discussion.</p>
          </div>
          <div class="pillar">
            <div class="pillar-num">03 / GEAR RANGE</div>
            <h3>Multiple Units</h3>
            <p>Enough hands-on time across brands to rate comparatively, not just personally.</p>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Featured Riders")
     |> assign(:riders, Riders.list_public_riders(featured: true))}
  end
end
