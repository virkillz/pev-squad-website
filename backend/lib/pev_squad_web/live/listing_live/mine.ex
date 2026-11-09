defmodule PevSquadWeb.ListingLive.Mine do
  @moduledoc """
  The seller's dashboard: confirm listings are still available, mark them
  sold, hide or delete them.
  """
  use PevSquadWeb, :live_view

  alias PevSquad.Listings

  import PevSquadWeb.ListingComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:for_sale}>
      <section class="band band-black">
        <div class="section-head">
          <div>
            <span class="eyebrow">
              <.link navigate={~p"/for-sale"} style="text-decoration:none;">
                05 / {gettext("For Sale")}
              </.link>
            </span>
            <h1 class="section-title">{gettext("My listings")}</h1>
            <p class="section-lede">
              {gettext(
                "Listings stay on the board for %{days} days after you last confirmed them. Tap \"Still available\" at least once a week; we'll email you a reminder before one drops off.",
                days: fresh_days()
              )}
            </p>
          </div>
          <.link :if={@blocked == nil} navigate={~p"/for-sale/new"} class="btn btn-solid">
            {gettext("New listing")}
          </.link>
        </div>

        <.sell_blocked :if={@blocked} reason={@blocked} />

        <p :if={@listings == []} class="section-lede" id="no-listings">
          {gettext("You haven't listed anything yet.")}
        </p>

        <div class="my-listings" id="my-listings">
          <article
            :for={{listing, state} <- @listings}
            id={"my-listing-#{listing.id}"}
            class="my-listing"
          >
            <.link navigate={listing_path(listing)} class="my-listing-thumb">
              <img :if={listing.photos != []} src={hd(listing.photos).thumb_path} alt="" />
            </.link>
            <div class="my-listing-body">
              <div class="flex flex-wrap gap-2 items-center">
                <span class={["badge", state not in [:live, :sold] && "badge-grey"]}>
                  {state_label(state)}
                </span>
                <span class="meta-text">{price(listing)} · {listing.city}</span>
              </div>
              <h2 class="card-title">
                <.link navigate={listing_path(listing)}>{listing.title}</.link>
              </h2>
              <p class="meta-text">{note(state, listing, @now)}</p>
              <p :if={state == :rejected and listing.rejection_reason} class="meta-text">
                {gettext("Moderator's note:")} <em>{listing.rejection_reason}</em>
              </p>
              <div class="flex flex-wrap gap-2 pt-2">
                <.button
                  :if={state in [:live, :expired]}
                  phx-click="check_in"
                  phx-value-id={listing.id}
                  variant="primary"
                  class="btn btn-primary btn-sm"
                >
                  {gettext("Still available")}
                </.button>
                <.button
                  :if={state in [:live, :expired, :hidden] and listing.status == :approved}
                  phx-click="sold"
                  phx-value-id={listing.id}
                  class="btn btn-outline btn-sm"
                >
                  {gettext("Mark sold")}
                </.button>
                <.button
                  :if={state in [:sold, :sold_archived]}
                  phx-click="unsold"
                  phx-value-id={listing.id}
                  data-confirm={gettext("Put it back on the board as available?")}
                  class="btn btn-outline btn-sm"
                >
                  {gettext("Not sold after all")}
                </.button>
                <.button
                  :if={state in [:live, :expired, :pending, :rejected]}
                  phx-click="hide"
                  phx-value-id={listing.id}
                  class="btn btn-outline btn-sm"
                >
                  {gettext("Hide")}
                </.button>
                <.button
                  :if={state == :hidden}
                  phx-click="unhide"
                  phx-value-id={listing.id}
                  class="btn btn-outline btn-sm"
                >
                  {gettext("Unhide")}
                </.button>
                <.button
                  :if={state not in [:sold, :sold_archived]}
                  navigate={~p"/for-sale/#{listing.id}/edit"}
                  class="btn btn-outline btn-sm"
                >
                  {gettext("Edit")}
                </.button>
                <.button
                  phx-click="delete"
                  phx-value-id={listing.id}
                  data-confirm={gettext("Delete this listing? This can't be undone.")}
                  class="btn btn-ghost btn-sm"
                >
                  {gettext("Delete")}
                </.button>
              </div>
            </div>
          </article>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    blocked =
      case Listings.can_sell?(socket.assigns.current_scope) do
        :ok -> nil
        {:error, reason} -> reason
      end

    {:ok,
     socket
     |> assign(:page_title, gettext("My listings"))
     |> assign(:blocked, blocked)
     |> load()}
  end

  defp load(socket) do
    now = DateTime.utc_now()

    listings =
      socket.assigns.current_scope
      |> Listings.list_my_listings()
      |> Enum.map(&{&1, Listings.state(&1, now)})

    socket |> assign(:now, now) |> assign(:listings, listings)
  end

  @impl true
  def handle_event(action, %{"id" => id}, socket)
      when action in ~w(check_in sold unsold hide unhide delete) do
    scope = socket.assigns.current_scope
    listing = Listings.get_my_listing!(scope, id)

    result =
      case action do
        "check_in" -> Listings.check_in(scope, listing, review_url: &review_url/1)
        "sold" -> Listings.mark_sold(scope, listing)
        "unsold" -> Listings.unmark_sold(scope, listing)
        "hide" -> Listings.hide(scope, listing)
        "unhide" -> Listings.unhide(scope, listing)
        "delete" -> Listings.delete_listing(scope, listing)
      end

    socket =
      case result do
        {:ok, updated} -> put_flash(socket, :info, done_message(action, updated))
        {:error, _} -> put_flash(socket, :error, gettext("That didn't work. Try again."))
      end

    {:noreply, load(socket)}
  end

  defp done_message("check_in", %{status: :pending}),
    do:
      gettext(
        "It had been off the board for a while, so a moderator will check it again before it goes back up."
      )

  defp done_message("check_in", _),
    do: gettext("Thanks! It stays on the board for another %{days} days.", days: fresh_days())

  defp done_message("sold", _),
    do: gettext("Marked sold. It stays on the board as sold for 7 days.")

  defp done_message("unsold", _), do: gettext("It's back on the board.")
  defp done_message("hide", _), do: gettext("Hidden. Only you can see it now.")
  defp done_message("unhide", _), do: gettext("Unhidden.")
  defp done_message("delete", _), do: gettext("Listing deleted.")

  defp note(:pending, _l, _now), do: gettext("A moderator will check it soon.")
  defp note(:rejected, _l, _now), do: gettext("Edit it to send it back for review.")

  defp note(:live, l, now),
    do: gettext("On the board. Drops off %{when}.", when: days_left(Listings.expires_at(l), now))

  defp note(:expired, _l, _now),
    do: gettext("Off the board. Tap \"Still available\" to put it back.")

  defp note(:sold, l, now),
    do: gettext("Sold %{when}. Shown as sold for a week.", when: days_ago(l.sold_at, now))

  defp note(:sold_archived, l, now),
    do: gettext("Sold %{when}.", when: days_ago(l.sold_at, now))

  defp note(:hidden, _l, _now), do: gettext("Hidden. Only you can see it.")

  defp review_url(_listing), do: url(~p"/admin/listings")
end
