defmodule PevSquad.Riders.Notifier do
  import Swoosh.Email

  require Logger

  alias PevSquad.Mailer
  alias PevSquad.Riders.RiderProfile

  # Sent synchronously; a failed send is logged, never blocks the save.
  def deliver_profile_waiting(to_email, %RiderProfile{} = profile, url) do
    new()
    |> to(to_email)
    |> from({"PEV Squad", "noreply@pev-squad.org"})
    |> subject("New rider waiting for approval: #{profile.alias}")
    |> text_body("""

    ==============================

    #{profile.alias}#{if profile.city, do: " (#{profile.city})"} just created a rider
    profile. It stays hidden, and they can't post photos, reviews or group
    rides, until a moderator approves it.

    #{url}

    ==============================
    """)
    |> deliver()
  end

  def deliver_profile_approved(to_email, %RiderProfile{} = profile, url) do
    new()
    |> to(to_email)
    |> from({"PEV Squad", "noreply@pev-squad.org"})
    |> subject("You're in the Squad, #{profile.alias}")
    |> text_body("""

    ==============================

    Your PEV Squad rider profile has been approved.#{if profile.is_public, do: " It's now on the Community page:", else: ""}

    #{url}

    You can now share photos in the gallery, write reviews and host group rides.

    ==============================
    """)
    |> deliver()
  end

  defp deliver(email) do
    case Mailer.deliver(email) do
      {:ok, _metadata} ->
        {:ok, email}

      {:error, reason} = error ->
        Logger.warning("Rider email to #{inspect(email.to)} failed: #{inspect(reason)}")
        error
    end
  end
end
