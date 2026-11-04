defmodule PevSquad.Events.Notifier do
  import Swoosh.Email

  alias PevSquad.Events.Event
  alias PevSquad.Mailer

  # Sent synchronously for now; moves to an Oban worker (with push) once
  # the mobile app exists.
  def deliver_waitlist_promotion(user, %Event{} = event, url) do
    email =
      new()
      |> to(user.email)
      |> from({"PEV Squad", "noreply@pev-squad.org"})
      |> subject("You're in: #{event.title}")
      |> text_body("""

      ==============================

      A seat opened up for #{event.title} and you were next on the waitlist —
      you're now marked as going.

      #{url}

      Can't make it any more? Cancel from the event page so the next rider
      gets your seat.

      ==============================
      """)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def deliver_event_cancelled(user, %Event{} = event, url) do
    email =
      new()
      |> to(user.email)
      |> from({"PEV Squad", "noreply@pev-squad.org"})
      |> subject("Cancelled: #{event.title}")
      |> text_body("""

      ==============================

      #{event.title} has been cancelled, so your RSVP no longer applies.

      #{url}

      Keep an eye on the events page for the next one.

      ==============================
      """)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
