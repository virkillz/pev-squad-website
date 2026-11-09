defmodule PevSquad.Listings.Notifier do
  @moduledoc "Emails about For Sale listings, each in the recipient's language."
  import Swoosh.Email
  use Gettext, backend: PevSquadWeb.Gettext

  require Logger

  alias PevSquad.Mailer

  # A failed send is logged and never blocks the save.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"PEV Squad", "noreply@pev-squad.org"})
      |> subject(subject)
      |> text_body(Mailer.framed(body))

    case Mailer.deliver(email) do
      {:ok, _metadata} ->
        {:ok, email}

      {:error, reason} = error ->
        Logger.error("listing email to #{recipient} failed: #{inspect(reason)}")
        error
    end
  end

  @doc "`staff` is anything with `:email` and `:locale`."
  def deliver_waiting(staff, listing, url) do
    Mailer.in_locale(staff, fn ->
      deliver(
        staff.email,
        gettext("Listing waiting for approval: %{title}", title: listing.title),
        gettext("A member listing is waiting in the For Sale queue:\n\n  %{title}\n\n%{url}",
          title: listing.title,
          url: url
        )
      )
    end)
  end

  def deliver_approved(user, listing, url) do
    Mailer.in_locale(user, fn ->
      deliver(
        user.email,
        gettext("Your listing is live: %{title}", title: listing.title),
        gettext(
          "Your listing \"%{title}\" has been approved\nand is now on the For Sale board:\n\n%{url}\n\nIt stays up for %{days} days. To keep it up, tap \"Still available\"\non My listings at least once a week. When it sells, mark it sold.",
          title: listing.title,
          url: url,
          days: PevSquad.Listings.fresh_days()
        )
      )
    end)
  end

  def deliver_rejected(user, listing, url) do
    Mailer.in_locale(user, fn ->
      deliver(
        user.email,
        gettext("Your listing needs changes: %{title}", title: listing.title),
        gettext(
          "A moderator sent your listing \"%{title}\"\nback with this note:\n\n  %{note}\n\nEdit and resubmit it here:\n\n%{url}",
          title: listing.title,
          note: listing.rejection_reason,
          url: url
        )
      )
    end)
  end

  def deliver_reminder(user, listing, url) do
    Mailer.in_locale(user, fn ->
      deliver(
        user.email,
        gettext("Is your %{title} still available?", title: listing.title),
        gettext(
          "Your listing \"%{title}\" comes off the For Sale\nboard in 2 days unless you confirm it's still available.\n\nTap \"Still available\" on My listings, or mark it sold:\n\n%{url}",
          title: listing.title,
          url: url
        )
      )
    end)
  end
end
