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
            <.link navigate={~p"/community"} style="text-decoration:none;">
              02 / {gettext("Community")}
            </.link>
          </span>
          <span
            :if={@rider.status == :banned}
            class="badge"
            style="background:var(--black); color:var(--white);"
          >
            {gettext("Banned")}
          </span>
          <span
            :if={@rider.status != :banned}
            class="badge"
            style="background:var(--black); color:var(--orange);"
          >
            {type_label(@rider.primary_pev_type)}
          </span>
          <span
            :if={@rider.status == :inactive}
            class="badge"
            style="background:transparent; color:var(--black); border:1px solid var(--black);"
            id="rider-inactive"
          >
            {gettext("Inactive")}
          </span>
        </div>
        <h1 class="event-detail-title">{@rider.alias}</h1>
        <p
          :if={@rider.status != :banned}
          class="page-intro"
          style="font-family:var(--font-mono); text-transform:uppercase; letter-spacing:0.06em;"
        >
          {card_meta(@rider)}
        </p>
      </section>

      <section :if={@blocked?} class="band band-tight band-white">
        <div class="notice flex flex-wrap gap-4 items-center justify-between">
          <span>
            {gettext("You've blocked %{rider}. Their reviews and photos are hidden from you.",
              rider: @rider.alias
            )}
          </span>
          <.button phx-click="unblock">{gettext("Unblock")}</.button>
        </div>
      </section>

      <section :if={@rider.status == :banned} class="band band-black" id="rider-banned">
        <div class="prose-body space-y-4" style="max-width:48rem;">
          <span class="eyebrow">
            {gettext("Statement from PEV Squad")} · {PevSquadWeb.Locale.strftime(
              @rider.banned_at,
              "%-d %B %Y"
            )}
          </span>
          <p>
            {gettext(
              "%{rider} has been banned from PEV Squad and is no longer part of the community.",
              rider: @rider.alias
            )}
          </p>
          <p :for={para <- paragraphs(@rider.ban_reason)}>{para}</p>
        </div>
      </section>

      <section :if={@rider.status != :banned} class="band band-black">
        <div class="event-detail-grid">
          <div class="space-y-8">
            <div :if={@rider.bio} class="prose-body">
              <p>{@rider.bio}</p>
            </div>
            <ul class="event-facts">
              <li :if={@rider.city}>
                <span class="k">{gettext("Based in")}</span><span>{@rider.city}</span>
              </li>
              <li :if={@rider.main_ride}>
                <span class="k">{gettext("Rides")}</span><span>{@rider.main_ride}</span>
              </li>
              <li :if={@rider.communities != []}>
                <span class="k">{gettext("Also rides with")}</span>
                <span class="partner-chips" id="rider-communities">
                  <.link
                    :for={p <- @rider.communities}
                    navigate={~p"/partners/#{p.slug}"}
                    class="partner-chip"
                  >
                    <img :if={p.logo_path} src={p.logo_path} alt="" />
                    <span :if={!p.logo_path} class="chip-initials">
                      {PevSquadWeb.PartnerComponents.initials(p.name)}
                    </span>
                    {p.name}
                  </.link>
                </span>
              </li>
              <li>
                <span class="k">{gettext("Type")}</span><span>{type_label(@rider.primary_pev_type)}</span>
              </li>
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
              {gettext("Edit my profile")}
            </.link>
            <div :if={!@own? && @current_scope} class="flex flex-wrap gap-3 items-center">
              <.link navigate={~p"/report/profile/#{@rider.id}"} class="btn btn-outline">
                {gettext("Report")}
              </.link>
              <.button
                :if={@rider.user_id && !@blocked?}
                phx-click="block"
                data-confirm={
                  gettext("Block %{rider}? You won't see their profile, reviews or photos.",
                    rider: @rider.alias
                  )
                }
              >
                {gettext("Block")}
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
     |> assign(:page_description, page_description(rider))
     |> assign(:rider, rider)
     |> assign(:own?, scope != nil and rider.user_id == scope.user.id)
     |> assign(:blocked?, rider.user_id != nil and Safety.blocked?(scope, rider.user_id))}
  end

  defp page_description(%{status: :banned} = rider),
    do: gettext("%{rider} has been banned from PEV Squad.", rider: rider.alias)

  defp page_description(rider),
    do: rider.bio || gettext("%{rider} rides with PEV Squad.", rider: rider.alias)

  defp paragraphs(text), do: String.split(text, ~r/\n\s*\n/, trim: true)

  @impl true
  def handle_event("block", _params, socket) do
    {:ok, _} = Safety.block(socket.assigns.current_scope, socket.assigns.rider.user_id)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Blocked %{rider}.", rider: socket.assigns.rider.alias))
     |> push_navigate(to: ~p"/community")}
  end

  def handle_event("unblock", _params, socket) do
    :ok = Safety.unblock(socket.assigns.current_scope, socket.assigns.rider.user_id)
    {:noreply, socket |> put_flash(:info, gettext("Unblocked.")) |> assign(:blocked?, false)}
  end
end
