defmodule PevSquad.Accounts.UserNotifier do
  import Swoosh.Email
  use Gettext, backend: PevSquadWeb.Gettext

  alias PevSquad.Mailer
  alias PevSquad.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"PEV Squad", "noreply@pev-squad.org"})
      |> subject(subject)
      |> text_body(Mailer.framed(body))

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  # These are sent while the rider is on the site, so a rider who hasn't
  # saved a language yet gets the one they're browsing in.
  defp in_locale(user, fun),
    do: Mailer.in_locale(user.locale || Gettext.get_locale(PevSquadWeb.Gettext), fun)

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    in_locale(user, fn ->
      deliver(
        user.email,
        gettext("Update email instructions"),
        gettext(
          "Hi %{email},\n\nYou can change your email by visiting the URL below:\n\n%{url}\n\nIf you didn't request this change, please ignore this.",
          email: user.email,
          url: url
        )
      )
    end)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    in_locale(user, fn ->
      deliver(
        user.email,
        gettext("Log in instructions"),
        gettext(
          "Hi %{email},\n\nYou can log into your account by visiting the URL below:\n\n%{url}\n\nIf you didn't request this email, please ignore this.",
          email: user.email,
          url: url
        )
      )
    end)
  end

  defp deliver_confirmation_instructions(user, url) do
    in_locale(user, fn ->
      deliver(
        user.email,
        gettext("Confirmation instructions"),
        gettext(
          "Hi %{email},\n\nYou can confirm your account by visiting the URL below:\n\n%{url}\n\nIf you didn't create an account with us, please ignore this.",
          email: user.email,
          url: url
        )
      )
    end)
  end
end
