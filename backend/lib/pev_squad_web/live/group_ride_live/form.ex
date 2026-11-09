defmodule PevSquadWeb.GroupRideLive.Form do
  @moduledoc "Members host group rides here; the host and staff edit or cancel them."
  use PevSquadWeb, :live_view

  alias PevSquad.Events
  alias PevSquad.Events.Event

  import PevSquadWeb.EventComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:events}>
      <section class="band band-black">
        <div class="panel panel-wide space-y-4">
          <.header>
            {@page_title}
            <:subtitle>
              Group rides are hosted by members and go live straight away. Times are in the ride's local timezone.
            </:subtitle>
          </.header>

          <div :if={@blocked == :no_profile} class="notice space-y-3" id="needs-profile">
            <p>
              Riders want to know who they're rolling with, so hosting needs a rider profile first.
            </p>
            <.link navigate={~p"/users/profile"} class="btn btn-primary">Set up my profile</.link>
          </div>

          <div :if={@blocked == :pending} class="notice" id="needs-approval">
            Your rider profile is waiting for a moderator to approve it. You can host group rides once it's approved — RSVPing to rides works already.
          </div>

          <div :if={@blocked == :limit} class="notice" id="host-limit">
            You're already hosting {Events.max_upcoming_per_host()} upcoming rides — that's the limit. Post the next one after one of them has happened.
          </div>

          <.form
            :if={is_nil(@blocked)}
            for={@form}
            id="group-ride-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-2"
          >
            <.input
              field={@form[:title]}
              type="text"
              label="Title"
              placeholder="Sunday Morning Loop"
              required
            />
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:kind]}
                type="select"
                label="Kind"
                options={group_ride_kind_options()}
              />
              <.input
                field={@form[:capacity]}
                type="number"
                min="1"
                max={Event.group_ride_max_capacity()}
                label={"Seats (max #{Event.group_ride_max_capacity()})"}
                required
              />
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <.input
                field={@form[:starts_at]}
                value={local_input_value(@form[:starts_at], @tz)}
                type="datetime-local"
                label="Starts"
                required
              />
              <.input
                field={@form[:ends_at]}
                value={local_input_value(@form[:ends_at], @tz)}
                type="datetime-local"
                label="Ends (optional)"
              />
              <.input
                field={@form[:timezone]}
                type="select"
                label="Timezone"
                options={timezone_options()}
              />
            </div>

            <.input
              field={@form[:location_name]}
              type="text"
              label="Area"
              placeholder="Senayan, Jakarta"
              required
            />
            <.input
              field={@form[:meeting_point]}
              type="text"
              label="Meeting point"
              placeholder="FX Sudirman, lobby parking"
            />
            <.input
              field={@form[:description]}
              type="textarea"
              label="Route, pace and what to bring"
              placeholder="~25 km, easy pace, regroup every 5 km. Helmet required."
            />
            <.input
              field={@form[:rsvp_deadline]}
              value={local_input_value(@form[:rsvp_deadline], @tz)}
              type="datetime-local"
              label="RSVP deadline (optional)"
            />

            <div class="flex flex-wrap gap-3 pt-4">
              <.button phx-disable-with="Saving..." variant="primary">
                {if @live_action == :new, do: "Post Ride", else: "Save Ride"}
              </.button>
              <.button navigate={cancel_path(@event)}>Back</.button>
              <.button
                :if={@live_action == :edit and @event.status in [:published, :hidden]}
                type="button"
                phx-click="cancel_ride"
                data-confirm="Cancel this ride? Everyone who RSVP'd gets an email."
                class="btn btn-ghost"
              >
                Cancel the ride
              </.button>
            </div>
          </.form>
        </div>
      </section>

      <section :if={@live_action == :edit} class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">{seats_label(@event)}</span>
            <h2 class="section-title">Riders</h2>
          </div>
        </div>
        <.table id="rsvps" rows={@rsvps}>
          <:col :let={rsvp} label="#">{rsvp.position}</:col>
          <:col :let={rsvp} label="Rider">{rsvp.rider_alias || "Member without a profile"}</:col>
          <:col :let={rsvp} label="Status">{rsvp.status}</:col>
          <:col :let={rsvp} label="RSVP'd at">
            {Calendar.strftime(local(rsvp.inserted_at, @event.timezone), "%d %b %H:%M")}
          </:col>
        </.table>
        <p :if={@rsvps == []} class="event-desc">No RSVPs yet.</p>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    event = Events.new_group_ride()

    blocked =
      case Events.can_host?(socket.assigns.current_scope) do
        :ok -> nil
        {:error, reason} -> reason
      end

    socket
    |> assign(:page_title, "Host a Group Ride")
    |> assign(:blocked, blocked)
    |> assign(:event, event)
    |> assign(:tz, event.timezone)
    |> assign(:form, to_form(Events.change_event(event)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope
    event = Events.get_manageable_event!(scope, id)

    if event.category == :official do
      push_navigate(socket, to: ~p"/admin/events/#{event.id}/edit")
    else
      socket
      |> assign(:page_title, "Edit Group Ride")
      |> assign(:blocked, nil)
      |> assign(:event, event)
      |> assign(:tz, event.timezone)
      |> assign(:form, to_form(Events.change_event(event)))
      |> assign_rsvps()
    end
  end

  defp assign_rsvps(socket) do
    rsvps =
      Events.list_rsvps(socket.assigns.current_scope, socket.assigns.event)
      |> Enum.chunk_by(& &1.status)
      |> Enum.flat_map(fn group ->
        group |> Enum.with_index(1) |> Enum.map(fn {r, i} -> Map.put(r, :position, i) end)
      end)

    assign(socket, :rsvps, rsvps)
  end

  @impl true
  def handle_event("validate", %{"event" => params}, socket) do
    params = to_utc_params(params)
    changeset = Events.change_event(socket.assigns.event, params)

    {:noreply,
     socket
     |> assign(:tz, params["timezone"] || socket.assigns.tz)
     |> assign(:form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"event" => params}, socket) do
    save(socket, socket.assigns.live_action, to_utc_params(params))
  end

  def handle_event("cancel_ride", _params, socket) do
    {:ok, event} =
      Events.cancel_event(socket.assigns.current_scope, socket.assigns.event, &event_url/1)

    {:noreply,
     socket
     |> put_flash(:info, "Ride cancelled. Everyone who RSVP'd has been emailed.")
     |> push_navigate(to: ~p"/events/#{event.slug}")}
  end

  defp save(socket, :new, params) do
    case Events.create_group_ride(socket.assigns.current_scope, params) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your ride is live. Share the link in the WhatsApp group.")
         |> push_navigate(to: ~p"/events/#{event.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, reason} ->
        {:noreply, assign(socket, :blocked, reason)}
    end
  end

  defp save(socket, :edit, params) do
    case Events.update_event(
           socket.assigns.current_scope,
           socket.assigns.event,
           params,
           &event_url/1
         ) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ride saved.")
         |> push_navigate(to: ~p"/events/#{event.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp cancel_path(%Event{slug: nil}), do: ~p"/events?show=group"
  defp cancel_path(%Event{slug: slug}), do: ~p"/events/#{slug}"

  defp event_url(event), do: url(~p"/events/#{event.slug}")
end
