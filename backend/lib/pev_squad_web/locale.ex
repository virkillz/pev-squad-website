defmodule PevSquadWeb.Locale do
  @moduledoc """
  Picks the UI language (Indonesian or English) for each request.

  Order: `?locale=` param, the `"locale"` session key (set by the language
  switcher), the browser's `Accept-Language` header, then the configured
  default (`config :pev_squad, PevSquadWeb.Gettext, default_locale: ...`).

  Used as a plug in the `:browser` pipeline and as an `on_mount` hook for
  LiveViews, which run in their own process and must set the locale again.
  """
  import Plug.Conn

  @supported ~w(id en)

  def supported, do: @supported

  def default, do: Application.get_env(:pev_squad, PevSquadWeb.Gettext)[:default_locale] || "id"

  def current, do: Gettext.get_locale(PevSquadWeb.Gettext)

  def supported?(locale), do: locale in @supported

  ## Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    param = conn.params["locale"]

    locale =
      cond do
        supported?(param) -> param
        supported?(get_session(conn, "locale")) -> get_session(conn, "locale")
        locale = from_accept_language(conn) -> locale
        true -> default()
      end

    Gettext.put_locale(PevSquadWeb.Gettext, locale)

    # Stored even when it came from the header, so LiveViews (which only see
    # the session) agree with the page the plug rendered.
    conn = assign(conn, :locale, locale)

    if get_session(conn, "locale") == locale,
      do: conn,
      else: put_session(conn, "locale", locale)
  end

  defp from_accept_language(conn) do
    conn
    |> get_req_header("accept-language")
    |> List.first("")
    |> String.split(",", trim: true)
    |> Enum.map(fn entry ->
      [tag | params] = String.split(entry, ";")
      lang = tag |> String.trim() |> String.downcase() |> String.split("-") |> hd()

      q =
        Enum.find_value(params, 1.0, fn p ->
          case String.split(String.trim(p), "=") do
            ["q", v] -> parse_q(v)
            _ -> nil
          end
        end)

      {lang, q}
    end)
    |> Enum.sort_by(fn {_, q} -> q end, :desc)
    |> Enum.find_value(fn
      {"in", _} -> "id"
      {lang, _} -> if supported?(lang), do: lang
    end)
  end

  defp parse_q(v) do
    case Float.parse(v) do
      {q, _} -> q
      :error -> 0.0
    end
  end

  ## LiveView

  def on_mount(:default, _params, session, socket) do
    locale = if supported?(session["locale"]), do: session["locale"], else: default()
    Gettext.put_locale(PevSquadWeb.Gettext, locale)
    {:cont, Phoenix.Component.assign(socket, :locale, locale)}
  end

  ## Dates

  @id_months ~w(Januari Februari Maret April Mei Juni Juli Agustus September Oktober November Desember)
  @id_months_abbr ~w(Jan Feb Mar Apr Mei Jun Jul Agu Sep Okt Nov Des)
  @id_days ~w(Senin Selasa Rabu Kamis Jumat Sabtu Minggu)
  @id_days_abbr ~w(Sen Sel Rab Kam Jum Sab Min)

  @doc """
  `Calendar.strftime/3` with month and day names in the current locale.
  """
  def strftime(datetime, format) do
    Calendar.strftime(datetime, format, name_opts(current()))
  end

  defp name_opts("id") do
    [
      month_names: &Enum.at(@id_months, &1 - 1),
      abbreviated_month_names: &Enum.at(@id_months_abbr, &1 - 1),
      day_of_week_names: &Enum.at(@id_days, &1 - 1),
      abbreviated_day_of_week_names: &Enum.at(@id_days_abbr, &1 - 1)
    ]
  end

  defp name_opts(_), do: []
end
