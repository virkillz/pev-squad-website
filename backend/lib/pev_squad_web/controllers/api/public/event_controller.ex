defmodule PevSquadWeb.API.EventController do
  use PevSquadWeb, :api_controller

  alias PevSquad.{Events, Gallery, Partners, Posts}
  alias PevSquadWeb.API.{Page, PublicJSON, PublicSchemas}
  alias PevSquadWeb.API.Public.Helpers

  tags(["Public"])

  operation(:index,
    summary: "Published events",
    parameters: [
      when: [
        in: :query,
        type: :string,
        description: "upcoming (default, soonest first) | past (latest first)"
      ],
      category: [in: :query, type: :string, description: "official | group_ride"],
      limit: [in: :query, type: :integer],
      after: [in: :query, type: :string]
    ],
    responses: [ok: {"Events", "application/json", PublicSchemas.page("Event")}]
  )

  def index(conn, params) do
    with {:ok, page} <- Page.from_params(params),
         {:ok, category} <- Helpers.enum_param(params, "category", [:official, :group_ride]),
         {:ok, whence} <- Helpers.enum_param(params, "when", [:upcoming, :past]) do
      opts = [category: category, exclude_users: Helpers.hidden_ids(conn)]

      events =
        if whence == :past,
          do: Events.list_past_events(opts),
          else: Events.list_upcoming_events(opts)

      {items, next} = Page.slice(events, page)
      json(conn, %{data: Enum.map(items, &PublicJSON.event/1), next: next})
    end
  end

  operation(:show,
    summary: "One event, with partners, recap posts and photo albums",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Event", "application/json", PublicSchemas.one("EventDetail")}]
  )

  def show(conn, %{"slug" => slug}) do
    with {:ok, event} <-
           Helpers.fetch(fn -> Events.get_public_event!(Helpers.scope(conn), slug) end) do
      partners = Partners.list_event_partners(event)
      recaps = Posts.list_event_posts(event)
      albums = Gallery.list_event_albums(event, exclude_users: Helpers.hidden_ids(conn))
      json(conn, %{data: PublicJSON.event_detail(event, partners, recaps, albums)})
    end
  end
end
