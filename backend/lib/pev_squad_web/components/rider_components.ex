defmodule PevSquadWeb.RiderComponents do
  @moduledoc "Rider cards and labels, matching the prototype's community roster."
  use PevSquadWeb, :html

  alias PevSquad.Riders.RiderProfile

  def type_label(:euc), do: "EUC"
  def type_label(:escooter), do: gettext("Scooter")
  def type_label(:esk8), do: "Esk8"
  def type_label(:ebike), do: "E-Bike"
  def type_label(:other), do: gettext("Other")

  def type_options, do: Enum.map(RiderProfile.pev_types(), &{type_label(&1), &1})

  @doc "\"WY\" for Wynn, \"SG\" for Si Ganteng."
  def initials(alias_name) do
    case String.split(alias_name) do
      [one] -> one |> String.slice(0, 2) |> String.upcase()
      [first, second | _] -> String.upcase(String.first(first) <> String.first(second))
    end
  end

  def card_meta(%RiderProfile{} = rider) do
    [rider.city, rider.main_ride]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
    |> String.upcase()
  end

  attr :rider, RiderProfile, required: true

  def rider_card(assigns) do
    ~H"""
    <.link navigate={~p"/community/#{@rider.slug}"} class="card" style="text-decoration:none;">
      <div class="card-head">
        <span class="card-initials">{initials(@rider.alias)}</span>
        <span class="flex gap-1">
          <span :if={@rider.status == :inactive} class="badge badge-grey">
            {gettext("Inactive")}
          </span>
          <span class="badge">{type_label(@rider.primary_pev_type)}</span>
        </span>
      </div>
      <img
        :if={@rider.avatar_path}
        class="card-photo"
        src={@rider.avatar_path}
        alt={
          gettext("%{rider} with their %{ride}",
            rider: @rider.alias,
            ride: @rider.main_ride || type_label(@rider.primary_pev_type)
          )
        }
        loading="lazy"
      />
      <div class="card-body">
        <h3 class="card-title">
          {@rider.alias}
        </h3>
        <p class="card-meta">{card_meta(@rider)}</p>
        <%!-- The Squad mark first on every card, then the partner communities they also ride with. --%>
        <div class="rider-communities">
          <span class="rider-community" title="PEV Squad">
            <img src={~p"/images/logo.jpg"} alt={gettext("PEV Squad logo")} loading="lazy" />
          </span>
          <span
            :for={p <- @rider.communities}
            class="rider-community"
            title={p.name}
          >
            <img
              :if={p.logo_path}
              src={p.logo_path}
              alt={gettext("%{name} logo", name: p.name)}
              loading="lazy"
            />
            <span :if={!p.logo_path}>{PevSquadWeb.PartnerComponents.initials(p.name)}</span>
          </span>
        </div>
        <p :if={@rider.bio} class="card-desc">{@rider.bio}</p>
      </div>
    </.link>
    """
  end
end
