defmodule PevSquadWeb.Admin.EventLive.Form do
  use PevSquadWeb, :live_view

  alias PevSquad.Events
  alias PevSquad.Partners
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
            <:subtitle>Times are in the event's local timezone.</:subtitle>
          </.header>

          <.form for={@form} id="event-form" phx-change="validate" phx-submit="save" class="space-y-2">
            <.input field={@form[:title]} type="text" label="Title" required />
            <.input
              field={@form[:slug]}
              type="text"
              label="URL slug (leave blank to generate)"
              placeholder="ngeride-ke-bromo-2026"
            />
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <.input field={@form[:kind]} type="select" label="Kind" options={kind_options()} />
              <.input
                field={@form[:role]}
                type="select"
                label="Our role"
                options={[{"Organizer", :organizer}, {"Collaborator", :collaborator}]}
              />
              <.input
                field={@form[:status]}
                type="select"
                label="Status"
                options={[{"Draft", :draft}, {"Published", :published}, {"Cancelled", :cancelled}]}
              />
            </div>
            <fieldset :if={@all_partners != []} class="fieldset space-y-2" id="event-partners">
              <span class="label">
                Partners (<.link navigate={~p"/admin/partners"} class="link-orange">manage</.link>)
              </span>
              <input type="hidden" name="partner_ids[]" value="" />
              <div class="flex flex-wrap gap-x-6 gap-y-2">
                <label :for={p <- @all_partners} class="flex gap-2 items-center cursor-pointer">
                  <input
                    type="checkbox"
                    name="partner_ids[]"
                    value={p.id}
                    checked={MapSet.member?(@partner_ids, p.id)}
                    class="checkbox"
                  />
                  <span>{p.name}</span>
                </label>
              </div>
            </fieldset>
            <.input
              field={@form[:partners]}
              type="text"
              label="Other partners (not in the directory)"
              placeholder="Le Victoria, Aruna Coffee"
            />

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
              label="Location"
              placeholder="Bromo, Malang"
            />
            <.input
              field={@form[:meeting_point]}
              type="text"
              label="Meeting point"
              placeholder="Bundaran HI, north side"
            />
            <.input field={@form[:description]} type="textarea" label="Description" />

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:capacity]}
                type="number"
                min="1"
                label="Seats (blank = unlimited)"
              />
              <.input
                field={@form[:rsvp_deadline]}
                value={local_input_value(@form[:rsvp_deadline], @tz)}
                type="datetime-local"
                label="RSVP deadline (optional)"
              />
            </div>

            <div class="flex gap-3 pt-4">
              <.button phx-disable-with="Saving..." variant="primary">Save Event</.button>
              <.button navigate={~p"/admin/events"}>Cancel</.button>
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
          <:col :let={rsvp} label="Rider">{rsvp.user.email}</:col>
          <:col :let={rsvp} label="Status">{rsvp.status}</:col>
          <:col :let={rsvp} label="RSVP'd at">
            {Calendar.strftime(local(rsvp.inserted_at, @event.timezone), "%d %b %H:%M:%S")}
          </:col>
        </.table>
        <p :if={@rsvps == []} class="event-desc">No RSVPs yet.</p>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:all_partners, Partners.list_all_partners(socket.assigns.current_scope))
     |> assign(:partner_ids, MapSet.new())
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    event = %Event{}

    socket
    |> assign(:page_title, "New Event")
    |> assign(:event, event)
    |> assign(:tz, event.timezone)
    |> assign(:form, to_form(Events.change_event(event)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    event = Events.get_event!(socket.assigns.current_scope, id)

    if event.category == :group_ride do
      push_navigate(socket, to: ~p"/group-rides/#{event.id}/edit")
    else
      edit_official(socket, event)
    end
  end

  defp edit_official(socket, event) do
    socket
    |> assign(
      :partner_ids,
      event |> Partners.list_event_partners(all: true) |> MapSet.new(& &1.id)
    )
    |> assign(:page_title, "Edit Event")
    |> assign(:event, event)
    |> assign(:tz, event.timezone)
    |> assign(:form, to_form(Events.change_event(event)))
    |> assign_rsvps()
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
  def handle_event("validate", %{"event" => params} = all_params, socket) do
    params = to_utc_params(params)
    changeset = Events.change_event(socket.assigns.event, params)

    {:noreply,
     socket
     |> assign(:partner_ids, partner_ids(all_params))
     |> assign(:tz, params["timezone"] || socket.assigns.tz)
     |> assign(:form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"event" => params} = all_params, socket) do
    socket = assign(socket, :partner_ids, partner_ids(all_params))
    save_event(socket, socket.assigns.live_action, to_utc_params(params))
  end

  defp partner_ids(params) do
    params
    |> Map.get("partner_ids", [])
    |> Enum.reject(&(&1 == ""))
    |> MapSet.new(&String.to_integer/1)
  end

  defp link_partners(socket, event) do
    {:ok, _} =
      Partners.set_event_partners(
        socket.assigns.current_scope,
        event,
        MapSet.to_list(socket.assigns.partner_ids)
      )

    event
  end

  defp save_event(socket, :edit, params) do
    case Events.update_event(
           socket.assigns.current_scope,
           socket.assigns.event,
           params,
           &event_url/1
         ) do
      {:ok, event} ->
        link_partners(socket, event)

        {:noreply,
         socket
         |> put_flash(:info, "Event saved.")
         |> push_navigate(to: ~p"/events/#{event.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_event(socket, :new, params) do
    case Events.create_event(socket.assigns.current_scope, params) do
      {:ok, event} ->
        link_partners(socket, event)

        {:noreply,
         socket
         |> put_flash(:info, "Event created.")
         |> push_navigate(to: ~p"/events/#{event.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp event_url(event), do: url(~p"/events/#{event.slug}")
end
