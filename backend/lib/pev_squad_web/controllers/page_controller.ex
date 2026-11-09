defmodule PevSquadWeb.PageController do
  use PevSquadWeb, :controller

  def riders(conn, _params), do: redirect(conn, to: ~p"/community")

  # The language switcher. `PevSquadWeb.Locale` (in the pipeline) has
  # already stored the locale from the path; send the rider back to the
  # page they were on. Only the path of the referer is kept, so this can't
  # redirect off-site.
  # A logged-in rider's choice is also saved to their account, for emails.
  def locale(conn, _params) do
    with %{user: %PevSquad.Accounts.User{} = user} <- conn.assigns.current_scope do
      PevSquad.Accounts.update_user_locale(user, conn.assigns.locale)
    end

    redirect(conn, to: back_path(conn))
  end

  defp back_path(conn) do
    with [referer | _] <- get_req_header(conn, "referer"),
         %URI{path: "/" <> _ = path} = uri <- URI.parse(referer),
         false <- String.starts_with?(path, "//") do
      if uri.query, do: path <> "?" <> uri.query, else: path
    else
      _ -> ~p"/"
    end
  end
end
