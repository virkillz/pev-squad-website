defmodule PevSquadWeb.API.HomeController do
  use PevSquadWeb, :api_controller

  alias PevSquad.{Events, Gallery, Listings, Posts}
  alias PevSquadWeb.API.Public.Helpers
  alias PevSquadWeb.API.{PublicJSON, PublicSchemas}

  tags(["Public"])

  operation(:show,
    summary: "Everything the app's home screen shows, in one call",
    responses: [ok: {"Home", "application/json", PublicSchemas.one("Home")}]
  )

  def show(conn, _params) do
    hidden = Helpers.hidden_ids(conn)
    upcoming = Events.list_upcoming_events(exclude_users: hidden)
    locale = Helpers.locale()

    json(conn, %{
      data: %{
        next_event:
          Enum.find(upcoming, &(&1.category == :official)) |> then(&(&1 && PublicJSON.event(&1))),
        upcoming: upcoming |> Enum.take(5) |> Enum.map(&PublicJSON.event/1),
        posts:
          [limit: 3] |> Posts.list_published_posts() |> Enum.map(&PublicJSON.post(&1, locale)),
        albums:
          [preview: 1, exclude_users: hidden]
          |> Gallery.list_published_albums()
          |> Enum.take(6)
          |> Enum.map(&PublicJSON.album/1),
        listings:
          [exclude_users: hidden]
          |> Listings.list_live_listings()
          |> Enum.take(4)
          |> Enum.map(&PublicJSON.listing/1)
      }
    })
  end
end
