defmodule PevSquadWeb.Admin.ListingLive.Queue do
  use PevSquadWeb, :live_view

  alias PevSquad.Listings
  alias PevSquad.Listings.Listing

  import PevSquadWeb.ListingComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:admin}>
      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Admin · Moderation</span>
            <h1 class="section-title">Listing Queue</h1>
            <p class="section-lede">{length(@listings)} waiting, oldest first.</p>
          </div>
          <.link navigate={~p"/for-sale"} class="btn btn-outline">For Sale board</.link>
        </div>

        <p :if={@listings == []} class="section-lede">All clear. Nothing waiting.</p>

        <div class="space-y-8">
          <article :for={listing <- @listings} id={"pending-#{listing.id}"} class="notice space-y-3">
            <div class="flex flex-wrap gap-2 items-center">
              <span class="badge">{Listing.category_label(listing.category)}</span>
              <span class="badge">{Listing.condition_label(listing.condition)}</span>
              <span
                :if={listing.approved_at}
                class="badge"
                style="background:var(--black); color:var(--orange);"
              >
                Edited after approval
              </span>
              <span class="meta-text">
                by {seller_name(listing)} ({listing.seller.email}) · {listing.city}
              </span>
            </div>
            <h2 class="card-title">
              <.link navigate={listing_path(listing)}>{listing.title}</.link>
            </h2>
            <p class="listing-price">
              {price(listing)}{if listing.negotiable, do: " · nego"} · qty {listing.quantity}{if listing.km,
                do: " · #{listing.km} km"}
            </p>
            <div class="listing-uploads">
              <a
                :for={photo <- listing.photos}
                href={photo.large_path}
                target="_blank"
                class="listing-upload"
              >
                <img src={photo.thumb_path} alt="" />
              </a>
            </div>
            <p class="listing-desc">{listing.description}</p>
            <p class="meta-text">
              WhatsApp: {listing.whatsapp || "—"} · Instagram: {listing.instagram || "—"}
            </p>
            <div class="flex flex-wrap gap-3 items-end">
              <.button phx-click="approve" phx-value-id={listing.id} variant="primary">
                Approve
              </.button>
              <form
                phx-submit="reject"
                class="flex gap-2 items-end flex-1"
                id={"reject-#{listing.id}"}
              >
                <input type="hidden" name="listing_id" value={listing.id} />
                <input
                  name="reason"
                  class="input"
                  placeholder="Why it's being sent back (emailed to the seller)"
                  required
                />
                <.button>Send back</.button>
              </form>
            </div>
          </article>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Admin · Listing queue") |> load()}
  end

  defp load(socket),
    do: assign(socket, :listings, Listings.list_pending(socket.assigns.current_scope))

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    listing = find(socket, id)
    {:ok, _} = Listings.approve(socket.assigns.current_scope, listing, &public_url/1)
    {:noreply, socket |> put_flash(:info, "Approved \"#{listing.title}\".") |> load()}
  end

  def handle_event("reject", %{"listing_id" => id, "reason" => reason}, socket) do
    listing = find(socket, id)

    case Listings.reject(socket.assigns.current_scope, listing, reason, &edit_url/1) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Sent back to the seller.") |> load()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Add a reason so the seller knows what to fix.")}
    end
  end

  defp find(socket, id), do: Enum.find(socket.assigns.listings, &(to_string(&1.id) == id))

  defp public_url(listing), do: url(~p"/for-sale/#{listing_param(listing)}")
  defp edit_url(listing), do: url(~p"/for-sale/#{listing.id}/edit")
end
