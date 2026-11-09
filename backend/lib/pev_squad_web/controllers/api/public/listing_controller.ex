defmodule PevSquadWeb.API.ListingController do
  use PevSquadWeb, :api_controller

  alias PevSquad.Listings
  alias PevSquad.Listings.Listing
  alias PevSquadWeb.API.{Page, PublicJSON, PublicSchemas}
  alias PevSquadWeb.API.Public.Helpers

  tags(["Public"])

  operation(:index,
    summary: "The For Sale board: live listings, or recently sold ones",
    parameters: [
      category: [in: :query, type: :string],
      sold: [in: :query, type: :boolean, description: "true = sold in the last 7 days"],
      limit: [in: :query, type: :integer],
      after: [in: :query, type: :string]
    ],
    responses: [ok: {"Listings", "application/json", PublicSchemas.page("Listing")}]
  )

  def index(conn, params) do
    with {:ok, page} <- Page.from_params(params),
         {:ok, category} <- Helpers.enum_param(params, "category", Listing.categories()) do
      opts = [category: category, exclude_users: Helpers.hidden_ids(conn)]

      listings =
        if params["sold"] in ["true", "1"],
          do: Listings.list_recently_sold(opts),
          else: Listings.list_live_listings(opts)

      {items, next} = Page.slice(listings, page)
      json(conn, %{data: Enum.map(items, &PublicJSON.listing/1), next: next})
    end
  end

  operation(:show,
    summary: "One listing. Seller contacts only when signed in.",
    parameters: [id: [in: :path, type: :integer, required: true]],
    responses: [ok: {"Listing", "application/json", PublicSchemas.one("ListingDetail")}]
  )

  def show(conn, %{"id" => id}) do
    scope = Helpers.scope(conn)

    with {id, ""} <- Integer.parse(id),
         {:ok, listing} <- Helpers.fetch(fn -> Listings.get_public_listing!(scope, id) end) do
      json(conn, %{data: PublicJSON.listing_detail(listing, not is_nil(scope))})
    else
      :error -> {:error, :not_found}
      {_, _rest} -> {:error, :not_found}
      error -> error
    end
  end
end
