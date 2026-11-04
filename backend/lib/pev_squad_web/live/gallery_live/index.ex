defmodule PevSquadWeb.GalleryLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Gallery

  import PevSquadWeb.GalleryComponents

  @preview 8

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:gallery}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">04 / The Archive</span>
          <span class="tag-scribble">caught on camera</span>
        </div>
        <h1 class="page-title">Gallery</h1>
        <p class="page-intro">
          {length(@albums)} sessions, {@total} frames — car park nights, a volcano at sunrise, and every coffee stop in between.
          Tap any frame to open it full screen — arrow keys to move through the set.
        </p>
      </section>

      <section class="band band-black">
        <div id="gallery-grids" phx-hook="Lightbox">
          <div :for={{album, i} <- Enum.with_index(@albums, 1)} style="margin-bottom:3rem;">
            <.album_head album={album} number={i} link />
            <div class="photo-grid">
              <.photo_tile
                :for={{photo, n} <- Enum.with_index(album.photos, 1)}
                photo={photo}
                number={n}
                album={album}
              />
            </div>
            <div :if={album.photo_count > @preview} style="margin-top:1.25rem;">
              <.link navigate={~p"/gallery/#{album.slug}"} class="btn btn-outline">
                See all {album.photo_count} frames
              </.link>
            </div>
          </div>
        </div>
        <p :if={@albums == []} class="section-lede">No albums yet.</p>
      </section>

      <section class="band band-orange">
        <div class="section-head" style="margin-bottom:0;">
          <div>
            <span class="eyebrow">Got a shot</span>
            <h2 class="section-title">Send It In.</h2>
            <p class="section-lede">
              Shot something good on a ride? Open the album and add it — a moderator gives it a quick look before it goes up.
            </p>
          </div>
          <.link
            :if={!@current_scope}
            navigate={~p"/users/log-in"}
            class="btn btn-solid"
            style="background:var(--black); color:var(--orange);"
          >
            Log in to upload
          </.link>
        </div>
      </section>

      <.lightbox />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Gallery")
     |> assign(
       :page_description,
       "Photos from PEV Squad rides — car parks, volcanoes and coffee stops."
     )
     |> assign(:preview, @preview)
     |> assign(:albums, Gallery.list_published_albums(preview: @preview))
     |> assign(:total, Gallery.total_published_photos())}
  end
end
