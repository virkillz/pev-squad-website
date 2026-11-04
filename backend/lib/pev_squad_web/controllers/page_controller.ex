defmodule PevSquadWeb.PageController do
  use PevSquadWeb, :controller

  @sections %{
    "for-sale" => {:for_sale, "06", "For Sale"}
  }

  def coming_soon(conn, _params) do
    {active, num, title} = Map.fetch!(@sections, hd(conn.path_info))

    render(conn, :coming_soon, active: active, num: num, title: title, page_title: title)
  end
end
