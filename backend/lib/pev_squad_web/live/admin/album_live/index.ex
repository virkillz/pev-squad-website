defmodule PevSquadWeb.Admin.AlbumLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Gallery

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:admin}>
      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Admin</span>
            <h1 class="section-title">Albums</h1>
          </div>
          <div class="flex gap-3">
            <.link navigate={~p"/admin/photos"} class="btn btn-outline">Photo queue</.link>
            <.link navigate={~p"/admin/albums/new"} class="btn btn-primary">New Album</.link>
          </div>
        </div>
        <.table
          id="albums"
          rows={@albums}
          row_click={fn a -> JS.navigate(~p"/admin/albums/#{a}/edit") end}
        >
          <:col :let={album} label="Title">{album.title}</:col>
          <:col :let={album} label="Taken">
            {album.taken_on && Calendar.strftime(album.taken_on, "%d %b %Y")}
          </:col>
          <:col :let={album} label="Photos">{album.photo_count}</:col>
          <:col :let={album} label="Status">
            {if album.published, do: "Published", else: "Draft"}
          </:col>
          <:col :let={album} label="Uploads">
            {if album.open_for_uploads, do: "Open", else: "Closed"}
          </:col>
        </.table>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin · Albums")
     |> assign(:albums, Gallery.list_albums_for_staff(socket.assigns.current_scope))}
  end
end
