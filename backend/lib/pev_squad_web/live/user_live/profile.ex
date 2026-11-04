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
            Rider profile
            <:subtitle>
              How you show up on the Community page. Your real name stays private.
              Login details live in <.link navigate={~p"/users/settings"} class="link-orange">email &amp; password settings</.link>.
            </:subtitle>
          </.header>

          <p :if={@profile.id && @profile.is_public} class="notice">
            Live at
            <.link navigate={~p"/community/#{@profile.slug}"} class="link-orange">
              /community/{@profile.slug}
            </.link>
          </p>

          <.form
            for={@form}
            id="profile-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-2"
          >
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input field={@form[:alias]} type="text" label="Alias (shown publicly)" required />
              <.input field={@form[:full_name]} type="text" label="Real name (private)" />
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:primary_pev_type]}
                type="select"
                label="Main PEV"
                options={type_options()}
              />
              <.input
                field={@form[:main_ride]}
                type="text"
                label="Model"
                placeholder="Veteran Sherman L"
              />
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input field={@form[:city]} type="text" label="City" placeholder="Jakarta" />
              <.input field={@form[:instagram]} type="text" label="Instagram" placeholder="pevsquad" />
            </div>
            <.input field={@form[:bio]} type="textarea" label="Bio (max 500 characters)" />

            <div class="fieldset mb-2">
              <span class="label mb-1">Photo — you with your ride</span>
              <div class="flex gap-4 items-start">
                <img
                  :if={@profile.avatar_path && @uploads.avatar.entries == []}
                  src={@profile.avatar_path}
                  alt="Current photo"
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
                    JPG, PNG or WebP, up to 10 MB. We crop it to a portrait and strip location data.
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
              label="Show my profile on the public Community page"
            />

            <div class="flex gap-3 pt-4">
              <.button phx-disable-with="Saving..." variant="primary">Save profile</.button>
            </div>
          </.form>
        </div>
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
     |> assign(:page_title, "Rider profile")
     |> assign(:profile, profile)
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

  def handle_event("save", %{"rider_profile" => params}, socket) do
    scope = socket.assigns.current_scope

    # consume_uploaded_entries deletes the temp file when the callback
    # returns, so the save (and image processing) happens inside it.
    results =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
        {:ok, Riders.save_my_profile(scope, params, path)}
      end)

    result =
      case results do
        [result] -> result
        [] -> Riders.save_my_profile(scope, params)
      end

    case result do
      {:ok, profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile saved.")
         |> assign(:profile, profile)
         |> assign(:form, to_form(Riders.change_profile(profile)))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp avatar_errors(form) do
    Enum.map(form.errors, fn
      {:avatar_path, {msg, _}} -> msg
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp upload_error(:too_large), do: "That photo is over 10 MB."
  defp upload_error(:not_accepted), do: "Use a JPG, PNG or WebP photo."
  defp upload_error(:too_many_files), do: "One photo at a time."
  defp upload_error(_), do: "Upload failed — try again."
end
