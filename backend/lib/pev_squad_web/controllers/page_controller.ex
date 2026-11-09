defmodule PevSquadWeb.PageController do
  use PevSquadWeb, :controller

  @sections %{
    "for-sale" => {:for_sale, "05", "For Sale"}
  }

  def coming_soon(conn, _params) do
    {active, num, title} = Map.fetch!(@sections, hd(conn.path_info))

    render(conn, :coming_soon, active: active, num: num, title: title, page_title: title)
  end

  def riders(conn, _params), do: redirect(conn, to: ~p"/community")

  # The language switcher. `PevSquadWeb.Locale` (in the pipeline) has
  # already stored the locale from the path; send the rider back to the
  # page they were on. Only the path of the referer is kept, so this can't
  # redirect off-site.
  def locale(conn, _params), do: redirect(conn, to: back_path(conn))

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
