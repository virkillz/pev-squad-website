defmodule PevSquad.Events.Rsvp do
  use Ecto.Schema

  alias PevSquad.Accounts.User
  alias PevSquad.Events.Event

  # Written only by PevSquad.Events, which decides :going vs :waitlist.
  # inserted_at is microsecond precision because it is the
  # first-come-first-served tiebreaker for waitlist promotion.
  schema "event_rsvps" do
    field :status, Ecto.Enum, values: [:going, :waitlist]

    belongs_to :event, Event
    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end
end
