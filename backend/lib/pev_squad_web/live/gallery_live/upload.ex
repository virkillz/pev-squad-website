defmodule PevSquadWeb.GalleryLive.Upload do
  use PevSquadWeb, :live_view

  alias PevSquad.{Gallery, Riders}
  alias PevSquad.Gallery.Processing

  @max_files 10

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:gallery}>
      <section class="band band-black">
        <div class="panel panel-wide space-y-4">
          <.header>
            {gettext("Add photos")}
            <:subtitle>
              {gettext("To")}
              <.link navigate={~p"/gallery/#{@album.slug}"} class="link-orange">{@album.title}</.link>. {gettext(
                "Up to %{count} at a time, 20 MB each. Location data is stripped from every photo.",
                count: @max_files
              )}
              <span :if={!@trusted?}>
                {gettext("A moderator checks new members' photos before they go up.")}
              </span>
            </:subtitle>
          </.header>

          <form id="upload-form" phx-change="validate" phx-submit="save" class="space-y-4">
            <div class="fieldset" phx-drop-target={@uploads.photos.ref}>
              <.live_file_input upload={@uploads.photos} class="input" />
              <p :for={err <- upload_errors(@uploads.photos)} class="text-error">{error_text(err)}</p>
            </div>

            <div :for={entry <- @uploads.photos.entries} class="notice flex gap-4 items-start">
              <.live_img_preview
                entry={entry}
                style="width:120px; aspect-ratio:1; object-fit:cover; border:var(--bw) solid var(--black);"
              />
              <div class="flex-1 space-y-2">
                <input
                  type="text"
                  name={"details[#{entry.ref}][title]"}
                  value={get_in(@details, [entry.ref, "title"])}
                  class="input"
                  placeholder={gettext("Title (optional) — e.g. Purple Hour")}
                  maxlength="60"
                />
                <input
                  type="text"
                  name={"details[#{entry.ref}][caption]"}
                  value={get_in(@details, [entry.ref, "caption"])}
                  class="input"
                  placeholder={gettext("Caption (optional)")}
                  maxlength="300"
                />
                <div class="seat-meter" aria-hidden="true">
                  <span style={"width:#{entry.progress}%"}></span>
                </div>
                <p :for={err <- upload_errors(@uploads.photos, entry)} class="text-error">
                  {error_text(err)}
                </p>
              </div>
              <button
                type="button"
                phx-click="cancel"
                phx-value-ref={entry.ref}
                class="btn btn-ghost btn-sm"
                aria-label={gettext("Remove")}
              >
                ✕
              </button>
            </div>

            <div class="flex gap-3 pt-2">
              <.button
                variant="primary"
                phx-disable-with={gettext("Uploading...")}
                disabled={@uploads.photos.entries == []}
              >
                {if @trusted?, do: gettext("Publish photos"), else: gettext("Submit photos")}
              </.button>
              <.button navigate={~p"/gallery/#{@album.slug}"}>{gettext("Back to album")}</.button>
            </div>
          </form>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    scope = socket.assigns.current_scope
    album = Gallery.get_album_for_upload!(scope, slug)

    cond do
      (blocked = Riders.can_post?(scope)) != :ok ->
        {:ok,
         socket
         |> put_flash(:error, blocked_message(blocked))
         |> push_navigate(to: ~p"/users/profile")}

      not Gallery.can_upload?(scope, album) ->
        {:ok,
         socket
         |> put_flash(:error, gettext("This album isn't taking new photos."))
         |> push_navigate(to: ~p"/gallery")}

      true ->
        {:ok,
         socket
         |> assign(:page_title, gettext("Add photos") <> " · " <> album.title)
         |> assign(:album, album)
         |> assign(:trusted?, Gallery.trusted?(scope))
         |> assign(:max_files, @max_files)
         |> assign(:details, %{})
         |> allow_upload(:photos,
           accept: ~w(.jpg .jpeg .png .webp),
           max_entries: @max_files,
           max_file_size: Processing.max_bytes()
         )}
    end
  end

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, :details, params["details"] || socket.assigns.details)}
  end

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  def handle_event("save", params, socket) do
    scope = socket.assigns.current_scope
    album = socket.assigns.album
    details = params["details"] || %{}

    results =
      consume_uploaded_entries(socket, :photos, fn %{path: path}, entry ->
        {:ok, Gallery.upload_photo(scope, album, path, Map.get(details, entry.ref, %{}))}
      end)

    ok = Enum.count(results, &match?({:ok, _}, &1))
    published = Enum.count(results, &match?({:ok, %{status: :published}}, &1))
    failed = length(results) - ok

    message =
      cond do
        ok == 0 ->
          nil

        published == ok ->
          ngettext("1 photo added to %{album}.", "%{count} photos added to %{album}.", ok,
            album: album.title
          )

        true ->
          ngettext(
            "1 photo sent to the moderators — it'll be up once approved.",
            "%{count} photos sent to the moderators — they'll be up once approved.",
            ok
          )
      end

    socket =
      socket
      |> assign(:details, %{})
      |> then(&if(message, do: put_flash(&1, :info, message), else: &1))
      |> then(
        &if(failed > 0,
          do:
            put_flash(
              &1,
              :error,
              ngettext(
                "1 photo couldn't be read — try JPG or PNG.",
                "%{count} photos couldn't be read — try JPG or PNG.",
                failed
              )
            ),
          else: &1
        )
      )

    if ok > 0 and failed == 0,
      do: {:noreply, push_navigate(socket, to: ~p"/gallery/#{album.slug}")},
      else: {:noreply, socket}
  end

  defp error_text(:too_large), do: gettext("Over 20 MB.")
  defp error_text(:not_accepted), do: gettext("Use JPG, PNG or WebP.")

  defp error_text(:too_many_files),
    do: gettext("Up to %{count} photos at a time.", count: @max_files)

  defp error_text(_), do: gettext("Upload failed — try again.")

  defp blocked_message({:error, :no_profile}),
    do: gettext("Set up your rider profile first — photos are credited to your alias.")

  defp blocked_message({:error, :pending}),
    do: gettext("You can share photos once a moderator approves your rider profile.")
end
