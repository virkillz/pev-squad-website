defmodule PevSquadWeb.ListingLive.Index do
  @moduledoc "The public For Sale board."
  use PevSquadWeb, :live_view

  alias PevSquad.Listings
  alias PevSquad.Listings.Listing

  import PevSquadWeb.ListingComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:for_sale}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">05 / {gettext("Member marketplace")}</span>
          <span class="tag-scribble">{gettext("still rolling")}</span>
        </div>
        <h1 class="page-title">{gettext("For Sale")}</h1>
        <p class="page-intro">
          {gettext(
            "Wheels, scooters, boards, parts and gear from riders in the squad. Every listing is checked by a moderator, and sellers confirm each week that it's still available, so what you see here is really for sale. Deal directly with the seller; PEV Squad doesn't handle payments."
          )}
        </p>
      </section>

      <section class="band band-black">
        <div class="section-head">
          <div>
            <span class="eyebrow">
              {ngettext("1 listing", "%{count} listings", length(@listings))}
            </span>
            <h2 class="section-title">{gettext("On the board")}</h2>
          </div>
          <div class="flex flex-wrap gap-3">
            <.link :if={@current_scope} navigate={~p"/for-sale/mine"} class="btn btn-outline">
              {gettext("My listings")}
            </.link>
            <.link navigate={~p"/for-sale/new"} class="btn btn-solid">
              {gettext("Sell something")}
            </.link>
          </div>
        </div>

        <div class="filters">
          <.link
            patch={~p"/for-sale"}
            class={["filter-tag", is_nil(@category) && "active"]}
          >
            {gettext("All")}
          </.link>
          <.link
            :for={{label, key} <- category_options()}
            patch={~p"/for-sale?category=#{key}"}
            class={["filter-tag", @category == key && "active"]}
          >
            {label}
          </.link>
        </div>

        <div :if={@listings != []} class="listing-grid" id="listings">
          <.listing_card :for={listing <- @listings} listing={listing} now={@now} />
        </div>
        <p :if={@listings == []} class="section-lede" id="no-listings">
          {gettext("Nothing for sale here right now. Got something to sell?")}
        </p>
      </section>

      <section :if={@sold != []} class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">
              {gettext("Last %{count} days", count: Listings.sold_visible_days())}
            </span>
            <h2 class="section-title">{gettext("Recently sold")}</h2>
          </div>
        </div>
        <div class="listing-grid" id="sold-listings">
          <.listing_card :for={listing <- @sold} listing={listing} now={@now} sold />
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("For Sale"))
     |> assign(
       :page_description,
       gettext("Used and new EUCs, scooters, boards and gear from PEV Squad riders.")
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    category = parse_category(params["category"])

    opts = [
      category: category,
      exclude_users: PevSquad.Safety.hidden_user_ids(socket.assigns.current_scope)
    ]

    {:noreply,
     socket
     |> assign(:category, category)
     |> assign(:now, DateTime.utc_now())
     |> assign(:listings, Listings.list_live_listings(opts))
     |> assign(:sold, Listings.list_recently_sold(opts))}
  end

  defp parse_category(value) do
    Enum.find(Listing.categories(), &(Atom.to_string(&1) == value))
  end
end
