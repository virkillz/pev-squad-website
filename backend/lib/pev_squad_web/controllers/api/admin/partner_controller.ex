defmodule PevSquadWeb.API.Admin.PartnerController do
  use PevSquadWeb, :api_controller

  alias PevSquad.Partners
  alias PevSquadWeb.API.Schemas

  tags(["Admin: partners"])
  security([%{"bearer" => []}])

  operation(:index,
    summary: "Partner communities and brands, for linking events (`partner_ids`)",
    responses: [ok: {"Partners", "application/json", Schemas.PartnerList}]
  )

  def index(conn, _params) do
    partners = Partners.list_all_partners(conn.assigns.current_scope)

    json(conn, %{
      data:
        Enum.map(partners, fn p ->
          %{id: p.id, slug: p.slug, name: p.name, kind: p.kind, published: p.published}
        end)
    })
  end
end
