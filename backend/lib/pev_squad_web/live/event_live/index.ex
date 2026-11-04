defmodule PevSquadWeb.EventLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Events

  import PevSquadWeb.EventComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:events}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">07 / Group rides &amp; meetups</span>
          <span class="tag-scribble">roll out</span>
        </div>
        <h1 class="page-title">Events</h1>
        <p class="page-intro">
          Where the squad shows up in person — trail expeditions, overnight getaways, brand collabs and community meetups. Some we organize, some we're invited to. RSVP to grab a seat: limited rides are first come, first served.
        </p>
      </section>

      <section class="band band-black">
        <div class="section-head">
          <div>
            <span class="eyebrow">Mark your calendar</span>
            <h2 class="section-title">Upcoming</h2>
          </div>
          <.link :if={@staff?} navigate={~p"/admin/events/new"} class="btn btn-outline">
            New Event
          </.link>
        </div>
        <div class="index-list">
          <.event_row :for={event <- @upcoming} event={event} />
          <p :if={@upcoming == []} class="event-desc" style="padding:1.75rem 2rem;">
            Nothing on the calendar yet — watch the WhatsApp group.
          </p>
        </div>
      </section>

      <section :if={@past != []} class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Recap</span>
            <h2 class="section-title">Past Events</h2>
          </div>
        </div>
        <div class="index-list">
          <.event_row :for={event <- @past} event={event} past />
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Events")
     |> assign(
       :page_description,
       "Group rides, meet-ups and trips from PEV Squad — see what's coming up and RSVP."
     )
     |> assign(:staff?, PevSquad.Accounts.Scope.staff?(socket.assigns.current_scope))
     |> assign(:upcoming, Events.list_upcoming_events())
     |> assign(:past, Events.list_past_events())}
  end
end
