defmodule PevSquadWeb.Admin.RiderLive.Edit do
  use PevSquadWeb, :live_view

  alias PevSquad.{Partners, Riders}
  alias PevSquad.Riders.{Avatar, RiderProfile}

  import PevSquadWeb.RiderComponents, only: [type_options: 0]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:community}>
      <section class="band band-black">
        <div class="panel panel-wide space-y-6">
          <.header :if={@live_action == :new}>
            New rider
            <:subtitle>
              For riders who haven't registered. Once they sign up, link their account here so they can edit it themselves.
            </:subtitle>
          </.header>
          <.header :if={@live_action == :edit}>
            {@rider.alias}
            <:subtitle>
              {source_label(@rider.source)}
              <.link
                :if={@rider.is_public}
                navigate={~p"/community/#{@rider.slug}"}
                class="link-orange"
              >
                View public profile
              </.link>
            </:subtitle>
          </.header>

          <div :if={@live_action == :edit} class="notice space-y-3">
            <%= if @rider.user do %>
              <p>
                Linked to member <strong>{@rider.user.email}</strong>
                — they can edit this profile themselves.
              </p>
              <.button
                phx-click="unlink"
                data-confirm="Unlink this profile from the member's account?"
              >
                Unlink member
              </.button>
            <% else %>
              <p>
                Unclaimed. Once the rider has registered, link their account so they can edit this profile.
              </p>
              <form id="link-form" phx-submit="link" class="flex gap-3 items-end">
                <div class="flex-1">
                  <label class="label mb-1" for="link-email">Member email</label>
                  <input id="link-email" name="email" type="email" class="input" required />
                </div>
                <.button variant="primary">Link</.button>
              </form>
            <% end %>
          </div>

          <.form for={@form} id="rider-form" phx-change="validate" phx-submit="save" class="space-y-2">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input field={@form[:alias]} type="text" label="Alias" required />
              <.input field={@form[:full_name]} type="text" label="Real name (private)" />
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:primary_pev_type]}
                type="select"
                label="Main PEV"
                options={type_options()}
              />
              <.input field={@form[:main_ride]} type="text" label="Model" />
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input field={@form[:city]} type="text" label="City" />
              <.input field={@form[:instagram]} type="text" label="Instagram" />
            </div>
            <.input field={@form[:bio]} type="textarea" label="Bio" />

            <div class="fieldset mb-2">
              <span class="label mb-1">Photo — the rider with their ride</span>
              <div class="flex gap-4 items-start">
                <img
                  :if={@rider.avatar_path && @uploads.avatar.entries == []}
                  src={@rider.avatar_path}
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
                    JPG, PNG or WebP, up to 10 MB. Cropped to a portrait, location data stripped.
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

            <fieldset class="fieldset space-y-2" id="rider-communities">
              <span class="label">
                Partner communities, up to {Riders.max_communities()} (<.link
                  navigate={~p"/admin/partners"}
                  class="link-orange"
                >manage</.link>)
              </span>
              <input type="hidden" name="community_ids[]" value="" />
              <p :if={@all_communities == []} class="text-sm">
                No partner communities yet.
              </p>
              <div class="flex flex-wrap gap-x-6 gap-y-2">
                <label
                  :for={p <- @all_communities}
                  class="flex gap-2 items-center cursor-pointer"
                >
                  <input
                    type="checkbox"
                    name="community_ids[]"
                    value={p.id}
                    checked={p.id in @community_ids}
                    class="checkbox"
                  />
                  <span>{p.name}{if !p.published, do: " (unpublished)"}</span>
                </label>
              </div>
              <p :if={length(@community_ids) > Riders.max_communities()} class="text-sm link-orange">
                Pick at most {Riders.max_communities()}.
              </p>
            </fieldset>
            <.input
              field={@form[:is_public]}
              type="checkbox"
              label="Public (the rider has agreed to be listed)"
            />

            <fieldset class="fieldset space-y-2 pt-4" id="rider-moderation">
              <span class="label">Moderation</span>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <.input
                  field={@form[:status]}
                  type="select"
                  label="Status"
                  options={[{"Active", :active}, {"Inactive", :inactive}, {"Banned", :banned}]}
                />
              </div>
              <.input
                :if={banned?(@form)}
                field={@form[:ban_reason]}
                type="textarea"
                label="Public statement (shown on the rider's page)"
                placeholder="What happened and what PEV Squad did about it."
              />
              <.input
                field={@form[:hidden_by_staff]}
                type="checkbox"
                label="Hidden by admin (overrides the rider's own Public setting)"
              />
              <p class="panel-sub" style="margin-top:0;">
                Inactive riders stay on the roster with a badge. Banned riders leave the roster, but their page stays up with the statement unless hidden.
              </p>
            </fieldset>
            <div class="flex gap-3 pt-4">
              <.button phx-disable-with="Saving..." variant="primary">
                {if @live_action == :new, do: "Create rider", else: "Save"}
              </.button>
              <.button navigate={~p"/admin/riders"}>Back</.button>
            </div>
          </.form>

          <div :if={@live_action == :edit} class="notice space-y-3" id="rider-delete">
            <p>
              Deleting removes the profile and photo for good. {if @rider.user,
                do: "The member's account stays; they can create a new profile."} To keep a public record, ban the rider instead.
            </p>
            <.button
              phx-click="delete"
              data-confirm={"Delete #{@rider.alias}'s profile permanently?"}
            >
              Delete rider
            </.button>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope

    all_communities =
      scope |> Partners.list_all_partners() |> Enum.filter(&(&1.kind == :community))

    socket =
      socket
      |> assign(:all_communities, all_communities)
      |> allow_upload(:avatar,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        max_file_size: Avatar.max_bytes()
      )

    case socket.assigns.live_action do
      :edit ->
        {:ok, assign_rider(socket, Riders.get_rider!(scope, params["id"]))}

      :new ->
        rider = %RiderProfile{source: :staff}

        {:ok,
         socket
         |> assign(:page_title, "Admin · New rider")
         |> assign(:rider, rider)
         |> assign(:form, to_form(Riders.change_rider(rider)))
         |> assign(:community_ids, [])}
    end
  end

  defp assign_rider(socket, rider) do
    socket
    |> assign(:page_title, "Admin · #{rider.alias}")
    |> assign(:rider, rider)
    |> assign(:form, to_form(Riders.change_rider(rider)))
    |> assign(:community_ids, Riders.community_ids(socket.assigns.current_scope, rider))
  end

  defp reload(socket) do
    assign_rider(socket, Riders.get_rider!(socket.assigns.current_scope, socket.assigns.rider.id))
  end

  @impl true
  def handle_event("validate", %{"rider_profile" => params} = all_params, socket) do
    changeset = Riders.change_rider(socket.assigns.rider, params)

    {:noreply,
     socket
     |> assign(:community_ids, community_ids(all_params))
     |> assign(:form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"rider_profile" => params} = all_params, socket) do
    scope = socket.assigns.current_scope
    ids = community_ids(all_params)
    socket = assign(socket, :community_ids, ids)

    if length(ids) > Riders.max_communities() do
      {:noreply,
       put_flash(socket, :error, "Pick at most #{Riders.max_communities()} communities.")}
    else
      # consume_uploaded_entries deletes the temp file when the callback
      # returns, so the save (and image processing) happens inside it.
      results =
        consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
          {:ok, save_rider(socket, params, path)}
        end)

      result =
        case results do
          [result] -> result
          [] -> save_rider(socket, params, nil)
        end

      case result do
        {:ok, rider} ->
          {:ok, _} = Riders.set_communities(scope, rider, ids)

          case socket.assigns.live_action do
            :new ->
              {:noreply,
               socket
               |> put_flash(:info, "#{rider.alias} added.")
               |> push_navigate(to: ~p"/admin/riders/#{rider}/edit")}

            :edit ->
              {:noreply, socket |> put_flash(:info, "Saved.") |> reload()}
          end

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset))}
      end
    end
  end

  def handle_event("delete", _params, socket) do
    {:ok, rider} = Riders.delete_rider(socket.assigns.current_scope, socket.assigns.rider)

    {:noreply,
     socket
     |> put_flash(:info, "#{rider.alias} deleted.")
     |> push_navigate(to: ~p"/admin/riders")}
  end

  def handle_event("link", %{"email" => email}, socket) do
    case Riders.link_to_member(socket.assigns.current_scope, socket.assigns.rider, email) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Linked to #{email}.") |> reload()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, link_error(reason))}
    end
  end

  def handle_event("unlink", _params, socket) do
    {:ok, _} = Riders.unlink_member(socket.assigns.current_scope, socket.assigns.rider)
    {:noreply, socket |> put_flash(:info, "Unlinked.") |> reload()}
  end

  defp save_rider(%{assigns: %{live_action: :new}} = socket, params, photo),
    do: Riders.create_rider(socket.assigns.current_scope, params, photo)

  defp save_rider(socket, params, photo),
    do: Riders.update_rider(socket.assigns.current_scope, socket.assigns.rider, params, photo)

  defp banned?(form), do: to_string(form[:status].value) == "banned"

  defp source_label(:import), do: "Imported from the sign-up form."
  defp source_label(:staff), do: "Added by staff."
  defp source_label(:member), do: "Created by the member."

  defp avatar_errors(form) do
    for {:avatar_path, {msg, _}} <- form.errors, do: msg
  end

  defp upload_error(:too_large), do: "That photo is over 10 MB."
  defp upload_error(:not_accepted), do: "Use a JPG, PNG or WebP photo."
  defp upload_error(:too_many_files), do: "One photo at a time."
  defp upload_error(_), do: "Upload failed — try again."

  defp community_ids(params) do
    params
    |> Map.get("community_ids", [])
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.to_integer/1)
  end

  defp link_error(:no_such_user), do: "No member has registered with that email yet."
  defp link_error(:member_has_profile), do: "That member already has a rider profile."
  defp link_error(:already_claimed), do: "This profile is already linked."
  defp link_error(%Ecto.Changeset{}), do: "Couldn't link — try again."
end
