defmodule PevSquadWeb.ListingLive.Form do
  @moduledoc "Sellers create and edit listings here."
  use PevSquadWeb, :live_view

  alias PevSquad.Listings
  alias PevSquad.Listings.{Listing, Processing}

  import PevSquadWeb.ListingComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:for_sale}>
      <section class="band band-black">
        <div class="panel panel-wide space-y-4">
          <.header>
            {@page_title}
            <:subtitle>
              {gettext(
                "A moderator checks every listing before it goes on the board. Up to %{count} photos, 20 MB each; location data is stripped from every photo.",
                count: Listing.max_photos()
              )}
              <span :if={@listing.status == :approved}>
                {gettext(
                  "Changing the price, quantity, location or contact keeps it live. Changing the title, category, condition, description or photos sends it back for review."
                )}
              </span>
            </:subtitle>
          </.header>

          <.sell_blocked :if={@blocked} reason={@blocked} />

          <.form
            :if={is_nil(@blocked)}
            for={@form}
            id="listing-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-2"
          >
            <.input
              field={@form[:title]}
              type="text"
              label={gettext("What are you selling?")}
              placeholder="Inmotion V11, 2023"
              required
            />
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:category]}
                type="select"
                label={gettext("Category")}
                prompt={gettext("Choose one")}
                options={category_options()}
                required
              />
              <.input
                field={@form[:condition]}
                type="select"
                label={gettext("Condition")}
                prompt={gettext("Choose one")}
                options={condition_options()}
                required
              />
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <.input
                field={@form[:price_idr]}
                type="text"
                inputmode="numeric"
                label={gettext("Price (Rp)")}
                placeholder="12.500.000"
                required
              />
              <.input field={@form[:quantity]} type="number" min="1" label={gettext("Quantity")} />
              <.input
                field={@form[:km]}
                type="text"
                inputmode="numeric"
                label={gettext("Mileage in km (optional)")}
              />
            </div>
            <.input field={@form[:negotiable]} type="checkbox" label={gettext("Price is negotiable")} />
            <.input
              field={@form[:city]}
              type="text"
              label={gettext("Where is it?")}
              placeholder="Jakarta Selatan"
              required
            />
            <.input
              field={@form[:description]}
              type="textarea"
              label={gettext("Description")}
              placeholder={
                gettext(
                  "Condition, battery health, what's included, any repairs, why you're selling, COD or shipping."
                )
              }
              rows="8"
            />

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:whatsapp]}
                type="tel"
                label={gettext("WhatsApp number")}
                placeholder="0812 3456 7890"
              />
              <.input
                field={@form[:instagram]}
                type="text"
                label={gettext("Instagram handle")}
                placeholder="pevsquad"
              />
            </div>
            <p class="meta-text">
              {gettext(
                "Add at least one. Only logged-in members see them, never visitors or search engines."
              )}
            </p>

            <div class="fieldset space-y-3" phx-drop-target={@uploads.photos.ref}>
              <span class="label">
                {gettext("Photos (%{count} of %{max})",
                  count: length(@kept) + length(@uploads.photos.entries),
                  max: Listing.max_photos()
                )}
              </span>
              <div class="listing-uploads">
                <div :for={path <- @kept} class="listing-upload">
                  <img src={thumb_for(@listing, path)} alt="" />
                  <button
                    type="button"
                    phx-click="remove_photo"
                    phx-value-path={path}
                    class="btn btn-ghost btn-sm"
                    aria-label={gettext("Remove")}
                  >
                    ✕
                  </button>
                </div>
                <div :for={entry <- @uploads.photos.entries} class="listing-upload">
                  <.live_img_preview entry={entry} />
                  <button
                    type="button"
                    phx-click="cancel_upload"
                    phx-value-ref={entry.ref}
                    class="btn btn-ghost btn-sm"
                    aria-label={gettext("Remove")}
                  >
                    ✕
                  </button>
                  <p :for={err <- upload_errors(@uploads.photos, entry)} class="text-error">
                    {error_text(err)}
                  </p>
                </div>
              </div>
              <.live_file_input
                :if={length(@kept) + length(@uploads.photos.entries) < Listing.max_photos()}
                upload={@uploads.photos}
                class="input"
              />
              <p :for={err <- upload_errors(@uploads.photos)} class="text-error">
                {error_text(err)}
              </p>
              <p :if={@photo_error} class="text-error" id="photo-error">{@photo_error}</p>
            </div>

            <div class="flex flex-wrap gap-3 pt-4">
              <.button phx-disable-with={gettext("Saving...")} variant="primary">
                {if @live_action == :new,
                  do: gettext("Submit for review"),
                  else: gettext("Save listing")}
              </.button>
              <.button navigate={~p"/for-sale/mine"}>{gettext("Back")}</.button>
            </div>
          </.form>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:photo_error, nil)
     |> allow_upload(:photos,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: Listing.max_photos(),
       max_file_size: Processing.max_bytes()
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope
    listing = Listings.new_listing(scope)

    blocked =
      case Listings.can_sell?(scope) do
        :ok -> nil
        {:error, reason} -> reason
      end

    socket
    |> assign(:page_title, gettext("Sell something"))
    |> assign(:blocked, blocked)
    |> assign(:listing, listing)
    |> assign(:kept, [])
    |> assign(:form, to_form(Listings.change_listing(listing)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    listing = Listings.get_my_listing!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, gettext("Edit listing"))
    |> assign(:blocked, nil)
    |> assign(:listing, listing)
    |> assign(:kept, Enum.map(listing.photos, & &1.large_path))
    |> assign(:form, to_form(Listings.change_listing(listing)))
  end

  @impl true
  def handle_event("validate", %{"listing" => params}, socket) do
    changeset = Listings.change_listing(socket.assigns.listing, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  def handle_event("remove_photo", %{"path" => path}, socket) do
    {:noreply, assign(socket, :kept, List.delete(socket.assigns.kept, path))}
  end

  def handle_event("save", %{"listing" => params}, socket) do
    total = length(socket.assigns.kept) + length(socket.assigns.uploads.photos.entries)

    cond do
      total == 0 ->
        {:noreply, assign(socket, :photo_error, gettext("Add at least one photo."))}

      total > Listing.max_photos() ->
        {:noreply,
         assign(
           socket,
           :photo_error,
           gettext("Up to %{count} photos.", count: Listing.max_photos())
         )}

      true ->
        save(socket, socket.assigns.live_action, params)
    end
  end

  defp save(socket, action, params) do
    scope = socket.assigns.current_scope

    # Copy the uploads out of LiveView's temp files, which are removed as
    # soon as the consume callback returns.
    sources =
      consume_uploaded_entries(socket, :photos, fn %{path: path}, entry ->
        dest =
          Path.join(
            System.tmp_dir!(),
            "listing-#{entry.uuid}#{Path.extname(entry.client_name)}"
          )

        File.cp!(path, dest)
        {:ok, dest}
      end)

    result =
      case action do
        :new ->
          Listings.create_listing(scope, params, sources, review_url: &review_url/1)

        :edit ->
          Listings.update_listing(
            scope,
            socket.assigns.listing,
            params,
            socket.assigns.kept,
            sources,
            review_url: &review_url/1
          )
      end

    Enum.each(sources, &File.rm/1)

    case result do
      {:ok, listing} ->
        {:noreply,
         socket
         |> put_flash(:info, saved_message(action, socket.assigns.listing, listing))
         |> push_navigate(to: ~p"/for-sale/mine")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> assign(:photo_error, photo_error(changeset))}

      {:error, :unreadable} ->
        {:noreply,
         assign(socket, :photo_error, gettext("A photo couldn't be read. Try JPG or PNG."))}

      {:error, reason} ->
        {:noreply, assign(socket, :blocked, reason)}
    end
  end

  defp saved_message(:new, _before, _after),
    do: gettext("Thanks! A moderator will check your listing; we'll email you when it's live.")

  defp saved_message(:edit, %{status: :approved}, %{status: :pending}),
    do: gettext("Saved. Your changes go back to a moderator before they show on the board.")

  defp saved_message(:edit, _before, %{status: :pending}),
    do: gettext("Saved and sent to a moderator.")

  defp saved_message(:edit, _before, _after), do: gettext("Listing saved.")

  defp photo_error(changeset) do
    case changeset.errors[:photos] do
      nil -> nil
      _ -> gettext("Add 1 to %{count} photos.", count: Listing.max_photos())
    end
  end

  defp thumb_for(listing, large_path) do
    case Enum.find(listing.photos, &(&1.large_path == large_path)) do
      nil -> large_path
      photo -> photo.thumb_path
    end
  end

  defp error_text(:too_large), do: gettext("Over 20 MB.")
  defp error_text(:not_accepted), do: gettext("Use JPG, PNG or WebP.")

  defp error_text(:too_many_files),
    do: gettext("Up to %{count} photos.", count: Listing.max_photos())

  defp error_text(_), do: gettext("Upload failed — try again.")

  defp review_url(_listing), do: url(~p"/admin/listings")
end
