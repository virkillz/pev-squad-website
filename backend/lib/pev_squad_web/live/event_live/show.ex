defmodule PevSquadWeb.EventLive.Show do
  use PevSquadWeb, :live_view

  alias PevSquad.Accounts.Scope
  alias PevSquad.Events

  import PevSquadWeb.EventComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:events}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">
            <.link navigate={~p"/events"} style="text-decoration:none;">07 / Events</.link>
          </span>
          <span class="badge" style="background:var(--black); color:var(--orange);">
            {kind_label(@event.kind)}
          </span>
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
              This event has been cancelled.
            </div>
            <div :if={@event.status == :draft} class="notice">
              Draft — only staff can see this page until it's published.
            </div>

            <div :if={@event.description} class="prose-body">
              <p :for={para <- paragraphs(@event.description)}>{para}</p>
            </div>

            <ul class="event-facts">
              <li><span class="k">When</span><span>{when_label(@event)}</span></li>
              <li :if={@event.ends_at}>
                <span class="k">Until</span><span>{when_label(%{@event | starts_at: @event.ends_at})}</span>
              </li>
              <li :if={@event.location_name}>
                <span class="k">Where</span><span>{@event.location_name}</span>
              </li>
              <li :if={@event.meeting_point}>
                <span class="k">Meet at</span><span>{@event.meeting_point}</span>
              </li>
              <li>
                <span class="k">Run by</span>
                <span>
                  {if @event.role == :organizer, do: "PEV Squad", else: "PEV Squad as collaborator"}<span :if={
                    @event.partners
                  }> · with {@event.partners}</span>
                </span>
              </li>
              <li :if={@event.rsvp_deadline}>
                <span class="k">RSVP by</span><span>{when_label(%{@event | starts_at: @event.rsvp_deadline})}</span>
              </li>
            </ul>
          </div>

          <aside class="rsvp-box" id="rsvp">
            <span class="eyebrow">Seats</span>
            <div class="stat-n" style="font-size:3rem;" id="seat-count">
              {@event.going_count}<span :if={@event.capacity} style="opacity:0.5;">/{@event.capacity}</span>
            </div>
            <span class="rsvp-status" style="font-weight:500; opacity:0.75;">
              going<span :if={@event.waitlist_count > 0}> · {@event.waitlist_count} on the waitlist</span>
            </span>
            <div :if={@event.capacity} class="seat-meter" aria-hidden="true">
              <span style={"width: #{min(@event.going_count * 100 / @event.capacity, 100)}%"}></span>
            </div>

            <%= cond do %>
              <% @rsvp && @rsvp.status == :going -> %>
                <p class="rsvp-status" style="color:var(--orange);" id="rsvp-status">
                  ✓ You're going
                </p>
                <.button
                  :if={@open?}
                  phx-click="cancel"
                  data-confirm="Give up your seat? If the ride is full, the next rider on the waitlist takes it."
                  class="btn btn-outline w-full"
                >
                  Cancel my RSVP
                </.button>
              <% @rsvp && @rsvp.status == :waitlist -> %>
                <p class="rsvp-status" id="rsvp-status">
                  You're #{@waitlist_position} on the waitlist
                </p>
                <p class="event-desc">
                  If a seat opens up you'll be moved in automatically and we'll email you.
                </p>
                <.button :if={@open?} phx-click="cancel" class="btn btn-outline w-full">
                  Leave the waitlist
                </.button>
              <% not @open? -> %>
                <p class="rsvp-status" id="rsvp-status">RSVPs closed</p>
              <% is_nil(@current_scope) -> %>
                <.link navigate={~p"/users/log-in"} class="btn btn-solid w-full text-center">
                  Log in to RSVP
                </.link>
                <p class="event-desc">
                  New here?
                  <.link navigate={~p"/users/register"} class="link-orange">Create an account</.link>
                </p>
              <% Events.seats_left(@event) == 0 -> %>
                <.button phx-click="rsvp" variant="primary" class="btn btn-primary w-full">
                  Full — join the waitlist
                </.button>
                <p class="event-desc">
                  First come, first served. You'll get a seat if someone cancels.
                </p>
              <% true -> %>
                <.button phx-click="rsvp" variant="primary" class="btn btn-primary w-full">
                  RSVP — I'm going
                </.button>
                <p :if={@event.capacity} class="event-desc">
                  {seats_left_label(@event)} First come, first served.
                </p>
            <% end %>

            <.link
              :if={@staff?}
              navigate={~p"/admin/events/#{@event.id}/edit"}
              class="btn btn-ghost w-full text-center"
            >
              Edit event · see riders
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
     |> assign(:staff?, Scope.staff?(scope))
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
            {:noreply, socket |> put_flash(:info, "You're in. See you there.") |> refresh()}

          {:ok, %{status: :waitlist}} ->
            {:noreply,
             socket
             |> put_flash(:info, "Ride's full — you're on the waitlist.")
             |> refresh()}

          {:error, :closed} ->
            {:noreply,
             socket |> put_flash(:error, "RSVPs for this event are closed.") |> refresh()}
        end
    end
  end

  def handle_event("cancel", _params, socket) do
    {:ok, _promoted} =
      Events.cancel_rsvp(socket.assigns.current_scope, socket.assigns.event, &event_url/1)

    {:noreply, socket |> put_flash(:info, "RSVP cancelled.") |> refresh()}
  end

  @impl true
  def handle_info({:rsvps_changed, _event_id}, socket), do: {:noreply, refresh(socket)}

  defp refresh(socket), do: assign_event(socket, Events.reload_counts(socket.assigns.event))

  defp assign_event(socket, event) do
    rsvp = Events.get_rsvp(socket.assigns.current_scope, event)

    socket
    |> assign(:event, event)
    |> assign(:rsvp, rsvp)
    |> assign(:waitlist_position, rsvp && Events.waitlist_position(rsvp))
    |> assign(:open?, Events.rsvp_open?(event))
  end

  defp seats_left_label(event) do
    case Events.seats_left(event) do
      1 -> "1 seat left."
      n -> "#{n} seats left."
    end
  end

  defp event_url(event), do: url(~p"/events/#{event.slug}")

  defp paragraphs(text), do: String.split(text, ~r/\n\s*\n/, trim: true)

  defp description(event) do
    [when_label(event), event.location_name, event.description]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
    |> String.slice(0, 200)
  end
end
