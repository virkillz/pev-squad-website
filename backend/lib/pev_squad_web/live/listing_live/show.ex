defmodule PevSquadWeb.ListingLive.Show do
  @moduledoc "One listing: photos, details and how to reach the seller."
  use PevSquadWeb, :live_view

  alias PevSquad.Accounts.Scope
  alias PevSquad.Listings
  alias PevSquad.Listings.Listing

  import PevSquadWeb.ListingComponents
  import PevSquadWeb.GalleryComponents, only: [lightbox: 1, pad: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:for_sale}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">
            <.link navigate={~p"/for-sale"} style="text-decoration:none;">
              05 / {gettext("For Sale")}
            </.link>
            · {Listing.category_label(@listing.category)}
          </span>
          <span class="sticker">{Listing.condition_label(@listing.condition)}</span>
        </div>
        <h1 class="event-detail-title">{@listing.title}</h1>
        <p class="listing-price listing-price-big" id="listing-price">
          {price(@listing)}
          <span :if={@listing.negotiable} class="listing-nego">{gettext("nego")}</span>
        </p>
      </section>

      <section :if={@manager?} class="band band-tight band-black" id="seller-panel">
        <div class="notice space-y-3">
          <p>
            <strong>{state_label(@state)}.</strong>
            {state_note(@state, @listing, @now)}
          </p>
          <p :if={@state == :rejected and @listing.rejection_reason}>
            {gettext("Moderator's note:")} <em>{@listing.rejection_reason}</em>
          </p>
          <div class="flex flex-wrap gap-3">
            <.link navigate={~p"/for-sale/mine"} class="btn btn-primary">
              {gettext("My listings")}
            </.link>
            <.link navigate={~p"/for-sale/#{@listing.id}/edit"} class="btn">
              {gettext("Edit")}
            </.link>
            <.link :if={@staff? and @state == :pending} navigate={~p"/admin/listings"} class="btn">
              Review queue
            </.link>
            <button
              :if={@staff? and not @owner?}
              type="button"
              phx-click="remove"
              data-confirm="Remove this listing from the board? The seller can't bring it back."
              class="btn btn-ghost"
            >
              Remove listing
            </button>
          </div>
        </div>
      </section>

      <section class="band band-white">
        <div class="listing-layout">
          <div>
            <div :if={@listing.photos != []} id="listing-photos" phx-hook="Lightbox">
              <div
                :for={{group, offset} <- photo_rows(@listing.photos)}
                class="photo-grid listing-photos"
                style={"grid-template-columns: repeat(#{length(group)}, 1fr);"}
              >
                <a
                  :for={{photo, i} <- Enum.with_index(group, offset)}
                  class={["photo-tile", i == 1 && "listing-photo-main"]}
                  href={photo.large_path}
                  data-title={@listing.title}
                  data-meta={price(@listing)}
                >
                  <span class="photo-num">{pad(i)}</span>
                  <img
                    src={if i == 1, do: photo.large_path, else: photo.thumb_path}
                    alt={gettext("%{title}, photo %{n}", title: @listing.title, n: i)}
                    loading={if i == 1, do: "eager", else: "lazy"}
                    decoding="async"
                  />
                </a>
              </div>
            </div>

            <h2 class="section-title" style="margin-top:2rem;">{gettext("About it")}</h2>
            <p class="listing-desc">{@listing.description}</p>
          </div>

          <aside class="listing-aside">
            <dl class="listing-facts">
              <dt>{gettext("Price")}</dt>
              <dd>
                {price(@listing)}{if @listing.negotiable, do: " · " <> gettext("negotiable")}
              </dd>
              <dt>{gettext("Condition")}</dt>
              <dd>{Listing.condition_label(@listing.condition)}</dd>
              <dt :if={@listing.km}>{gettext("Mileage")}</dt>
              <dd :if={@listing.km}>{@listing.km} km</dd>
              <dt>{gettext("Quantity")}</dt>
              <dd>{@listing.quantity}</dd>
              <dt>{gettext("Location")}</dt>
              <dd>{@listing.city}</dd>
              <dt>{gettext("Seller")}</dt>
              <dd>
                <.link
                  :if={seller_link(@listing)}
                  navigate={seller_link(@listing)}
                  class="link-orange"
                >
                  {seller_name(@listing)}
                </.link>
                <span :if={!seller_link(@listing)}>{seller_name(@listing)}</span>
              </dd>
              <dt :if={@listing.last_checked_at}>{gettext("Still available")}</dt>
              <dd :if={@listing.last_checked_at}>
                {gettext("confirmed %{when}", when: days_ago(@listing.last_checked_at, @now))}
              </dd>
            </dl>

            <div :if={@state == :sold} class="notice" id="sold-notice">
              {gettext("Sold %{when}. Congrats to the new owner.",
                when: days_ago(@listing.sold_at, @now)
              )}
            </div>

            <div :if={@state != :sold and @current_scope} class="space-y-3" id="contact">
              <a
                :if={@listing.whatsapp}
                href={whatsapp_url(@listing, @url)}
                target="_blank"
                rel="noopener"
                class="btn btn-primary w-full"
              >
                {gettext("Chat on WhatsApp")}
              </a>
              <a
                :if={@listing.instagram}
                href={"https://ig.me/m/#{@listing.instagram}"}
                target="_blank"
                rel="noopener"
                class="btn w-full"
              >
                {gettext("DM @%{handle} on Instagram", handle: @listing.instagram)}
              </a>
              <p class="meta-text">
                {gettext(
                  "Meet in a public place, check the item before you pay, and never send a deposit to someone you haven't met."
                )}
              </p>
            </div>

            <div :if={@state != :sold and !@current_scope} class="notice space-y-3" id="contact-login">
              <p>{gettext("Log in to see how to contact the seller.")}</p>
              <.link navigate={~p"/users/log-in"} class="btn btn-primary">
                {gettext("Log in")}
              </.link>
            </div>
          </aside>
        </div>
      </section>

      <.lightbox label={gettext("For Sale")} report={false} />
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => param}, _session, socket) do
    scope = socket.assigns.current_scope

    id =
      case Integer.parse(param) do
        {id, _rest} -> id
        :error -> raise Ecto.NoResultsError, queryable: Listing
      end

    listing = Listings.get_public_listing!(scope, id)
    now = DateTime.utc_now()

    {:ok,
     socket
     |> assign(:page_title, listing.title)
     |> assign(
       :page_description,
       "#{price(listing)} · #{listing.city} · " <> String.slice(listing.description, 0, 140)
     )
     |> assign(:listing, listing)
     |> assign(:now, now)
     |> assign(:state, Listings.state(listing, now))
     |> assign(:url, url(~p"/for-sale/#{listing_param(listing)}"))
     |> assign(:owner?, Listings.owner?(scope, listing))
     |> assign(:staff?, Scope.staff?(scope))
     |> assign(:manager?, Listings.owner?(scope, listing) or Scope.staff?(scope))}
  end

  @impl true
  def handle_event("remove", _params, socket) do
    {:ok, _} = Listings.delete_listing(socket.assigns.current_scope, socket.assigns.listing)

    {:noreply, socket |> put_flash(:info, "Listing removed.") |> push_navigate(to: ~p"/for-sale")}
  end

  # The first photo on its own row, the rest in a strip below it.
  defp photo_rows([first | rest]),
    do: if(rest == [], do: [{[first], 1}], else: [{[first], 1}, {rest, 2}])

  defp seller_link(%Listing{seller_profile: %{is_public: true, hidden_by_staff: false} = p}),
    do: ~p"/community/#{p.slug}"

  defp seller_link(_listing), do: nil

  defp whatsapp_url(listing, url) do
    text =
      gettext("Hi, is your %{title} on PEV Squad still available? %{url}",
        title: listing.title,
        url: url
      )

    "https://wa.me/#{listing.whatsapp}?" <> URI.encode_query(%{"text" => text})
  end

  defp state_note(:pending, _l, _now),
    do: gettext("A moderator checks every listing before it goes on the board.")

  defp state_note(:rejected, _l, _now),
    do: gettext("Edit the listing and save it to send it back for review.")

  defp state_note(:live, l, now),
    do:
      gettext("It drops off the board %{when} unless you tap \"Still available\".",
        when: days_left(Listings.expires_at(l), now)
      )

  defp state_note(:expired, _l, _now),
    do: gettext("Only you can see it. Tap \"Still available\" on My listings to put it back.")

  defp state_note(:sold, l, _now),
    do:
      gettext("It stays on the board, marked sold, until %{when}.",
        when: PevSquadWeb.Locale.strftime(Listings.sold_until(l), "%d %b")
      )

  defp state_note(:sold_archived, _l, _now), do: gettext("Only you can see it.")
  defp state_note(:hidden, _l, _now), do: gettext("Only you can see it until you unhide it.")
end
