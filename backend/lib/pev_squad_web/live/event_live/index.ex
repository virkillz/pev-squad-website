defmodule PevSquadWeb.EventLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Events

  import PevSquadWeb.EventComponents

  defp filters,
    do: [
      {gettext("All"), "all"},
      {gettext("Official"), "official"},
      {gettext("Group rides"), "group"}
    ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:events}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">06 / {gettext("Group rides & meetups")}</span>
          <span class="tag-scribble">{gettext("roll out")}</span>
        </div>
        <h1 class="page-title">{gettext("Events")}</h1>
        <p class="page-intro">
          {gettext(
            "Where the squad shows up in person — trail expeditions, overnight getaways, brand collabs and community meetups. Some we organize, some we're invited to, and group rides are hosted by members. RSVP to grab a seat: limited rides are first come, first served."
          )}
        </p>
      </section>

      <section class="band band-black">
        <div class="section-head">
          <div>
            <span class="eyebrow">{gettext("Mark your calendar")}</span>
            <h2 class="section-title">{gettext("Upcoming")}</h2>
          </div>
          <div class="flex flex-wrap gap-3">
            <.link :if={@staff?} navigate={~p"/admin/events/new"} class="btn btn-outline">
              {gettext("New Event")}
            </.link>
            <.link navigate={~p"/group-rides/new"} class="btn btn-solid">
              {gettext("Host a Group Ride")}
            </.link>
          </div>
        </div>
        <div class="filters">
          <.link
            :for={{label, key} <- @filters}
            patch={if key == "all", do: ~p"/events", else: ~p"/events?show=#{key}"}
            class={["filter-tag", @filter == key && "active"]}
          >
            {label}
          </.link>
        </div>
        <div class="index-list" id="upcoming-events">
          <.event_row :for={event <- @upcoming} event={event} />
          <p :if={@upcoming == []} class="event-desc" style="padding:1.75rem 2rem;">
            {empty_message(@filter)}
          </p>
        </div>
      </section>

      <section :if={@past != []} class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">{gettext("Recap")}</span>
            <h2 class="section-title">{gettext("Past Events")}</h2>
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
     |> assign(:page_title, gettext("Events"))
     |> assign(
       :page_description,
       gettext("Group rides, meet-ups and trips from PEV Squad — see what's coming up and RSVP.")
     )
     |> assign(:filters, filters())
     |> assign(:staff?, PevSquad.Accounts.Scope.staff?(socket.assigns.current_scope))
     |> assign(:hidden, PevSquad.Safety.hidden_user_ids(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = if params["show"] in ["official", "group"], do: params["show"], else: "all"
    category = %{"all" => nil, "official" => :official, "group" => :group_ride}[filter]
    hidden = socket.assigns.hidden

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:upcoming, Events.list_upcoming_events(category: category, exclude_users: hidden))
     # The recap is the squad's own history; past group rides aren't kept on show.
     |> assign(
       :past,
       if(category == :group_ride, do: [], else: Events.list_past_events(category: :official))
     )}
  end

  defp empty_message("group"), do: gettext("No group rides planned yet — host one.")
  defp empty_message(_), do: gettext("Nothing on the calendar yet — watch the WhatsApp group.")
end
