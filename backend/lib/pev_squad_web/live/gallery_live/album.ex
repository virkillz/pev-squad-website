defmodule PevSquadWeb.GalleryLive.Album do
  use PevSquadWeb, :live_view

  alias PevSquad.Gallery

  import PevSquadWeb.GalleryComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:gallery}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">
            <.link navigate={~p"/gallery"} style="text-decoration:none;">
              03 / {gettext("The Archive")}
            </.link>
          </span>
          <span class="sticker">
            {gettext("%{count} Frames", count: pad(length(@album.photos)))}
          </span>
        </div>
        <h1 class="event-detail-title">{@album.title}</h1>
        <p
          :if={@album.subtitle}
          class="page-intro"
          style="font-family:var(--font-mono); text-transform:uppercase; letter-spacing:0.06em;"
        >
          {@album.subtitle}
        </p>
        <p :if={@album.description} class="page-intro">{@album.description}</p>
      </section>

      <section class="band band-black">
        <div class="section-head">
          <div>
            <span class="eyebrow">{gettext("Tap a frame to open it")}</span>
          </div>
          <.link
            :if={@can_upload?}
            navigate={~p"/gallery/#{@album.slug}/upload"}
            class="btn btn-solid"
          >
            {gettext("Add Photos")}
          </.link>
          <.link
            :if={!@current_scope && @album.open_for_uploads}
            navigate={~p"/users/log-in"}
            class="btn btn-outline"
          >
            {gettext("Log in to add photos")}
          </.link>
        </div>
        <div id="album-grid" phx-hook="Lightbox" class="photo-grid">
          <.photo_tile
            :for={{photo, n} <- Enum.with_index(@album.photos, 1)}
            photo={photo}
            number={n}
            album={@album}
          />
        </div>
        <p :if={@album.photos == []} class="section-lede">{gettext("No photos yet.")}</p>
      </section>

      <.lightbox />
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    album =
      Gallery.get_published_album!(slug,
        exclude_users: PevSquad.Safety.hidden_user_ids(socket.assigns.current_scope)
      )

    {:ok,
     socket
     |> assign(:page_title, album.title)
     |> assign(
       :page_description,
       album.subtitle || gettext("%{album} — PEV Squad gallery", album: album.title)
     )
     |> assign(:album, album)
     |> assign(:can_upload?, Gallery.can_upload?(socket.assigns.current_scope, album))}
  end
end
