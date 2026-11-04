defmodule PevSquadWeb.RiderComponents do
  @moduledoc "Rider cards and labels, matching the prototype's community roster."
  use PevSquadWeb, :html

  alias PevSquad.Riders.RiderProfile

  @type_labels %{euc: "EUC", escooter: "Scooter", esk8: "Esk8", ebike: "E-Bike", other: "Other"}

  def type_label(type), do: Map.fetch!(@type_labels, type)

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
        <span class="badge">{type_label(@rider.primary_pev_type)}</span>
      </div>
      <img
        :if={@rider.avatar_path}
        class="card-photo"
        src={@rider.avatar_path}
        alt={"#{@rider.alias} with their #{@rider.main_ride || type_label(@rider.primary_pev_type)}"}
        loading="lazy"
      />
      <div class="card-body">
        <h3 class="card-title">
          {@rider.alias}
        </h3>
        <p class="card-meta">{card_meta(@rider)}</p>
        <p :if={@rider.bio} class="card-desc">{@rider.bio}</p>
      </div>
    </.link>
    """
  end
end
