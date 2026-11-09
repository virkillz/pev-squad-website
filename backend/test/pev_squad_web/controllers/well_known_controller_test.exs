defmodule PevSquadWeb.WellKnownControllerTest do
  use PevSquadWeb.ConnCase, async: true

  test "serves the apple-app-site-association file as JSON", %{conn: conn} do
    conn = get(conn, "/.well-known/apple-app-site-association")

    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "application/json"

    assert %{"applinks" => %{"details" => [detail]}} = json_response(conn, 200)
    assert detail["appIDs"] == ["2QW696JV44.org.pevsquad.app"]

    components = detail["components"]
    assert %{"/" => "/events/*"} in components

    # Forms are excluded before the wildcard that would otherwise match them.
    excluded = Enum.find_index(components, &(&1 == %{"/" => "/for-sale/new", "exclude" => true}))
    wildcard = Enum.find_index(components, &(&1 == %{"/" => "/for-sale/*"}))
    assert excluded < wildcard
  end
end
