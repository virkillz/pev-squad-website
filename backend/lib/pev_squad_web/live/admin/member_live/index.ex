defmodule PevSquadWeb.Admin.MemberLive.Index do
  @moduledoc """
  Every account and the rider profile it's linked to. Staff can link a
  member to an unclaimed rider; only admins can change roles.
  """
  use PevSquadWeb, :live_view

  alias PevSquad.{Accounts, Riders}
  alias PevSquad.Accounts.Scope

  @filters [{"All", nil}, {"With profile", :with}, {"No profile", :without}]
  @roles [{"Member", :member}, {"Moderator", :moderator}, {"Admin", :admin}]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:admin}>
      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">
              Admin · {@members_count} {if @members_count == 1, do: "account", else: "accounts"}
            </span>
            <h1 class="section-title">Members</h1>
            <p class="section-lede">
              Everyone who has registered, and the rider profile they're linked to. {if @admin?,
                do: "As an admin you can change roles.",
                else: "Only admins can change roles."}
            </p>
          </div>
          <.link navigate={~p"/admin/riders"} class="btn btn-outline">Riders admin</.link>
        </div>

        <div class="filters" style="margin-bottom:1rem;" id="member-filter">
          <.link
            :for={{label, filter} <- @filters}
            patch={members_path(@search, filter)}
            class={["filter-tag", @profile == filter && "active"]}
          >
            {label}
          </.link>
        </div>

        <form
          id="member-search"
          phx-change="search"
          phx-submit="search"
          class="roster-controls"
          role="search"
        >
          <label class="sr-only" for="member-search-input">Search members</label>
          <input
            id="member-search-input"
            type="search"
            name="q"
            value={@search}
            placeholder="Search email or alias"
            class="input"
            phx-debounce="300"
            autocomplete="off"
          />
        </form>

        <p :if={@members == []} class="section-lede">No members match.</p>

        <.table :if={@members != []} id="members" rows={@members} row_id={&"member-#{&1.user.id}"}>
          <:col :let={m} label="Email">
            {m.user.email}
            <span :if={m.user.id == @current_scope.user.id} class="badge badge-host">You</span>
          </:col>
          <:col :let={m} label="Registered">
            {Calendar.strftime(m.user.inserted_at, "%-d %b %Y")}
            <span :if={is_nil(m.user.confirmed_at)} class="block text-sm" style="color:var(--muted);">
              Email not confirmed
            </span>
          </:col>
          <:col :let={m} label="Role">
            <form
              :if={@admin? && m.user.id != @current_scope.user.id}
              id={"role-#{m.user.id}"}
              phx-submit="set_role"
              class="flex gap-2 items-center"
            >
              <input type="hidden" name="user_id" value={m.user.id} />
              <label class="sr-only" for={"role-select-#{m.user.id}"}>Role</label>
              <select id={"role-select-#{m.user.id}"} name="role" class="select" style="width:auto;">
                <option :for={{label, role} <- @roles} value={role} selected={m.user.role == role}>
                  {label}
                </option>
              </select>
              <.button data-confirm={"Change the role of #{m.user.email}?"}>Set</.button>
            </form>
            <span :if={!@admin? || m.user.id == @current_scope.user.id}>
              {role_label(m.user.role)}
            </span>
          </:col>
          <:col :let={m} label="Rider profile">
            <.link
              :if={m.profile}
              navigate={~p"/admin/riders/#{m.profile.id}/edit"}
              class="link-orange"
            >
              {m.profile.alias}
            </.link>
            <span :if={m.profile} class="block text-sm">{status_label(m.profile.status)}</span>
            <form
              :if={is_nil(m.profile) && @unclaimed != []}
              id={"link-#{m.user.id}"}
              phx-submit="link"
              class="flex gap-2 items-center"
            >
              <input type="hidden" name="user_id" value={m.user.id} />
              <label class="sr-only" for={"link-select-#{m.user.id}"}>Unclaimed rider</label>
              <select
                id={"link-select-#{m.user.id}"}
                name="rider_id"
                class="select"
                style="width:auto;"
                required
              >
                <option value="">Link to rider…</option>
                <option :for={r <- @unclaimed} value={r.id}>{r.alias}</option>
              </select>
              <.button data-confirm={"Link #{m.user.email} to this rider? They'll be able to edit it."}>
                Link
              </.button>
            </form>
            <span :if={is_nil(m.profile) && @unclaimed == []} style="color:var(--muted);">
              No profile
            </span>
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
     |> assign(:page_title, "Admin · Members")
     |> assign(:filters, @filters)
     |> assign(:roles, @roles)
     |> assign(:admin?, Scope.admin?(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    profile =
      Enum.find_value(@filters, fn {_l, f} -> f && to_string(f) == params["profile"] && f end)

    {:noreply,
     socket
     |> assign(:profile, profile)
     |> assign(:search, params["q"] |> to_string() |> String.trim())
     |> load()}
  end

  defp load(socket) do
    scope = socket.assigns.current_scope

    members =
      Accounts.list_members(scope, search: socket.assigns.search, profile: socket.assigns.profile)

    socket
    |> assign(:members, members)
    |> assign(:members_count, length(members))
    |> assign(:unclaimed, Riders.list_unclaimed_riders(scope))
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    path = members_path(String.trim(q), socket.assigns.profile)
    {:noreply, push_patch(socket, to: path, replace: true)}
  end

  def handle_event("set_role", %{"user_id" => id, "role" => role}, socket) do
    %{user: user} = find_member!(socket, id)
    role = Enum.find_value(@roles, fn {_l, r} -> to_string(r) == role && r end)

    case role && Accounts.change_role(socket.assigns.current_scope, user, role) do
      {:ok, user} ->
        {:noreply,
         socket |> put_flash(:info, "#{user.email} is now #{role_label(role)}.") |> load()}

      {:error, :own_role} ->
        {:noreply, put_flash(socket, :error, "You can't change your own role.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Couldn't change the role — try again.")}
    end
  end

  def handle_event("link", %{"user_id" => id, "rider_id" => rider_id}, socket)
      when rider_id != "" do
    scope = socket.assigns.current_scope
    %{user: user} = find_member!(socket, id)
    rider = Riders.get_rider!(scope, rider_id)

    case Riders.link_to_member(scope, rider, user.email) do
      {:ok, _} ->
        {:noreply,
         socket |> put_flash(:info, "#{user.email} is now linked to #{rider.alias}.") |> load()}

      {:error, :member_has_profile} ->
        {:noreply,
         socket |> put_flash(:error, "That member already has a rider profile.") |> load()}

      {:error, :already_claimed} ->
        {:noreply, socket |> put_flash(:error, "#{rider.alias} is already linked.") |> load()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Couldn't link — try again.")}
    end
  end

  def handle_event("link", _params, socket),
    do: {:noreply, put_flash(socket, :error, "Pick a rider to link.")}

  defp find_member!(socket, id) do
    id = String.to_integer(id)

    Enum.find(socket.assigns.members, &(&1.user.id == id)) ||
      raise Ecto.NoResultsError, queryable: Accounts.User
  end

  defp members_path(search, profile) do
    params =
      Enum.reject([profile: profile, q: search != "" && search], fn {_k, v} ->
        v in [nil, false]
      end)

    case params do
      [] -> ~p"/admin/members"
      params -> "/admin/members?" <> URI.encode_query(params)
    end
  end

  defp role_label(:member), do: "Member"
  defp role_label(:moderator), do: "Moderator"
  defp role_label(:admin), do: "Admin"

  defp status_label(:pending), do: "Pending approval"
  defp status_label(:active), do: "Active"
  defp status_label(:inactive), do: "Inactive"
  defp status_label(:banned), do: "Banned"
end
