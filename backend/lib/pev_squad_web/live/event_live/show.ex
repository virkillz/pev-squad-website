defmodule PevSquadWeb.EventLive.Show do
  use PevSquadWeb, :live_view

  alias PevSquad.Events

  import PevSquadWeb.EventComponents
  import PevSquadWeb.PartnerComponents, only: [initials: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:events}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">
            <.link navigate={~p"/events"} style="text-decoration:none;">
              06 / {gettext("Events")}
            </.link>
          </span>
          <span class="badge" style="background:var(--black); color:var(--orange);">
            {kind_label(@event.kind)}
          </span>
          <span :if={@group?} class="badge badge-host">{hosted_by(@event)}</span>
        </div>
        <h1 class="event-detail-title">{@event.title}</h1>
        <p
          class="page-intro"
          style="font-family:var(--font-mono); text-transform:uppercase; letter-spacing:0.06em;"
        >
          {when_label(@event)}<span :if={@event.location_name}> · {@event.location_name}</span>
        </p>
      </section>

      <section class="band band-black">
        <div class="event-detail-grid">
          <div class="space-y-8">
            <div :if={@event.status == :cancelled} class="notice">
              {gettext("This event has been cancelled.")}
            </div>
            <div :if={@event.status == :draft} class="notice">
              {gettext("Draft — only staff can see this page until it's published.")}
            </div>
            <div :if={@event.status == :hidden} class="notice">
              {gettext(
                "Hidden after reports from members — only you and the moderators can see it until they've looked."
              )}
            </div>
            <p :if={@group?} class="host-note" id="group-ride-note">
              {gettext(
                "A group ride hosted by a member, not organized by PEV Squad. Ride within your limits and wear your gear."
              )}
            </p>

            <div :if={@event.description} class="prose-body">
              <p :for={para <- paragraphs(@event.description)}>{para}</p>
            </div>

            <div :if={@recaps != []} class="event-recaps" id="event-recaps">
              <span class="eyebrow">{gettext("Recap")}</span>
              <.link
                :for={post <- @recaps}
                navigate={PevSquadWeb.PostComponents.post_path(post)}
                class="event-recap"
                lang={recap_title(post).locale}
              >
                {recap_title(post).title} →
              </.link>
            </div>

            <ul class="event-facts">
              <li><span class="k">{gettext("When")}</span><span>{when_label(@event)}</span></li>
              <li :if={@event.ends_at}>
                <span class="k">{gettext("Until")}</span><span>{when_label(%{@event | starts_at: @event.ends_at})}</span>
              </li>
              <li :if={@event.location_name}>
                <span class="k">{gettext("Where")}</span><span>{@event.location_name}</span>
              </li>
              <li :if={@event.meeting_point}>
                <span class="k">{gettext("Meet at")}</span><span>{@event.meeting_point}</span>
              </li>
              <li :if={@group?}>
                <span class="k">{gettext("Hosted by")}</span>
                <span>
                  <.link
                    :if={@event.host_slug}
                    navigate={~p"/community/#{@event.host_slug}"}
                    class="link-orange"
                  >
                    {@event.host_alias}
                  </.link>
                  <span :if={is_nil(@event.host_slug)}>{gettext("A PEV Squad member")}</span>
                </span>
              </li>
              <li :if={!@group?}>
                <span class="k">{gettext("Run by")}</span>
                <span>
                  {if @event.role == :organizer,
                    do: "PEV Squad",
                    else: gettext("PEV Squad as collaborator")}
                </span>
              </li>
              <li :if={@linked_partners != [] or @event.partners}>
                <span class="k">{gettext("With")}</span>
                <span class="partner-chips" id="event-partners">
                  <.link
                    :for={p <- @linked_partners}
                    navigate={~p"/partners/#{p.slug}"}
                    class="partner-chip"
                  >
                    <img :if={p.logo_path} src={p.logo_path} alt="" />
                    <span :if={!p.logo_path} class="chip-initials">{initials(p.name)}</span>
                    {p.name}
                  </.link>
                  <span :if={@event.partners} style="align-self:center;">{@event.partners}</span>
                </span>
              </li>
              <li :if={@event.rsvp_deadline}>
                <span class="k">{gettext("RSVP by")}</span><span>{when_label(%{@event | starts_at: @event.rsvp_deadline})}</span>
              </li>
            </ul>
          </div>

          <aside class="rsvp-box" id="rsvp">
            <span class="eyebrow">{gettext("Seats")}</span>
            <div class="stat-n" style="font-size:3rem;" id="seat-count">
              {@event.going_count}<span :if={@event.capacity} style="opacity:0.5;">/{@event.capacity}</span>
            </div>
            <span class="rsvp-status" style="font-weight:500; opacity:0.75;">
              {gettext("going")}<span :if={@event.waitlist_count > 0}> · {gettext("%{count} on the waitlist", count: @event.waitlist_count)}</span>
            </span>
            <div :if={@event.capacity} class="seat-meter" aria-hidden="true">
              <span style={"width: #{min(@event.going_count * 100 / @event.capacity, 100)}%"}></span>
            </div>

            <%= cond do %>
              <% @rsvp && @rsvp.status == :going -> %>
                <p class="rsvp-status" style="color:var(--orange);" id="rsvp-status">
                  ✓ {gettext("You're going")}
                </p>
                <.button
                  :if={@open?}
                  phx-click="cancel"
                  data-confirm={
                    gettext(
                      "Give up your seat? If the ride is full, the next rider on the waitlist takes it."
                    )
                  }
                  class="btn btn-outline w-full"
                >
                  {gettext("Cancel my RSVP")}
                </.button>
              <% @rsvp && @rsvp.status == :waitlist -> %>
                <p class="rsvp-status" id="rsvp-status">
                  {gettext("You're #%{position} on the waitlist", position: @waitlist_position)}
                </p>
                <p class="event-desc">
                  {gettext("If a seat opens up you'll be moved in automatically and we'll email you.")}
                </p>
                <.button :if={@open?} phx-click="cancel" class="btn btn-outline w-full">
                  {gettext("Leave the waitlist")}
                </.button>
              <% not @open? -> %>
                <p class="rsvp-status" id="rsvp-status">{gettext("RSVPs closed")}</p>
              <% is_nil(@current_scope) -> %>
                <.link navigate={~p"/users/log-in"} class="btn btn-solid w-full text-center">
                  {gettext("Log in to RSVP")}
                </.link>
                <p class="event-desc">
                  {gettext("New here?")}
                  <.link navigate={~p"/users/register"} class="link-orange">
                    {gettext("Create an account")}
                  </.link>
                </p>
              <% Events.seats_left(@event) == 0 -> %>
                <.button phx-click="rsvp" variant="primary" class="btn btn-primary w-full">
                  {gettext("Full — join the waitlist")}
                </.button>
                <p class="event-desc">
                  {gettext("First come, first served. You'll get a seat if someone cancels.")}
                </p>
              <% true -> %>
                <.button phx-click="rsvp" variant="primary" class="btn btn-primary w-full">
                  {gettext("RSVP — I'm going")}
                </.button>
                <p :if={@event.capacity} class="event-desc">
                  {seats_left_label(@event)} {gettext("First come, first served.")}
                </p>
            <% end %>

            <.link
              :if={@can_manage? and @group?}
              navigate={~p"/group-rides/#{@event.id}/edit"}
              class="btn btn-ghost w-full text-center"
            >
              {gettext("Edit ride · see riders")}
            </.link>
            <.link
              :if={@can_manage? and !@group?}
              navigate={~p"/admin/events/#{@event.id}/edit"}
              class="btn btn-ghost w-full text-center"
            >
              {gettext("Edit event · see riders")}
            </.link>
            <.link
              :if={((@group? and @current_scope) && !@host?) and @event.status == :published}
              navigate={~p"/report/event/#{@event.id}"}
              class="lb-report"
              style="color:inherit; opacity:0.6;"
            >
              {gettext("Report this ride")}
            </.link>
          </aside>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    scope = socket.assigns.current_scope
    event = Events.get_public_event!(scope, slug)

    if connected?(socket), do: Events.subscribe(event)

    {:ok,
     socket
     |> assign(:page_title, event.title)
     |> assign(:page_description, description(event))
     |> assign(:linked_partners, PevSquad.Partners.list_event_partners(event))
     |> assign(:recaps, PevSquad.Posts.list_event_posts(event))
     |> assign(:group?, event.category == :group_ride)
     |> assign(:host?, Events.host?(scope, event))
     |> assign(:can_manage?, Events.can_manage?(scope, event))
     |> assign_event(event)}
  end

  @impl true
  def handle_event("rsvp", _params, socket) do
    case socket.assigns.current_scope do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/users/log-in")}

      scope ->
        case Events.rsvp(scope, socket.assigns.event) do
          {:ok, %{status: :going}} ->
            {:noreply,
             socket |> put_flash(:info, gettext("You're in. See you there.")) |> refresh()}

          {:ok, %{status: :waitlist}} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Ride's full — you're on the waitlist."))
             |> refresh()}

          {:error, :closed} ->
            {:noreply,
             socket |> put_flash(:error, gettext("RSVPs for this event are closed.")) |> refresh()}
        end
    end
  end

  def handle_event("cancel", _params, socket) do
    {:ok, _promoted} =
      Events.cancel_rsvp(socket.assigns.current_scope, socket.assigns.event, &event_url/1)

    {:noreply, socket |> put_flash(:info, gettext("RSVP cancelled.")) |> refresh()}
  end

  @impl true
  def handle_info({:rsvps_changed, _event_id}, socket), do: {:noreply, refresh(socket)}

  defp refresh(socket), do: assign_event(socket, Events.reload_event(socket.assigns.event))

  defp assign_event(socket, event) do
    rsvp = Events.get_rsvp(socket.assigns.current_scope, event)

    socket
    |> assign(:event, event)
    |> assign(:rsvp, rsvp)
    |> assign(:waitlist_position, rsvp && Events.waitlist_position(rsvp))
    |> assign(:open?, Events.rsvp_open?(event))
  end

  defp seats_left_label(event) do
    n = Events.seats_left(event)
    ngettext("1 seat left.", "%{count} seats left.", n)
  end

  defp event_url(event), do: url(~p"/events/#{event.slug}")

  defp recap_title(post),
    do: PevSquad.Posts.translation_for(post, PevSquadWeb.Locale.current())

  defp paragraphs(text), do: String.split(text, ~r/\n\s*\n/, trim: true)

  defp description(event) do
    [when_label(event), event.location_name, event.description]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
    |> String.slice(0, 200)
  end
end
