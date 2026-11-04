defmodule PevSquadWeb.Admin.RiderLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Riders

  import PevSquadWeb.RiderComponents, only: [type_label: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:community}>
      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Admin · {length(@riders)} profiles · {@unclaimed} unclaimed</span>
            <h1 class="section-title">Riders</h1>
          </div>
          <.link navigate={~p"/admin/events"} class="btn btn-outline">Events admin</.link>
        </div>

        <.table
          id="riders"
          rows={@riders}
          row_click={fn rider -> JS.navigate(~p"/admin/riders/#{rider}/edit") end}
        >
          <:col :let={rider} label="Alias">{rider.alias}</:col>
          <:col :let={rider} label="Type">{type_label(rider.primary_pev_type)}</:col>
          <:col :let={rider} label="City">{rider.city}</:col>
          <:col :let={rider} label="Member account">
            {if rider.user, do: rider.user.email, else: "— unclaimed"}
          </:col>
          <:col :let={rider} label="Public">{if rider.is_public, do: "Yes", else: "Hidden"}</:col>
          <:col :let={rider} label="Featured">{if rider.featured_since, do: "★", else: ""}</:col>
          <:col :let={rider} label="Photo">{if rider.avatar_path, do: "✓", else: ""}</:col>
        </.table>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    riders = Riders.list_all_riders(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Admin · Riders")
     |> assign(:riders, riders)
     |> assign(:unclaimed, Enum.count(riders, &is_nil(&1.user_id)))}
  end
end
