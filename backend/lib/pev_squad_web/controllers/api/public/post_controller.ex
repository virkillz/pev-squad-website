defmodule PevSquadWeb.API.PostController do
  use PevSquadWeb, :api_controller

  alias PevSquad.Posts
  alias PevSquad.Posts.Post
  alias PevSquadWeb.API.{Page, PublicJSON, PublicSchemas}
  alias PevSquadWeb.API.Public.Helpers

  tags(["Public"])

  operation(:index,
    summary: "Published news and articles, newest first, in the request language",
    parameters: [
      kind: [in: :query, type: :string, description: "news | article"],
      topic: [in: :query, type: :string],
      limit: [in: :query, type: :integer],
      after: [in: :query, type: :string]
    ],
    responses: [ok: {"Posts", "application/json", PublicSchemas.page("Post")}]
  )

  def index(conn, params) do
    with {:ok, page} <- Page.from_params(params),
         {:ok, kind} <- Helpers.enum_param(params, "kind", Post.kinds()),
         {:ok, topic} <- Helpers.enum_param(params, "topic", Post.topics()) do
      rows =
        Posts.list_published_posts(
          kind: kind,
          topic: topic,
          limit: page.limit + 1,
          offset: page.offset
        )

      {items, next} = Page.trim(rows, page)
      json(conn, %{data: Enum.map(items, &PublicJSON.post(&1, Helpers.locale())), next: next})
    end
  end

  operation(:show,
    summary: "One post with its Markdown body",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Post", "application/json", PublicSchemas.one("PostDetail")}]
  )

  def show(conn, %{"slug" => slug}) do
    with {:ok, post} <- Helpers.fetch(fn -> Posts.get_public_post!(Helpers.scope(conn), slug) end) do
      json(conn, %{data: PublicJSON.post_detail(post, Helpers.locale())})
    end
  end
end
