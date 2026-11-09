defmodule PevSquadWeb.HomeLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Events
  alias PevSquadWeb.EventComponents
  alias PevSquadWeb.PostComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "We Take It Personal")
     |> assign(:date_stamp, date_stamp())
     |> assign(:next_event, Events.next_event())
     |> assign(:upcoming_count, length(Events.list_upcoming_events()))
     |> assign(:latest_posts, latest_posts())
     |> assign(
       :featured_photos,
       PevSquad.Gallery.list_featured_photos(
         exclude_users: PevSquad.Safety.hidden_user_ids(socket.assigns.current_scope)
       )
     )}
  end

  # The hero's "Latest" block: the newest post as the feature, the next one
  # as a row. Empty until the first post is published.
  defp latest_posts do
    locale = PevSquadWeb.Locale.current()

    [limit: 2]
    |> PevSquad.Posts.list_published_posts()
    |> Enum.map(&%{post: &1, t: PevSquad.Posts.translation_for(&1, locale)})
  end

  # "04 NOV WED" (or "04 NOV RAB") in Jakarta time — the hero meta strip.
  defp date_stamp do
    DateTime.utc_now()
    |> DateTime.shift_zone!("Asia/Jakarta")
    |> PevSquadWeb.Locale.strftime("%d %b %a")
    |> String.upcase()
  end
end
