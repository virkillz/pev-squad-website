defmodule PevSquadWeb.WellKnownController do
  use PevSquadWeb, :controller

  # Pages the iOS app can show. iOS opens these pev-squad.org links in the
  # app when it's installed; the app's src/app/+native-intent.tsx maps the
  # website paths to its own screens. Forms stay on the website, so they are
  # excluded first (the first matching component wins).
  @app_paths ~w(/events /events/* /news /news/* /articles/* /community /community/*
                /partners/* /gallery /gallery/* /for-sale /for-sale/*)
  @web_only_paths ~w(/for-sale/new /for-sale/mine /for-sale/*/edit /gallery/*/upload)

  def apple_app_site_association(conn, _params) do
    components =
      Enum.map(@web_only_paths, &%{"/" => &1, "exclude" => true}) ++
        Enum.map(@app_paths, &%{"/" => &1})

    json(conn, %{
      applinks: %{
        details: [
          %{appIDs: Application.fetch_env!(:pev_squad, :ios_app_ids), components: components}
        ]
      }
    })
  end
end
