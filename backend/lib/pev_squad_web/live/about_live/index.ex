defmodule PevSquadWeb.AboutLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.{Events, Partners, Riders}

  import PevSquadWeb.EventComponents, only: [kind_label: 1, date_block: 1]

  # Which past events illustrate each pillar.
  @speed_kinds [:race]
  @adventure_kinds [:tour, :getaway, :expedition, :trail_ride, :night_ride, :ride]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:about}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">07 / Who we are</span>
          <span class="tag-scribble">since 2023</span>
        </div>
        <h1 class="page-title">About</h1>
        <p class="page-intro">
          PEV Squad is a community of personal electric vehicle riders across Indonesia — EUCs, performance scooters, electric skateboards and e-bikes. We race, we tour, and we commute. And we team up with local communities and brands to put on events and grow the PEV scene nationwide.
        </p>
      </section>

      <section class="band band-black">
        <div class="section-head">
          <div>
            <span class="eyebrow">What we're about</span>
            <h2 class="section-title">Speed. Adventure.<br />Freedom.</h2>
            <p class="section-lede">
              Three things a personal electric vehicle does better than anything else on the road. Everything the squad does fits under one of them.
            </p>
          </div>
        </div>

        <div class="grid grid-3 grid-rule" id="pillars">
          <div class="pillar about-pillar" id="pillar-speed">
            <div class="pillar-num">01 / RACE</div>
            <h3>Speed</h3>
            <p>
              Races and competitions. Drag runs, cannonball races, mini drag strips at community booths — anywhere there's a start line and riders who want to find out what their machine actually does. Full gear, always.
            </p>
            <.pillar_events events={@speed_events} />
          </div>
          <div class="pillar about-pillar" id="pillar-adventure">
            <div class="pillar-num">02 / TOUR</div>
            <h3>Adventure</h3>
            <p>
              Touring and group rides. Night loops through the city, muddy trails in Bogor, weekend getaways and multi-day expeditions across Java. Members host their own group rides too — anyone can roll out.
            </p>
            <.pillar_events events={@adventure_events} />
            <.link navigate={~p"/events"} class="link-orange about-pillar-link">
              Upcoming rides →
            </.link>
          </div>
          <div class="pillar about-pillar" id="pillar-freedom">
            <div class="pillar-num">03 / COMMUTE</div>
            <h3>Freedom</h3>
            <p>
              PEVs as everyday transport. Ride to the station, take it with you on public transport, and ride the last mile — no traffic jams, no parking hunt, your own schedule. We want more people to know a PEV is a real way to get to work.
            </p>
            <.link navigate={~p"/reviews"} class="link-orange about-pillar-link">
              Find a commuter in the reviews →
            </.link>
          </div>
        </div>
      </section>

      <section class="band band-tight band-white">
        <div class="statbar" id="about-stats">
          <div class="stat">
            <div class="stat-n">{@stats.riders}</div>
            <div class="stat-l">Riders on the roster</div>
          </div>
          <div class="stat">
            <div class="stat-n">{@stats.cities}</div>
            <div class="stat-l">Cities</div>
          </div>
          <div class="stat">
            <div class="stat-n">{@events_held}</div>
            <div class="stat-l">Events held</div>
          </div>
          <div class="stat">
            <div class="stat-n">{@partner_count}</div>
            <div class="stat-l">Partner communities &amp; brands</div>
          </div>
        </div>
      </section>

      <section class="band band-black">
        <div class="section-head">
          <div>
            <span class="eyebrow">The network</span>
            <h2 class="section-title">Bigger Than<br />One Squad</h2>
            <p class="section-lede">
              Indonesia has plenty of PEV groups — local crews running their own group rides, and communities built around one kind of vehicle. We don't compete with them; we ride with them. Partner communities join our events and we join theirs, and together we bring brands to the riders.
            </p>
          </div>
        </div>
        <div class="grid grid-2 grid-rule">
          <.link navigate={~p"/community#partner-communities"} class="pillar about-pillar-cta">
            <div class="pillar-num">{count_label(@community_count, "COMMUNITY", "COMMUNITIES")}</div>
            <h3>Partner Communities</h3>
            <p>Local and vehicle-specific groups across Indonesia that ride with us.</p>
          </.link>
          <.link navigate={~p"/community#brand-partners"} class="pillar about-pillar-cta">
            <div class="pillar-num">{count_label(@brand_count, "BRAND", "BRANDS")}</div>
            <h3>Brand Partners</h3>
            <p>
              Brands that have ridden, hosted, fed or filmed with us — and reached PEV riders doing it.
            </p>
          </.link>
        </div>
      </section>

      <section class="band band-orange">
        <div class="section-head">
          <div>
            <span class="eyebrow">Get involved</span>
            <h2 class="section-title">Ride With Us</h2>
            <p class="section-lede">
              No entry fee, no minimum speed. Make a profile, RSVP to a ride, or bring us something fun to do — if it's fun, we're in.
            </p>
          </div>
          <div class="flex flex-wrap gap-3">
            <.link
              navigate={~p"/users/register"}
              class="btn btn-solid"
              style="background:var(--black); color:var(--orange);"
            >
              Join the Squad
            </.link>
            <.link navigate={~p"/#collaborate"} class="btn btn-outline">Collaborate</.link>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :events, :list, required: true

  defp pillar_events(assigns) do
    ~H"""
    <ul :if={@events != []} class="about-events">
      <li :for={event <- @events}>
        <.link navigate={~p"/events/#{event.slug}"}>
          <span class="about-event-date">{date_label(event)}</span>
          <span>{event.title}</span>
          <span class="about-event-kind">{kind_label(event.kind)}</span>
        </.link>
      </li>
    </ul>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    past = Events.list_past_events(category: :official)
    communities = Partners.list_partners(:community)
    brands = Partners.list_partners(:brand)

    {:ok,
     socket
     |> assign(:page_title, "About")
     |> assign(
       :page_description,
       "PEV Squad is Indonesia's personal electric vehicle community — speed (racing), adventure (touring and group rides) and freedom (commuting)."
     )
     |> assign(:stats, Riders.stats())
     |> assign(:events_held, length(past))
     |> assign(:speed_events, pick(past, @speed_kinds))
     |> assign(:adventure_events, pick(past, @adventure_kinds))
     |> assign(:community_count, length(communities))
     |> assign(:brand_count, length(brands))
     |> assign(:partner_count, length(communities) + length(brands))}
  end

  # The three most recent past events of these kinds.
  defp pick(events, kinds), do: events |> Enum.filter(&(&1.kind in kinds)) |> Enum.take(3)

  defp count_label(1, one, _many), do: "1 #{one}"
  defp count_label(n, _one, many), do: "#{n} #{many}"

  defp date_label(event) do
    %{m: m, y: y} = date_block(event)
    "#{m} #{y}"
  end
end
