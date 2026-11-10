defmodule PevSquadWeb.API.Admin.AlbumController do
  use PevSquadWeb, :api_controller

  alias PevSquad.Gallery
  alias PevSquadWeb.API.Schemas

  tags(["Admin: albums"])
  security([%{"bearer" => []}])

  operation(:index,
    summary: "Gallery albums, drafts included, for linking (`album_id`, `album_ids`)",
    responses: [ok: {"Albums", "application/json", Schemas.AlbumList}]
  )

  def index(conn, _params) do
    albums = Gallery.list_albums_for_staff(conn.assigns.current_scope)

    json(conn, %{
      data:
        Enum.map(albums, fn a ->
          %{
            id: a.id,
            slug: a.slug,
            title: a.title,
            taken_on: a.taken_on,
            published: a.published,
            photo_count: a.photo_count,
            event_id: a.event_id,
            url: url(~p"/gallery/#{a.slug}")
          }
        end)
    })
  end
end
