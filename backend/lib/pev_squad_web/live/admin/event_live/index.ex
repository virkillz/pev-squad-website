defmodule PevSquadWeb.Admin.EventLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Events

  import PevSquadWeb.EventComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:events}>
      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Admin</span>
            <h1 class="section-title">Events</h1>
          </div>
          <.link navigate={~p"/admin/events/new"} class="btn btn-primary">New Event</.link>
        </div>

        <.table
          id="events"
          rows={@streams.events}
          row_click={fn {_id, event} -> JS.navigate(~p"/admin/events/#{event}/edit") end}
        >
          <:col :let={{_id, event}} label="Date">
            {Calendar.strftime(local(event.starts_at, event.timezone), "%d %b %Y")}
          </:col>
          <:col :let={{_id, event}} label="Title">{event.title}</:col>
          <:col :let={{_id, event}} label="Kind">{kind_label(event.kind)}</:col>
          <:col :let={{_id, event}} label="Status">{event.status}</:col>
          <:col :let={{_id, event}} label="Seats">{seats_label(event)}</:col>
          <:action :let={{_id, event}}>
            <.link navigate={~p"/events/#{event.slug}"} class="link-orange">View</.link>
          </:action>
          <:action :let={{id, event}}>
            <.link
              phx-click={JS.push("delete", value: %{id: event.id}) |> hide("##{id}")}
              data-confirm="Delete this event and all its RSVPs?"
              class="link-orange"
            >
              Delete
            </.link>
          </:action>
        </.table>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin · Events")
     |> stream(:events, Events.list_events_for_staff(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    event = Events.get_event!(scope, id)
    {:ok, _} = Events.delete_event(scope, event)

    {:noreply, stream_delete(socket, :events, event)}
  end
end
