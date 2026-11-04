defmodule PevSquadWeb.PageController do
  use PevSquadWeb, :controller

  @sections %{
    "community" => {:community, "02", "Community"},
    "riders" => {:riders, "03", "Featured Riders"},
    "gallery" => {:gallery, "04", "Gallery"},
    "reviews" => {:reviews, "05", "Reviews"},
    "for-sale" => {:for_sale, "06", "For Sale"}
  }

  def coming_soon(conn, _params) do
    {active, num, title} = Map.fetch!(@sections, hd(conn.path_info))

    render(conn, :coming_soon, active: active, num: num, title: title, page_title: title)
  end
end
