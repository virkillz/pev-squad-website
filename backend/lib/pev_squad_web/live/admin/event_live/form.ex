defmodule PevSquadWeb.Admin.EventLive.Form do
  use PevSquadWeb, :live_view

  alias PevSquad.{Events, Gallery, Partners}
  alias PevSquad.Events.Event
  alias PevSquad.Posts.Images

  import PevSquadWeb.EventComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:events}>
      <section class="band band-black">
        <div class="panel panel-wide space-y-4">
          <.header>
            {@page_title}
            <:subtitle>Times are in the event's local timezone.</:subtitle>
          </.header>

          <.form for={@form} id="event-form" phx-change="validate" phx-submit="save" class="space-y-2">
            <.input field={@form[:title]} type="text" label="Title" required />
            <.input
              field={@form[:slug]}
              type="text"
              label="URL slug (leave blank to generate)"
              placeholder="ngeride-ke-bromo-2026"
            />
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <.input field={@form[:kind]} type="select" label="Kind" options={kind_options()} />
              <.input
                field={@form[:role]}
                type="select"
                label="Our role"
                options={[{"Organizer", :organizer}, {"Collaborator", :collaborator}]}
              />
              <.input
                field={@form[:status]}
                type="select"
                label="Status"
                options={[{"Draft", :draft}, {"Published", :published}, {"Cancelled", :cancelled}]}
              />
            </div>
            <fieldset :if={@all_partners != []} class="fieldset space-y-2" id="event-partners">
              <span class="label">
                Partners (<.link navigate={~p"/admin/partners"} class="link-orange">manage</.link>)
              </span>
              <input type="hidden" name="partner_ids[]" value="" />
              <div class="flex flex-wrap gap-x-6 gap-y-2">
                <label :for={p <- @all_partners} class="flex gap-2 items-center cursor-pointer">
                  <input
                    type="checkbox"
                    name="partner_ids[]"
                    value={p.id}
                    checked={MapSet.member?(@partner_ids, p.id)}
                    class="checkbox"
                  />
                  <span>{p.name}</span>
                </label>
              </div>
            </fieldset>
            <.input
              field={@form[:partners]}
              type="text"
              label="Other partners (not in the directory)"
              placeholder="Le Victoria, Aruna Coffee"
            />

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <.input
                field={@form[:starts_at]}
                value={local_input_value(@form[:starts_at], @tz)}
                type="datetime-local"
                label="Starts"
                required
              />
              <.input
                field={@form[:ends_at]}
                value={local_input_value(@form[:ends_at], @tz)}
                type="datetime-local"
                label="Ends (optional)"
              />
              <.input
                field={@form[:timezone]}
                type="select"
                label="Timezone"
                options={timezone_options()}
              />
            </div>

            <.input
              field={@form[:location_name]}
              type="text"
              label="Location"
              placeholder="Bromo, Malang"
            />
            <.input
              field={@form[:meeting_point]}
              type="text"
              label="Meeting point"
              placeholder="Bundaran HI, north side"
            />
            <.input field={@form[:description]} type="textarea" label="Description" />

            <div class="space-y-2" id="event-cover">
              <span class="label">Image (poster or photo)</span>
              <div class="flex gap-4 items-start">
                <img
                  :if={@event.cover_path && @uploads.cover.entries == []}
                  src={@event.cover_path}
                  alt=""
                  style="width:200px; aspect-ratio:3/2; object-fit:cover;"
                />
                <.live_img_preview
                  :for={entry <- @uploads.cover.entries}
                  entry={entry}
                  style="width:200px; aspect-ratio:3/2; object-fit:cover; border:var(--bw) solid var(--orange);"
                />
                <div class="flex-1 space-y-2">
                  <.live_file_input upload={@uploads.cover} class="input" />
                  <p class="panel-sub" style="margin-top:0;">
                    Shown at the top of the event page and in link previews. Up to 15 MB; it's resized and location data removed.
                  </p>
                  <p :for={err <- upload_errors(@uploads.cover)} class="text-error">
                    {upload_error(err)}
                  </p>
                  <%= for entry <- @uploads.cover.entries, err <- upload_errors(@uploads.cover, entry) do %>
                    <p class="text-error">{upload_error(err)}</p>
                  <% end %>
                  <button
                    :if={@event.cover_path && @uploads.cover.entries == []}
                    type="button"
                    phx-click="remove_cover"
                    class="btn btn-ghost"
                  >
                    Remove image
                  </button>
                </div>
              </div>
              <p :if={@cover_error} class="text-error" id="cover-error">{@cover_error}</p>
            </div>

            <fieldset :if={@all_albums != []} class="fieldset space-y-2" id="event-albums">
              <span class="label">
                Photo albums (<.link navigate={~p"/admin/albums"} class="link-orange">manage</.link>)
              </span>
              <input type="hidden" name="album_ids[]" value="" />
              <div class="flex flex-wrap gap-x-6 gap-y-2">
                <label :for={a <- @all_albums} class="flex gap-2 items-center cursor-pointer">
                  <input
                    type="checkbox"
                    name="album_ids[]"
                    value={a.id}
                    checked={MapSet.member?(@album_ids, a.id)}
                    class="checkbox"
                  />
                  <span>{album_label(a, @event)}</span>
                </label>
              </div>
              <p class="panel-sub" style="margin-top:0;">
                Published albums with photos show on the event page and its recap posts. An album belongs to one event, so ticking one linked elsewhere moves it here.
              </p>
            </fieldset>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:capacity]}
                type="number"
                min="1"
                label="Seats (blank = unlimited)"
              />
              <.input
                field={@form[:rsvp_deadline]}
                value={local_input_value(@form[:rsvp_deadline], @tz)}
                type="datetime-local"
                label="RSVP deadline (optional)"
              />
            </div>

            <div class="flex gap-3 pt-4">
              <.button phx-disable-with="Saving..." variant="primary">Save Event</.button>
              <.button navigate={~p"/admin/events"}>Cancel</.button>
            </div>
          </.form>
        </div>
      </section>

      <section :if={@live_action == :edit} class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">{seats_label(@event)}</span>
            <h2 class="section-title">Riders</h2>
          </div>
        </div>
        <.table id="rsvps" rows={@rsvps}>
          <:col :let={rsvp} label="#">{rsvp.position}</:col>
          <:col :let={rsvp} label="Rider">{rsvp.user.email}</:col>
          <:col :let={rsvp} label="Status">{rsvp.status}</:col>
          <:col :let={rsvp} label="RSVP'd at">
            {Calendar.strftime(local(rsvp.inserted_at, @event.timezone), "%d %b %H:%M:%S")}
          </:col>
        </.table>
        <p :if={@rsvps == []} class="event-desc">No RSVPs yet.</p>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:all_partners, Partners.list_all_partners(socket.assigns.current_scope))
     |> assign(:partner_ids, MapSet.new())
     |> assign(:all_albums, Gallery.list_albums_for_staff(socket.assigns.current_scope))
     |> assign(:album_ids, MapSet.new())
     |> assign(:cover_error, nil)
     |> allow_upload(:cover,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: Images.max_bytes()
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    event = %Event{}

    socket
    |> assign(:page_title, "New Event")
    |> assign(:event, event)
    |> assign(:tz, event.timezone)
    |> assign(:form, to_form(Events.change_event(event)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    event = Events.get_event!(socket.assigns.current_scope, id)

    if event.category == :group_ride do
      push_navigate(socket, to: ~p"/group-rides/#{event.id}/edit")
    else
      edit_official(socket, event)
    end
  end

  defp edit_official(socket, event) do
    socket
    |> assign(
      :partner_ids,
      event |> Partners.list_event_partners(all: true) |> MapSet.new(& &1.id)
    )
    |> assign(:album_ids, MapSet.new(Gallery.list_event_album_ids(event)))
    |> assign(:page_title, "Edit Event")
    |> assign(:event, event)
    |> assign(:tz, event.timezone)
    |> assign(:form, to_form(Events.change_event(event)))
    |> assign_rsvps()
  end

  defp assign_rsvps(socket) do
    rsvps =
      Events.list_rsvps(socket.assigns.current_scope, socket.assigns.event)
      |> Enum.chunk_by(& &1.status)
      |> Enum.flat_map(fn group ->
        group |> Enum.with_index(1) |> Enum.map(fn {r, i} -> Map.put(r, :position, i) end)
      end)

    assign(socket, :rsvps, rsvps)
  end

  @impl true
  def handle_event("validate", %{"event" => params} = all_params, socket) do
    params = to_utc_params(params)
    changeset = Events.change_event(socket.assigns.event, params)

    {:noreply,
     socket
     |> assign(:partner_ids, partner_ids(all_params))
     |> assign(:album_ids, ids(all_params, "album_ids"))
     |> assign(:tz, params["timezone"] || socket.assigns.tz)
     |> assign(:form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"event" => params} = all_params, socket) do
    socket =
      socket
      |> assign(:partner_ids, partner_ids(all_params))
      |> assign(:album_ids, ids(all_params, "album_ids"))

    save_event(socket, socket.assigns.live_action, to_utc_params(params))
  end

  def handle_event("remove_cover", _params, socket) do
    {:ok, event} = Events.remove_cover(socket.assigns.current_scope, socket.assigns.event)
    {:noreply, assign(socket, :event, %{socket.assigns.event | cover_path: event.cover_path})}
  end

  defp partner_ids(params), do: ids(params, "partner_ids")

  defp ids(params, key) do
    params
    |> Map.get(key, [])
    |> Enum.reject(&(&1 == ""))
    |> MapSet.new(&String.to_integer/1)
  end

  # Partners, albums and the image are saved after the event itself. A bad
  # image doesn't undo the save: the event is kept and the editor says so.
  defp link_extras(socket, event) do
    scope = socket.assigns.current_scope

    {:ok, _} =
      Partners.set_event_partners(scope, event, MapSet.to_list(socket.assigns.partner_ids))

    {:ok, _} = Gallery.set_event_albums(scope, event, MapSet.to_list(socket.assigns.album_ids))

    results =
      consume_uploaded_entries(socket, :cover, fn %{path: path}, _ ->
        {:ok, Events.set_cover(scope, event, path)}
      end)

    case results do
      [{:error, :bad_image}] -> {:error, event}
      _ -> {:ok, event}
    end
  end

  defp saved(socket, {:ok, event}, message) do
    socket
    |> put_flash(:info, message)
    |> push_navigate(to: ~p"/events/#{event.slug}")
  end

  defp saved(socket, {:error, event}, _message) do
    socket
    |> put_flash(:error, "Event saved, but that image couldn't be read. Try a JPG or PNG.")
    |> push_navigate(to: ~p"/admin/events/#{event.id}/edit")
  end

  defp save_event(socket, :edit, params) do
    case Events.update_event(
           socket.assigns.current_scope,
           socket.assigns.event,
           params,
           &event_url/1
         ) do
      {:ok, event} ->
        {:noreply, saved(socket, link_extras(socket, event), "Event saved.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_event(socket, :new, params) do
    case Events.create_event(socket.assigns.current_scope, params) do
      {:ok, event} ->
        {:noreply, saved(socket, link_extras(socket, event), "Event created.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp event_url(event), do: url(~p"/events/#{event.slug}")

  defp album_label(album, event) do
    notes =
      [
        !album.published && "draft",
        album.event_id && album.event_id != event.id && "linked to another event"
      ]
      |> Enum.filter(& &1)

    case notes do
      [] -> album.title
      notes -> "#{album.title} (#{Enum.join(notes, ", ")})"
    end
  end

  defp upload_error(:too_large), do: "That image is over 15 MB."
  defp upload_error(:not_accepted), do: "Use a JPG, PNG or WebP."
  defp upload_error(:too_many_files), do: "Only one image."
  defp upload_error(_), do: "Upload failed — try again."
end
