defmodule PevSquadWeb.Admin.PhotoLive.Queue do
  use PevSquadWeb, :live_view

  alias PevSquad.Gallery

  import PevSquadWeb.GalleryComponents, only: [credit: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:admin}>
      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Admin · Moderation</span>
            <h1 class="section-title">Photo Queue</h1>
            <p class="section-lede">
              {length(@photos)} waiting, oldest first. Rejected photos are deleted.
            </p>
          </div>
          <.link navigate={~p"/admin/albums"} class="btn btn-outline">Albums</.link>
        </div>
        <p :if={@photos == []} class="section-lede">All clear. Nothing waiting.</p>
        <div class="grid grid-3" style="gap:1rem;">
          <div :for={photo <- @photos} id={"pending-#{photo.id}"} class="notice space-y-2">
            <a href={photo.large_path} target="_blank" rel="noopener">
              <img
                src={photo.thumb_path}
                alt=""
                style="width:100%; aspect-ratio:1; object-fit:cover;"
              />
            </a>
            <p><strong>{photo.title || "Untitled"}</strong> · {photo.album.title}</p>
            <p :if={photo.caption}>{photo.caption}</p>
            <p class="meta-text">{credit(photo)}</p>
            <div class="flex gap-2">
              <.button phx-click="approve" phx-value-id={photo.id} variant="primary">Approve</.button>
              <.button
                phx-click="reject"
                phx-value-id={photo.id}
                data-confirm="Reject and delete this photo?"
              >
                Reject
              </.button>
            </div>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Admin · Photo queue") |> load()}
  end

  defp load(socket),
    do: assign(socket, :photos, Gallery.list_pending_photos(socket.assigns.current_scope))

  defp find(socket, id), do: Enum.find(socket.assigns.photos, &(to_string(&1.id) == id))

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    {:ok, _} = Gallery.approve_photo(socket.assigns.current_scope, find(socket, id))
    {:noreply, socket |> put_flash(:info, "Photo published.") |> load()}
  end

  def handle_event("reject", %{"id" => id}, socket) do
    {:ok, _} = Gallery.reject_photo(socket.assigns.current_scope, find(socket, id))
    {:noreply, socket |> put_flash(:info, "Photo rejected and deleted.") |> load()}
  end
end
