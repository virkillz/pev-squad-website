defmodule PevSquadWeb.CommunityLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.{Events, Riders}

  import PevSquadWeb.RiderComponents

  @filters [
    {"All", nil},
    {"EUC", :euc},
    {"Scooter", :escooter},
    {"Esk8", :esk8},
    {"E-Bike", :ebike}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:community}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">02 / Who rides with us</span>
          <span class="tag-scribble">show up</span>
        </div>
        <h1 class="page-title">Community</h1>
        <p class="page-intro">
          PEV Squad is a collective of riders across Indonesia — mostly performance EUC, plus e-bikes and the occasional electric skateboard. Jakarta to Malang, Depok to Banjarnegara. No entry fee, just show up and ride.
        </p>
      </section>

      <div class="bleed">
        <img
          src={~p"/images/community.png"}
          alt="PEV Squad members and their EUCs and scooters gathered in a parking garage"
        />
      </div>

      <section class="band band-tight band-black">
        <div class="statbar">
          <div class="stat">
            <div class="stat-n">{@stats.riders}</div>
            <div class="stat-l">Riders on the roster</div>
          </div>
          <div class="stat">
            <div class="stat-n">{@stats.cities}</div>
            <div class="stat-l">Cities</div>
          </div>
          <div class="stat">
            <div class="stat-n">{@meetups_held}</div>
            <div class="stat-l">Meetups Held</div>
          </div>
          <div class="stat">
            <div class="stat-n">{@upcoming}</div>
            <div class="stat-l">Rides Coming Up</div>
          </div>
        </div>
      </section>

      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Rider roster</span>
            <h2 class="section-title">The Squad</h2>
            <p class="section-lede">
              From daily commuters to mountain offroaders. Riding with us? <.link
                navigate={~p"/users/profile"}
                class="link-orange"
              >Add your profile</.link>.
            </p>
          </div>
        </div>

        <div class="filters" style="margin-bottom:2rem;">
          <.link
            :for={{label, type} <- @filters}
            patch={if type, do: ~p"/community?type=#{type}", else: ~p"/community"}
            class={["filter-tag", @type == type && "active"]}
          >
            {label}
          </.link>
        </div>

        <div class="grid grid-3" id="roster">
          <.rider_card :for={rider <- @riders} rider={rider} />
        </div>
        <p :if={@riders == []} class="section-lede">No riders here yet.</p>
      </section>

      <section class="band band-orange">
        <div class="section-head">
          <div>
            <span class="eyebrow">Find us</span>
            <h2 class="section-title">Where We<br />Actually Talk</h2>
            <p class="section-lede">
              Our community lives on chat, not inboxes. Join the WhatsApp group to get in the loop on rides and drops.
            </p>
          </div>
          <a href="#" class="btn btn-solid" style="background:var(--black); color:var(--orange);">
            Join WhatsApp Group
          </a>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Community")
     |> assign(
       :page_description,
       "The riders of PEV Squad — EUC, scooter, esk8 and e-bike riders across Indonesia."
     )
     |> assign(:filters, @filters)
     |> assign(:stats, Riders.stats())
     |> assign(:meetups_held, length(Events.list_past_events(category: :official)))
     |> assign(:upcoming, length(Events.list_upcoming_events()))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    type = parse_type(params["type"])

    {:noreply,
     socket
     |> assign(:type, type)
     |> assign(
       :riders,
       Riders.list_public_riders(
         type: type,
         exclude_users: PevSquad.Safety.hidden_user_ids(socket.assigns.current_scope)
       )
     )}
  end

  defp parse_type(type) do
    Enum.find_value(@filters, fn {_label, t} -> t && to_string(t) == type && t end)
  end
end
