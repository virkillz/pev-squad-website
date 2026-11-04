defmodule PevSquadWeb.Admin.Dashboard do
  use PevSquadWeb, :live_view

  alias PevSquad.Reviews

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:admin}>
      <section class="page-header">
        <div class="meta-row"><span class="eyebrow">Moderators &amp; admins</span></div>
        <h1 class="page-title" style="font-size:clamp(3.5rem, 12vw, 11rem);">Admin</h1>
      </section>
      <section class="band band-black">
        <div class="index-list">
          <.link class="index-row" navigate={~p"/admin/reports"}>
            <div class="index-num">00</div>
            <div class="index-title">Reports</div>
            <div class="index-desc">Members flagging reviews, photos or profiles.</div>
            <div class="index-meta">{@open_reports} OPEN</div>
          </.link>
          <.link class="index-row" navigate={~p"/admin/reviews"}>
            <div class="index-num">01</div>
            <div class="index-title">Review Queue</div>
            <div class="index-desc">Approve or send back member reviews.</div>
            <div class="index-meta">{@pending} WAITING</div>
          </.link>
          <.link class="index-row" navigate={~p"/admin/photos"}>
            <div class="index-num">02</div>
            <div class="index-title">Photo Queue</div>
            <div class="index-desc">Approve or reject member gallery uploads.</div>
            <div class="index-meta">{@pending_photos} WAITING</div>
          </.link>
          <.link class="index-row" navigate={~p"/admin/albums"}>
            <div class="index-num">03</div>
            <div class="index-title">Albums</div>
            <div class="index-desc">Create albums, open them for uploads, arrange photos.</div>
            <div class="index-meta">GALLERY</div>
          </.link>
          <.link class="index-row" navigate={~p"/admin/events"}>
            <div class="index-num">04</div>
            <div class="index-title">Events</div>
            <div class="index-desc">Create rides, set seats, see who's going.</div>
            <div class="index-meta">RSVP · WAITLIST</div>
          </.link>
          <.link class="index-row" navigate={~p"/admin/riders"}>
            <div class="index-num">05</div>
            <div class="index-title">Riders</div>
            <div class="index-desc">Link imported profiles to members, Featured badges.</div>
            <div class="index-meta">PROFILES</div>
          </.link>
          <.link class="index-row" navigate={~p"/admin/models"}>
            <div class="index-num">06</div>
            <div class="index-title">Model Catalog</div>
            <div class="index-desc">The EUCs, scooters and boards riders can review.</div>
            <div class="index-meta">CATALOG</div>
          </.link>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin")
     |> assign(:pending, Reviews.count_pending(socket.assigns.current_scope))
     |> assign(
       :pending_photos,
       PevSquad.Gallery.count_pending_photos(socket.assigns.current_scope)
     )}
  end
end
