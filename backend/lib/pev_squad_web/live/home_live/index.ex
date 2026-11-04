defmodule PevSquadWeb.HomeLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Events
  alias PevSquadWeb.EventComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "We Take It Personal")
     |> assign(:date_stamp, date_stamp())
     |> assign(:next_event, Events.next_event())
     |> assign(:upcoming_count, length(Events.list_upcoming_events()))
     |> assign(
       :featured_photos,
       PevSquad.Gallery.list_featured_photos(
         exclude_users: PevSquad.Safety.hidden_user_ids(socket.assigns.current_scope)
       )
     )}
  end

  # "04 NOV WED" in Jakarta time — the hero meta strip.
  defp date_stamp do
    DateTime.utc_now()
    |> DateTime.shift_zone!("Asia/Jakarta")
    |> Calendar.strftime("%d %b %a")
    |> String.upcase()
  end
end
