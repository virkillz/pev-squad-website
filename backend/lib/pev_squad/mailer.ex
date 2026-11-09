defmodule PevSquad.Mailer do
  use Swoosh.Mailer, otp_app: :pev_squad

  @doc """
  Runs `fun` (which builds an email) in the recipient's language.

  Takes a user (their saved `locale`), a locale string, or nil. Users who
  never picked a language get the site default.
  """
  def in_locale(%{locale: locale}, fun), do: in_locale(locale, fun)

  def in_locale(locale, fun) do
    locale =
      if PevSquadWeb.Locale.supported?(locale), do: locale, else: PevSquadWeb.Locale.default()

    Gettext.with_locale(PevSquadWeb.Gettext, locale, fun)
  end

  @doc "Wraps a plain-text email body in the squad's ruled frame."
  def framed(body) do
    """

    ==============================

    #{body}

    ==============================
    """
  end
end
