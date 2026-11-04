defmodule PevSquadWeb.Admin.RiderLive.Edit do
  use PevSquadWeb, :live_view

  alias PevSquad.Riders

  import PevSquadWeb.RiderComponents, only: [type_options: 0]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:community}>
      <section class="band band-black">
        <div class="panel panel-wide space-y-6">
          <.header>
            {@rider.alias}
            <:subtitle>
              {if @rider.source == :import,
                do: "Imported from the sign-up form.",
                else: "Created by the member."}
              <.link
                :if={@rider.is_public}
                navigate={~p"/community/#{@rider.slug}"}
                class="link-orange"
              >
                View public profile
              </.link>
            </:subtitle>
          </.header>

          <div class="notice space-y-3">
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

          <div class="notice flex gap-4 items-center justify-between">
            <p :if={@rider.featured_since}>
              ★ Featured Rider since {Calendar.strftime(@rider.featured_since, "%d %b %Y")}
            </p>
            <p :if={!@rider.featured_since}>
              Not a Featured Rider. The bar: 5,000 km, a year riding with the squad, several units owned.
            </p>
            <.button
              phx-click="toggle_featured"
              variant={if is_nil(@rider.featured_since), do: "primary"}
            >
              {if @rider.featured_since, do: "Remove badge", else: "Make Featured"}
            </.button>
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
            <.input
              field={@form[:is_public]}
              type="checkbox"
              label="Public (the rider has agreed to be listed)"
            />
            <div class="flex gap-3 pt-4">
              <.button phx-disable-with="Saving..." variant="primary">Save</.button>
              <.button navigate={~p"/admin/riders"}>Back</.button>
            </div>
          </.form>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, assign_rider(socket, Riders.get_rider!(socket.assigns.current_scope, id))}
  end

  defp assign_rider(socket, rider) do
    socket
    |> assign(:page_title, "Admin · #{rider.alias}")
    |> assign(:rider, rider)
    |> assign(:form, to_form(Riders.change_profile(rider)))
  end

  defp reload(socket) do
    assign_rider(socket, Riders.get_rider!(socket.assigns.current_scope, socket.assigns.rider.id))
  end

  @impl true
  def handle_event("validate", %{"rider_profile" => params}, socket) do
    changeset = Riders.change_profile(socket.assigns.rider, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"rider_profile" => params}, socket) do
    case Riders.update_rider(socket.assigns.current_scope, socket.assigns.rider, params) do
      {:ok, _rider} -> {:noreply, socket |> put_flash(:info, "Saved.") |> reload()}
      {:error, changeset} -> {:noreply, assign(socket, :form, to_form(changeset))}
    end
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

  def handle_event("toggle_featured", _params, socket) do
    rider = socket.assigns.rider

    {:ok, _} =
      Riders.set_featured(socket.assigns.current_scope, rider, is_nil(rider.featured_since))

    {:noreply, reload(socket)}
  end

  defp link_error(:no_such_user), do: "No member has registered with that email yet."
  defp link_error(:member_has_profile), do: "That member already has a rider profile."
  defp link_error(:already_claimed), do: "This profile is already linked."
  defp link_error(%Ecto.Changeset{}), do: "Couldn't link — try again."
end
