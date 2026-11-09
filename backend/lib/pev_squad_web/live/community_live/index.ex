defmodule PevSquadWeb.CommunityLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.{Events, Partners, Riders}

  import PevSquadWeb.RiderComponents
  import PevSquadWeb.PartnerComponents, only: [partner_card: 1]

  @per_page 9

  @filters [
    {"All", nil},
    {"EUC", :euc},
    {"Scooter", :escooter},
    {"Esk8", :esk8},
    {"E-Bike", :ebike}
  ]

  @sorts [
    {"A to Z", :az},
    {"Z to A", :za},
    {"Newest first", :newest},
    {"Oldest first", :oldest}
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

      <section class="band band-white" id="squad">
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

        <div class="filters" style="margin-bottom:1rem;">
          <.link
            :for={{label, type} <- @filters}
            patch={roster_path(@query, type: type, page: 1)}
            class={["filter-tag", @query.type == type && "active"]}
          >
            {label}
          </.link>
        </div>

        <form
          id="roster-controls"
          phx-change="roster"
          phx-submit="roster"
          class="roster-controls"
          role="search"
        >
          <label class="sr-only" for="roster-search">Search riders</label>
          <input
            id="roster-search"
            type="search"
            name="q"
            value={@query.q}
            placeholder="Search alias, city or ride"
            class="input"
            phx-debounce="300"
            autocomplete="off"
          />
          <label class="sr-only" for="roster-sort">Sort riders</label>
          <select id="roster-sort" name="sort" class="select">
            <option :for={{label, sort} <- @sorts} value={sort} selected={@query.sort == sort}>
              {label}
            </option>
          </select>
        </form>

        <div class="grid grid-3" id="roster">
          <.rider_card :for={rider <- @roster.entries} rider={rider} />
        </div>
        <p :if={@roster.entries == []} class="section-lede">
          {if @query.q != "", do: "No riders match “#{@query.q}”.", else: "No riders here yet."}
        </p>

        <nav :if={@roster.total_pages > 1} class="pager" id="roster-pager" aria-label="Roster pages">
          <span class="pager-count">
            {range_label(@roster)} of {@roster.total} riders
          </span>
          <div class="pager-links">
            <.link
              :if={@roster.page > 1}
              patch={roster_path(@query, page: @roster.page - 1)}
              class="filter-tag"
              rel="prev"
            >
              ← Prev
            </.link>
            <.link
              :for={n <- 1..@roster.total_pages}
              patch={roster_path(@query, page: n)}
              class={["filter-tag", n == @roster.page && "active"]}
              aria-current={n == @roster.page && "page"}
            >
              {String.pad_leading(to_string(n), 2, "0")}
            </.link>
            <.link
              :if={@roster.page < @roster.total_pages}
              patch={roster_path(@query, page: @roster.page + 1)}
              class="filter-tag"
              rel="next"
            >
              Next →
            </.link>
          </div>
        </nav>
      </section>

      <section :if={@communities != []} class="band band-black" id="partner-communities">
        <div class="section-head">
          <div>
            <span class="eyebrow">The network</span>
            <h2 class="section-title">Partner<br />Communities</h2>
            <p class="section-lede">
              Local crews and single-vehicle groups we ride with. They run their own group rides; we team up for the big ones and keep the PEV network connected across Indonesia.
            </p>
          </div>
        </div>
        <div class="grid grid-3">
          <.partner_card :for={partner <- @communities} partner={partner} />
        </div>
      </section>

      <section :if={@brands != []} class="band band-white" id="brand-partners">
        <div class="section-head">
          <div>
            <span class="eyebrow">Who backs the rides</span>
            <h2 class="section-title">Brand<br />Partners</h2>
            <p class="section-lede">
              Brands that have ridden, hosted, fed or filmed with us. Want to be on this list? Reach out on WhatsApp — if it's fun, we're in.
            </p>
          </div>
        </div>
        <div class="grid grid-3">
          <.partner_card :for={partner <- @brands} partner={partner} />
        </div>
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
       "The riders of PEV Squad — EUC, scooter, esk8 and e-bike riders across Indonesia — plus the communities and brands we ride with."
     )
     |> assign(:filters, @filters)
     |> assign(:sorts, @sorts)
     |> assign(:stats, Riders.stats())
     |> assign(:meetups_held, length(Events.list_past_events(category: :official)))
     |> assign(:upcoming, length(Events.list_upcoming_events()))
     |> assign(:communities, Partners.list_partners(:community))
     |> assign(:brands, Partners.list_partners(:brand))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = %{
      type: parse_type(params["type"]),
      sort: parse_sort(params["sort"]),
      q: params["q"] |> to_string() |> String.trim() |> String.slice(0, 60)
    }

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(
       :roster,
       Riders.paginate_public_riders(
         type: query.type,
         sort: query.sort,
         search: query.q,
         page: parse_page(params["page"]),
         per_page: @per_page,
         exclude_users: PevSquad.Safety.hidden_user_ids(socket.assigns.current_scope)
       )
     )}
  end

  @impl true
  def handle_event("roster", params, socket) do
    query = %{
      socket.assigns.query
      | q: String.trim(params["q"] || ""),
        sort: parse_sort(params["sort"])
    }

    # No #squad anchor here, so the page doesn't jump while someone types.
    path = query |> roster_path(page: 1) |> String.replace_suffix("#squad", "")
    {:noreply, push_patch(socket, to: path, replace: true)}
  end

  defp parse_page(page) do
    case Integer.parse(page || "") do
      {n, ""} when n > 0 -> n
      _ -> 1
    end
  end

  # Defaults (All, A to Z, no search, page 1) are left out of the URL;
  # #squad keeps the roster in view.
  defp roster_path(query, changes) do
    %{type: type, sort: sort, q: q} = Map.merge(query, Map.new(Keyword.delete(changes, :page)))
    page = Keyword.get(changes, :page, 1)

    params =
      Enum.reject(
        [type: type, sort: sort != :az && sort, q: q != "" && q, page: page != 1 && page],
        fn {_k, v} -> v in [nil, false] end
      )

    case params do
      [] -> "/community#squad"
      params -> "/community?" <> URI.encode_query(params) <> "#squad"
    end
  end

  defp range_label(%{page: page, per_page: per_page, entries: entries}) do
    first = (page - 1) * per_page + 1
    "#{first}–#{first + length(entries) - 1}"
  end

  defp parse_sort(sort) do
    Enum.find_value(@sorts, :az, fn {_label, s} -> to_string(s) == sort && s end)
  end

  defp parse_type(type) do
    Enum.find_value(@filters, fn {_label, t} -> t && to_string(t) == type && t end)
  end
end
