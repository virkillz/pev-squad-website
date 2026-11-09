defmodule PevSquadWeb.API.AlbumController do
  use PevSquadWeb, :api_controller

  alias PevSquad.Gallery
  alias PevSquadWeb.API.{Page, PublicJSON, PublicSchemas}
  alias PevSquadWeb.API.Public.Helpers

  tags(["Public"])

  operation(:index,
    summary: "Gallery albums with a few preview photos, newest first",
    parameters: [limit: [in: :query, type: :integer], after: [in: :query, type: :string]],
    responses: [ok: {"Albums", "application/json", PublicSchemas.page("Album")}]
  )

  def index(conn, params) do
    with {:ok, page} <- Page.from_params(params) do
      albums = Gallery.list_published_albums(preview: 4, exclude_users: Helpers.hidden_ids(conn))
      {items, next} = Page.slice(albums, page)
      json(conn, %{data: Enum.map(items, &PublicJSON.album/1), next: next})
    end
  end

  operation(:show,
    summary: "One album with all its photos",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Album", "application/json", PublicSchemas.one("AlbumDetail")}]
  )

  def show(conn, %{"slug" => slug}) do
    hidden = Helpers.hidden_ids(conn)

    with {:ok, album} <-
           Helpers.fetch(fn -> Gallery.get_published_album!(slug, exclude_users: hidden) end) do
      json(conn, %{data: PublicJSON.album_detail(album)})
    end
  end
end
