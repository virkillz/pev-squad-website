defmodule PevSquadWeb.Admin.AlbumLive.Form do
  use PevSquadWeb, :live_view

  alias PevSquad.{Events, Gallery}
  alias PevSquad.Gallery.Album

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:admin}>
      <section class="band band-black">
        <div class="panel panel-wide space-y-4">
          <.header>
            {@page_title}
            <:subtitle>
              <.link
                :if={@album.id && @album.published}
                navigate={~p"/gallery/#{@album.slug}"}
                class="link-orange"
              >
                View album
              </.link>
            </:subtitle>
          </.header>

          <.form for={@form} id="album-form" phx-change="validate" phx-submit="save" class="space-y-2">
            <.input field={@form[:title]} type="text" label="Title" required />
            <.input
              field={@form[:subtitle]}
              type="text"
              label="Subtitle"
              placeholder="Mount Bromo, East Java"
            />
            <.input field={@form[:description]} type="textarea" label="Description (optional)" />
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input field={@form[:taken_on]} type="date" label="Date" />
              <.input
                field={@form[:event_id]}
                type="select"
                label="Event (optional)"
                prompt="—"
                options={@event_options}
              />
            </div>
            <.input field={@form[:published]} type="checkbox" label="Published" />
            <.input field={@form[:open_for_uploads]} type="checkbox" label="Members can add photos" />
            <div class="flex gap-3 pt-4">
              <.button variant="primary" phx-disable-with="Saving...">Save album</.button>
              <.link
                :if={@album.id}
                navigate={~p"/gallery/#{@album.slug}/upload"}
                class="btn btn-outline"
              >
                Add photos
              </.link>
              <.button navigate={~p"/admin/albums"}>Back</.button>
            </div>
          </.form>
        </div>
      </section>

      <section :if={@album.id} class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">{length(@album.photos)} photos, in order</span>
            <h2 class="section-title">Photos</h2>
          </div>
          <.button
            phx-click="delete_album"
            data-confirm="Delete this album and all its photos? This can't be undone."
          >
            Delete album
          </.button>
        </div>
        <div class="grid grid-3" style="gap:1rem;">
          <form
            :for={photo <- @album.photos}
            id={"photo-#{photo.id}"}
            phx-change="update_photo"
            class="notice space-y-2"
          >
            <input type="hidden" name="photo_id" value={photo.id} />
            <img src={photo.thumb_path} alt="" style="width:100%; aspect-ratio:1; object-fit:cover;" />
            <span :if={photo.status != :published} class="badge">{photo.status}</span>
            <input
              name="photo[title]"
              value={photo.title}
              class="input"
              placeholder="Title"
              phx-debounce="600"
            />
            <input
              name="photo[meta]"
              value={photo.meta}
              class="input"
              placeholder="Tile line"
              phx-debounce="600"
            />
            <div class="flex gap-2">
              <select name="photo[tile]" class="select">
                <option
                  :for={t <- ~w(normal big wide)}
                  value={t}
                  selected={to_string(photo.tile) == t}
                >
                  {String.capitalize(t)} tile
                </option>
              </select>
              <input
                name="photo[position]"
                type="number"
                value={photo.position}
                class="input"
                style="width:6rem;"
                aria-label="Position"
                phx-debounce="600"
              />
            </div>
            <button
              type="button"
              phx-click="delete_photo"
              phx-value-id={photo.id}
              data-confirm="Delete this photo?"
              class="link-orange"
            >
              Delete
            </button>
          </form>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    events =
      (Events.list_upcoming_events(category: :official) ++
         Events.list_past_events(category: :official))
      |> Enum.map(&{"#{&1.title} (#{&1.starts_at.year})", &1.id})

    {:ok,
     socket |> assign(:event_options, events) |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    album = %Album{photos: []}

    socket
    |> assign(:page_title, "New Album")
    |> assign(:album, album)
    |> assign(:form, to_form(Gallery.change_album(album)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    album = Gallery.get_album!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Album")
    |> assign(:album, album)
    |> assign(:form, to_form(Gallery.change_album(album)))
  end

  defp reload(socket) do
    assign(
      socket,
      :album,
      Gallery.get_album!(socket.assigns.current_scope, socket.assigns.album.id)
    )
  end

  @impl true
  def handle_event("validate", %{"album" => params}, socket) do
    changeset = Gallery.change_album(socket.assigns.album, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"album" => params}, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.live_action do
        :new -> Gallery.create_album(scope, params)
        :edit -> Gallery.update_album(scope, socket.assigns.album, params)
      end

    case result do
      {:ok, album} ->
        {:noreply,
         socket
         |> put_flash(:info, "Album saved.")
         |> push_navigate(to: ~p"/admin/albums/#{album}/edit")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("update_photo", %{"photo_id" => id, "photo" => attrs}, socket) do
    photo = Enum.find(socket.assigns.album.photos, &(to_string(&1.id) == id))
    {:ok, _} = Gallery.update_photo(socket.assigns.current_scope, photo, attrs)
    {:noreply, reload(socket)}
  end

  def handle_event("delete_photo", %{"id" => id}, socket) do
    photo = Enum.find(socket.assigns.album.photos, &(to_string(&1.id) == id))
    {:ok, _} = Gallery.delete_photo(socket.assigns.current_scope, photo)
    {:noreply, socket |> put_flash(:info, "Photo deleted.") |> reload()}
  end

  def handle_event("delete_album", _params, socket) do
    {:ok, _} = Gallery.delete_album(socket.assigns.current_scope, socket.assigns.album)

    {:noreply,
     socket |> put_flash(:info, "Album deleted.") |> push_navigate(to: ~p"/admin/albums")}
  end
end
