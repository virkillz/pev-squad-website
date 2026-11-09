defmodule PevSquadWeb.UserLive.Profile do
  use PevSquadWeb, :live_view

  alias PevSquad.Riders
  alias PevSquad.Riders.{Avatar, RiderProfile}

  import PevSquadWeb.RiderComponents, only: [type_options: 0]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:account}>
      <section class="band band-black">
        <div class="panel panel-wide space-y-4">
          <.header>
            {gettext("Rider profile")}
            <:subtitle>
              {gettext("How you show up on the Community page. Your real name stays private.")}
              {gettext("Login details live in")}
              <.link navigate={~p"/users/settings"} class="link-orange">
                {gettext("email & password settings")}
              </.link>
            </:subtitle>
          </.header>

          <p :if={@profile.status == :pending} class="notice" id="profile-pending">
            <strong>{gettext("Waiting for approval.")}</strong>
            {gettext(
              "A moderator checks every new profile before it appears on the Community page, so nobody can claim to be in the Squad without us knowing them. We'll email you once you're approved. Until then you can still RSVP to rides; photos, reviews and hosting group rides open up after approval."
            )}
          </p>
          <p :if={@profile.status == :banned} class="notice" id="profile-banned">
            {gettext(
              "Your profile has been banned by PEV Squad staff and can't be edited. Contact an admin if you think this is a mistake."
            )}
          </p>
          <p
            :if={@profile.hidden_by_staff && @profile.status != :banned}
            class="notice"
            id="profile-hidden"
          >
            {gettext(
              "Staff have hidden your profile from the public site. Contact an admin to find out why."
            )}
          </p>

          <p
            :if={
              @profile.id && @profile.is_public && !@profile.hidden_by_staff &&
                @profile.status in [:active, :inactive]
            }
            class="notice"
          >
            {gettext("Live at")}
            <.link navigate={~p"/community/#{@profile.slug}"} class="link-orange">
              /community/{@profile.slug}
            </.link>
          </p>

          <.form
            :if={@profile.status != :banned}
            for={@form}
            id="profile-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-2"
          >
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:alias]}
                type="text"
                label={gettext("Alias (shown publicly)")}
                required
              />
              <.input field={@form[:full_name]} type="text" label={gettext("Real name (private)")} />
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:primary_pev_type]}
                type="select"
                label={gettext("Main PEV")}
                options={type_options()}
              />
              <.input
                field={@form[:main_ride]}
                type="text"
                label={gettext("Model")}
                placeholder="Veteran Sherman L"
              />
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input field={@form[:city]} type="text" label={gettext("City")} placeholder="Jakarta" />
              <.input field={@form[:instagram]} type="text" label="Instagram" placeholder="pevsquad" />
            </div>
            <.input field={@form[:bio]} type="textarea" label={gettext("Bio (max 500 characters)")} />

            <div class="fieldset mb-2">
              <span class="label mb-1">{gettext("Photo — you with your ride")}</span>
              <div class="flex gap-4 items-start">
                <img
                  :if={@profile.avatar_path && @uploads.avatar.entries == []}
                  src={@profile.avatar_path}
                  alt={gettext("Current photo")}
                  style="width:96px; aspect-ratio:4/5; object-fit:cover; border:var(--bw) solid var(--black);"
                />
                <.live_img_preview
                  :for={entry <- @uploads.avatar.entries}
                  entry={entry}
                  style="width:96px; aspect-ratio:4/5; object-fit:cover; border:var(--bw) solid var(--orange);"
                />
                <div class="flex-1 space-y-2">
                  <.live_file_input upload={@uploads.avatar} class="input" />
                  <p class="panel-sub" style="margin-top:0;">
                    {gettext(
                      "JPG, PNG or WebP, up to 10 MB. We crop it to a portrait and strip location data."
                    )}
                  </p>
                  <p :for={err <- upload_errors(@uploads.avatar)} class="text-error">
                    {upload_error(err)}
                  </p>
                  <%= for entry <- @uploads.avatar.entries, err <- upload_errors(@uploads.avatar, entry) do %>
                    <p class="text-error">{upload_error(err)}</p>
                  <% end %>
                  <p :for={msg <- avatar_errors(@form)} class="text-error">{msg}</p>
                </div>
              </div>
            </div>

            <.input
              field={@form[:is_public]}
              type="checkbox"
              label={gettext("Show my profile on the public Community page")}
            />

            <div class="flex gap-3 pt-4">
              <.button phx-disable-with={gettext("Saving...")} variant="primary">
                {gettext("Save profile")}
              </.button>
            </div>
          </.form>
        </div>
      </section>

      <section :if={@profile.id} class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">{gettext("Your reviews")}</span>
            <h2 class="section-title">{gettext("My Reviews")}</h2>
          </div>
          <.link navigate={~p"/reviews/new"} class="btn btn-primary">
            {gettext("Write a Review")}
          </.link>
        </div>
        <.table
          :if={@my_reviews != []}
          id="my-reviews"
          rows={@my_reviews}
          row_click={fn r -> JS.navigate(~p"/reviews/#{r.id}") end}
        >
          <:col :let={r} label={gettext("Model")}>
            {PevSquad.Reviews.PevModel.full_name(r.pev_model)}
          </:col>
          <:col :let={r} label={gettext("Headline")}>{r.headline}</:col>
          <:col :let={r} label={gettext("Status")}>{review_status(r)}</:col>
        </.table>
        <p :if={@my_reviews == []} class="section-lede">
          {gettext("No reviews yet. Own a wheel, board or scooter? Tell the squad how it rides.")}
        </p>
      </section>

      <section :if={@blocked != []} class="band band-black">
        <div class="section-head">
          <div>
            <span class="eyebrow">{gettext("Hidden from you")}</span>
            <h2 class="section-title">{gettext("Blocked Riders")}</h2>
          </div>
        </div>
        <ul class="attendee-list" id="blocked">
          <li :for={b <- @blocked} class="flex gap-3 items-center">
            {b.alias || gettext("Member without a profile")}
            <button type="button" phx-click="unblock" phx-value-id={b.user_id} class="link-orange">
              {gettext("Unblock")}
            </button>
          </li>
        </ul>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    profile =
      Riders.get_my_profile(socket.assigns.current_scope) || %RiderProfile{is_public: true}

    {:ok,
     socket
     |> assign(:page_title, gettext("Rider profile"))
     |> assign(:profile, profile)
     |> assign(:my_reviews, PevSquad.Reviews.list_my_reviews(socket.assigns.current_scope))
     |> assign(:blocked, PevSquad.Safety.list_blocked(socket.assigns.current_scope))
     |> assign(:form, to_form(Riders.change_profile(profile)))
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: Avatar.max_bytes()
     )}
  end

  @impl true
  def handle_event("validate", %{"rider_profile" => params}, socket) do
    changeset = Riders.change_profile(socket.assigns.profile, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("unblock", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    :ok = PevSquad.Safety.unblock(scope, String.to_integer(id))
    {:noreply, assign(socket, :blocked, PevSquad.Safety.list_blocked(scope))}
  end

  def handle_event("save", %{"rider_profile" => params}, socket) do
    scope = socket.assigns.current_scope

    # consume_uploaded_entries deletes the temp file when the callback
    # returns, so the save (and image processing) happens inside it.
    results =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
        {:ok, Riders.save_my_profile(scope, params, path, review_url: &admin_url/1)}
      end)

    result =
      case results do
        [result] -> result
        [] -> Riders.save_my_profile(scope, params, nil, review_url: &admin_url/1)
      end

    case result do
      {:ok, profile} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           if(profile.status == :pending,
             do: gettext("Profile saved. A moderator will check it before it goes live."),
             else: gettext("Profile saved.")
           )
         )
         |> assign(:profile, profile)
         |> assign(:form, to_form(Riders.change_profile(profile)))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, :banned} ->
        {:noreply,
         put_flash(socket, :error, gettext("Your profile has been banned and can't be edited."))}
    end
  end

  defp admin_url(profile), do: url(~p"/admin/riders/#{profile.id}/edit")

  defp review_status(%{status: :published}), do: gettext("Live")
  defp review_status(%{status: :pending}), do: gettext("Waiting for a moderator")
  defp review_status(%{status: :rejected}), do: gettext("Sent back — edit and resubmit")

  defp avatar_errors(form) do
    Enum.map(form.errors, fn
      {:avatar_path, error} -> translate_error(error)
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp upload_error(:too_large), do: gettext("That photo is over 10 MB.")
  defp upload_error(:not_accepted), do: gettext("Use a JPG, PNG or WebP photo.")
  defp upload_error(:too_many_files), do: gettext("One photo at a time.")
  defp upload_error(_), do: gettext("Upload failed — try again.")
end
