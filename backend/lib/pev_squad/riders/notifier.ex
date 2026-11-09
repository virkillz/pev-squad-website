defmodule PevSquad.Riders.Notifier do
  import Swoosh.Email
  use Gettext, backend: PevSquadWeb.Gettext

  require Logger

  alias PevSquad.Mailer
  alias PevSquad.Riders.RiderProfile

  # Sent synchronously; a failed send is logged, never blocks the save.
  # `staff` is the moderator being told (anything with :email and :locale).
  def deliver_profile_waiting(staff, %RiderProfile{} = profile, url) do
    Mailer.in_locale(staff, fn ->
      rider = if profile.city, do: "#{profile.alias} (#{profile.city})", else: profile.alias

      new()
      |> to(staff.email)
      |> from({"PEV Squad", "noreply@pev-squad.org"})
      |> subject(gettext("New rider waiting for approval: %{rider}", rider: profile.alias))
      |> text_body(
        Mailer.framed(
          gettext(
            "%{rider} just created a rider\nprofile. It stays hidden, and they can't post photos, reviews or group\nrides, until a moderator approves it.\n\n%{url}",
            rider: rider,
            url: url
          )
        )
      )
      |> deliver()
    end)
  end

  def deliver_profile_approved(user, %RiderProfile{} = profile, url) do
    Mailer.in_locale(user, fn ->
      intro =
        if profile.is_public,
          do:
            gettext(
              "Your PEV Squad rider profile has been approved. It's now on the Community page:"
            ),
          else: gettext("Your PEV Squad rider profile has been approved.")

      new()
      |> to(user.email)
      |> from({"PEV Squad", "noreply@pev-squad.org"})
      |> subject(gettext("You're in the Squad, %{rider}", rider: profile.alias))
      |> text_body(
        Mailer.framed(
          intro <>
            "\n\n#{url}\n\n" <>
            gettext(
              "You can now share photos in the gallery, write reviews and host group rides."
            )
        )
      )
      |> deliver()
    end)
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
