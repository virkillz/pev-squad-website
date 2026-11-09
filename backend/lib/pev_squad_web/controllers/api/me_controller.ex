defmodule PevSquadWeb.API.MeController do
  use PevSquadWeb, :api_controller

  alias PevSquad.Riders
  alias PevSquadWeb.API.Schemas
  alias PevSquadWeb.API.Urls

  tags(["Me"])
  security([%{"bearer" => []}])

  operation(:show,
    summary: "The signed-in user",
    responses: [
      ok: {"The user", "application/json", Schemas.Me},
      unauthorized: {"Missing or invalid token", "application/json", Schemas.Error}
    ]
  )

  def show(conn, _params) do
    scope = conn.assigns.current_scope
    user = scope.user
    profile = Riders.get_my_profile(scope)

    json(conn, %{
      data: %{
        id: user.id,
        email: user.email,
        role: user.role,
        locale: user.locale,
        rider_profile:
          profile &&
            %{
              alias: profile.alias,
              slug: profile.slug,
              status: profile.status,
              avatar_url: Urls.absolute(profile.avatar_path)
            }
      }
    })
  end
end
