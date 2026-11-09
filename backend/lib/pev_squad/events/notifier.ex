defmodule PevSquad.Events.Notifier do
  import Swoosh.Email
  use Gettext, backend: PevSquadWeb.Gettext

  alias PevSquad.Events.Event
  alias PevSquad.Mailer

  # Sent synchronously for now; moves to an Oban worker (with push) once
  # the mobile app exists. Each email is in the recipient's language.
  def deliver_waitlist_promotion(user, %Event{} = event, url) do
    Mailer.in_locale(user, fn ->
      deliver(
        user,
        gettext("You're in: %{title}", title: event.title),
        gettext(
          "A seat opened up for %{title} and you were next on the waitlist —\nyou're now marked as going.\n\n%{url}\n\nCan't make it any more? Cancel from the event page so the next rider\ngets your seat.",
          title: event.title,
          url: url
        )
      )
    end)
  end

  def deliver_event_cancelled(user, %Event{} = event, url) do
    Mailer.in_locale(user, fn ->
      deliver(
        user,
        gettext("Cancelled: %{title}", title: event.title),
        gettext(
          "%{title} has been cancelled, so your RSVP no longer applies.\n\n%{url}\n\nKeep an eye on the events page for the next one.",
          title: event.title,
          url: url
        )
      )
    end)
  end

  defp deliver(user, subject, body) do
    email =
      new()
      |> to(user.email)
      |> from({"PEV Squad", "noreply@pev-squad.org"})
      |> subject(subject)
      |> text_body(Mailer.framed(body))

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
