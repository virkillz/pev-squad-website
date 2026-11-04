defmodule PevSquad.Safety.Block do
  use Ecto.Schema

  schema "blocks" do
    belongs_to :blocker, PevSquad.Accounts.User
    belongs_to :blocked, PevSquad.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
