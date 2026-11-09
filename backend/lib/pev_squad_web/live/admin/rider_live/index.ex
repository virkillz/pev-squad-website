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
            <span class="eyebrow">
              Admin · {length(@riders)} profiles · {@unclaimed} unclaimed · {@pending} pending
            </span>
            <h1 class="section-title">Riders</h1>
          </div>
          <div class="flex flex-wrap gap-3">
            <.link navigate={~p"/admin/riders/new"} class="btn btn-primary">New Rider</.link>
            <.link navigate={~p"/admin/events"} class="btn btn-outline">Events admin</.link>
          </div>
        </div>

        <div class="filters" style="margin-bottom:1.5rem;" id="rider-status-filter">
          <.link
            :for={{label, status} <- @status_filters}
            patch={if status, do: ~p"/admin/riders?status=#{status}", else: ~p"/admin/riders"}
            class={["filter-tag", @status == status && "active"]}
          >
            {label}{if status == :pending && @pending > 0, do: " (#{@pending})"}
          </.link>
        </div>

        <p :if={@riders == []} class="section-lede">No riders with this status.</p>

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
          <:col :let={rider} label="Status">{status_label(rider.status)}</:col>
          <:col :let={rider} label="Public">{visibility_label(rider)}</:col>
          <:col :let={rider} label="Photo">{if rider.avatar_path, do: "✓", else: ""}</:col>
        </.table>
      </section>
    </Layouts.app>
    """
  end

  defp status_label(:pending), do: "Pending approval"
  defp status_label(:active), do: "Active"
  defp status_label(:inactive), do: "Inactive"
  defp status_label(:banned), do: "Banned"

  defp visibility_label(%{hidden_by_staff: true}), do: "Hidden by admin"
  defp visibility_label(%{is_public: true}), do: "Yes"
  defp visibility_label(_), do: "Not public"

  @status_filters [
    {"All", nil},
    {"Pending", :pending},
    {"Active", :active},
    {"Inactive", :inactive},
    {"Banned", :banned}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin · Riders")
     |> assign(:status_filters, @status_filters)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    status =
      Enum.find_value(@status_filters, fn {_label, s} ->
        s && to_string(s) == params["status"] && s
      end)

    riders = Riders.list_all_riders(scope, status: status)

    {:noreply,
     socket
     |> assign(:status, status)
     |> assign(:riders, riders)
     |> assign(:unclaimed, Enum.count(riders, &is_nil(&1.user_id)))
     |> assign(:pending, Riders.count_pending(scope))}
  end
end
