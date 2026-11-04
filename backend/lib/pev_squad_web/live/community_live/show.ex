defmodule PevSquadWeb.CommunityLive.Show do
  use PevSquadWeb, :live_view

  alias PevSquad.{Riders, Safety}

  import PevSquadWeb.RiderComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:community}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">
            <.link navigate={~p"/community"} style="text-decoration:none;">02 / Community</.link>
          </span>
          <span class="badge" style="background:var(--black); color:var(--orange);">
            {type_label(@rider.primary_pev_type)}
          </span>
        </div>
        <h1 class="event-detail-title">{@rider.alias}</h1>
        <p
          class="page-intro"
          style="font-family:var(--font-mono); text-transform:uppercase; letter-spacing:0.06em;"
        >
          {card_meta(@rider)}
        </p>
      </section>

      <section :if={@blocked?} class="band band-tight band-white">
        <div class="notice flex flex-wrap gap-4 items-center justify-between">
          <span>You've blocked {@rider.alias}. Their reviews and photos are hidden from you.</span>
          <.button phx-click="unblock">Unblock</.button>
        </div>
      </section>

      <section class="band band-black">
        <div class="event-detail-grid">
          <div class="space-y-8">
            <span :if={@rider.featured_since} class="badge">★ Featured Rider</span>
            <div :if={@rider.bio} class="prose-body">
              <p>{@rider.bio}</p>
            </div>
            <ul class="event-facts">
              <li :if={@rider.city}><span class="k">Based in</span><span>{@rider.city}</span></li>
              <li :if={@rider.main_ride}>
                <span class="k">Rides</span><span>{@rider.main_ride}</span>
              </li>
              <li><span class="k">Type</span><span>{type_label(@rider.primary_pev_type)}</span></li>
              <li :if={@rider.instagram}>
                <span class="k">Instagram</span>
                <a
                  href={"https://instagram.com/#{@rider.instagram}"}
                  class="link-orange"
                  rel="noopener"
                  target="_blank"
                >
                  @{@rider.instagram}
                </a>
              </li>
            </ul>
            <.link :if={@own?} navigate={~p"/users/profile"} class="btn btn-outline">
              Edit my profile
            </.link>
            <div :if={!@own? && @current_scope} class="flex flex-wrap gap-3 items-center">
              <.link navigate={~p"/report/profile/#{@rider.id}"} class="btn btn-outline">
                Report
              </.link>
              <.button
                :if={@rider.user_id && !@blocked?}
                phx-click="block"
                data-confirm={"Block #{@rider.alias}? You won't see their profile, reviews or photos."}
              >
                Block
              </.button>
            </div>
          </div>
          <div>
            <img
              :if={@rider.avatar_path}
              src={@rider.avatar_path}
              alt={@rider.alias}
              style="width:100%; aspect-ratio:4/5; object-fit:cover; border:var(--bw) solid var(--white);"
            />
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    rider = Riders.get_public_rider!(slug)
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:page_title, rider.alias)
     |> assign(:page_description, rider.bio || "#{rider.alias} rides with PEV Squad.")
     |> assign(:rider, rider)
     |> assign(:own?, scope != nil and rider.user_id == scope.user.id)
     |> assign(:blocked?, rider.user_id != nil and Safety.blocked?(scope, rider.user_id))}
  end

  @impl true
  def handle_event("block", _params, socket) do
    {:ok, _} = Safety.block(socket.assigns.current_scope, socket.assigns.rider.user_id)

    {:noreply,
     socket
     |> put_flash(:info, "Blocked #{socket.assigns.rider.alias}.")
     |> push_navigate(to: ~p"/community")}
  end

  def handle_event("unblock", _params, socket) do
    :ok = Safety.unblock(socket.assigns.current_scope, socket.assigns.rider.user_id)
    {:noreply, socket |> put_flash(:info, "Unblocked.") |> assign(:blocked?, false)}
  end
end
