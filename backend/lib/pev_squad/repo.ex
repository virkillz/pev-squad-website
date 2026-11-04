defmodule PevSquad.Repo do
  use Ecto.Repo,
    otp_app: :pev_squad,
    adapter: Ecto.Adapters.Postgres
end
