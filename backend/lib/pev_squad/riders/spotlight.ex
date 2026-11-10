defmodule PevSquad.Riders.Spotlight do
  @moduledoc """
  The rider of the day for one date (Jakarta time). Written only by
  `PevSquad.Riders`; `picked_by_id` is set when staff chose the rider.
  """
  use Ecto.Schema

  schema "rider_spotlights" do
    field :date, :date

    belongs_to :rider_profile, PevSquad.Riders.RiderProfile
    belongs_to :picked_by, PevSquad.Accounts.User

    timestamps(type: :utc_datetime)
  end
end
