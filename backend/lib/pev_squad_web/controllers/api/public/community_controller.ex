defmodule PevSquadWeb.API.CommunityController do
  use PevSquadWeb, :api_controller

  alias PevSquad.{Events, Partners, Riders}
  alias PevSquad.Riders.RiderProfile
  alias PevSquadWeb.API.{Page, PublicJSON, PublicSchemas}
  alias PevSquadWeb.API.Public.Helpers

  tags(["Public"])

  operation(:show,
    summary: "Community stats, partner communities and brand partners",
    responses: [ok: {"Community", "application/json", PublicSchemas.one("Community")}]
  )

  def show(conn, _params) do
    stats = Riders.stats()

    json(conn, %{
      data: %{
        stats: %{
          riders: stats.riders,
          cities: stats.cities,
          meetups_held: length(Events.list_past_events(category: :official)),
          rides_upcoming: length(Events.list_upcoming_events())
        },
        communities: :community |> Partners.list_partners() |> Enum.map(&PublicJSON.partner/1),
        brands: :brand |> Partners.list_partners() |> Enum.map(&PublicJSON.partner/1)
      }
    })
  end

  operation(:riders,
    summary: "The rider roster",
    parameters: [
      type: [in: :query, type: :string, description: "euc | escooter | esk8 | ebike | other"],
      search: [in: :query, type: :string, description: "Alias, city or ride"],
      sort: [in: :query, type: :string, description: "az (default) | za | newest | oldest"],
      limit: [in: :query, type: :integer],
      after: [in: :query, type: :string]
    ],
    responses: [ok: {"Riders", "application/json", PublicSchemas.page("Rider")}]
  )

  def riders(conn, params) do
    with {:ok, page} <- Page.from_params(params),
         {:ok, type} <- Helpers.enum_param(params, "type", RiderProfile.pev_types()),
         {:ok, sort} <- Helpers.enum_param(params, "sort", [:az, :za, :newest, :oldest]) do
      riders =
        Riders.list_public_riders(
          type: type,
          search: blank_to_nil(params["search"]),
          sort: sort || :az,
          exclude_users: Helpers.hidden_ids(conn)
        )

      {items, next} = Page.slice(riders, page)
      json(conn, %{data: Enum.map(items, &PublicJSON.rider/1), next: next})
    end
  end

  operation(:rider,
    summary: "One rider's public profile",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Rider", "application/json", PublicSchemas.one("RiderDetail")}]
  )

  def rider(conn, %{"slug" => slug}) do
    with {:ok, rider} <- Helpers.fetch(fn -> Riders.get_public_rider!(slug) end) do
      json(conn, %{data: PublicJSON.rider_detail(rider)})
    end
  end

  operation(:partner,
    summary: "A partner community or brand, with the events done together",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Partner", "application/json", PublicSchemas.one("PartnerDetail")}]
  )

  def partner(conn, %{"slug" => slug}) do
    with {:ok, partner} <- Helpers.fetch(fn -> Partners.get_public_partner!(slug) end) do
      json(conn, %{
        data: PublicJSON.partner_detail(partner, Partners.list_partner_events(partner))
      })
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(s) do
    case String.trim(s) do
      "" -> nil
      t -> t
    end
  end
end
