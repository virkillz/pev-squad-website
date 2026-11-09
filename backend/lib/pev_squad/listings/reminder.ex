defmodule PevSquad.Listings.Reminder do
  @moduledoc """
  Hourly: emails sellers whose listing is about to drop off the For Sale
  board. Started only when `config :pev_squad, :listing_reminders` is true
  (not in tests).
  """
  use GenServer

  require Logger

  @interval :timer.hours(1)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    # Let the endpoint come up before the first run.
    Process.send_after(self(), :run, :timer.minutes(1))
    {:ok, nil}
  end

  @impl true
  def handle_info(:run, state) do
    try do
      count = PevSquad.Listings.send_reminders(PevSquadWeb.Endpoint.url() <> "/for-sale/mine")
      if count > 0, do: Logger.info("sent #{count} listing reminder(s)")
    rescue
      e -> Logger.error("listing reminders failed: " <> Exception.message(e))
    end

    Process.send_after(self(), :run, @interval)
    {:noreply, state}
  end
end
