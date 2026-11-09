defmodule PevSquadWeb.API.MeControllerTest do
  use PevSquadWeb.ConnCase, async: true

  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures, only: [staff_scope_fixture: 0]

  alias PevSquad.Accounts

  setup %{conn: conn} do
    scope = staff_scope_fixture()
    {:ok, token, _} = Accounts.create_api_token(scope, %{"name" => "test"})
    %{conn: put_req_header(conn, "accept", "application/json"), scope: scope, token: token}
  end

  defp authed(conn, token), do: put_req_header(conn, "authorization", "Bearer " <> token)

  test "GET /api/v1/me returns the token's user", %{conn: conn, scope: scope, token: token} do
    body = conn |> authed(token) |> get(~p"/api/v1/me") |> json_response(200)

    assert body["data"]["id"] == scope.user.id
    assert body["data"]["email"] == scope.user.email
    assert body["data"]["role"] == "moderator"
    assert body["data"]["rider_profile"] == nil
  end

  test "the bearer scheme is case-insensitive", %{conn: conn, token: token} do
    conn = conn |> put_req_header("authorization", "bearer " <> token) |> get(~p"/api/v1/me")
    assert json_response(conn, 200)
  end

  test "no token is a 401 in the shared error shape", %{conn: conn} do
    conn = get(conn, ~p"/api/v1/me")

    assert %{"error" => %{"code" => "unauthorized", "message" => _}} = json_response(conn, 401)
    assert get_resp_header(conn, "www-authenticate") != []
  end

  test "a bad token is a 401", %{conn: conn, token: token} do
    conn = conn |> authed(token <> "x") |> get(~p"/api/v1/me")
    assert %{"error" => %{"code" => "unauthorized"}} = json_response(conn, 401)
  end

  test "a browser session cookie doesn't authenticate the API", %{conn: conn} do
    conn = conn |> log_in_user(user_fixture()) |> get(~p"/api/v1/me")
    assert json_response(conn, 401)
  end

  test "language comes from ?locale= or Accept-Language", %{conn: conn} do
    conn1 = conn |> put_req_header("accept-language", "id-ID,id;q=0.9") |> get(~p"/api/v1/me")
    assert get_resp_header(conn1, "content-language") == ["id"]
    assert json_response(conn1, 401)["error"]["message"] == "Token API yang valid diperlukan."

    conn2 = get(conn, ~p"/api/v1/me?locale=en")
    assert get_resp_header(conn2, "content-language") == ["en"]
    assert json_response(conn2, 401)["error"]["message"] == "A valid API token is required."
  end

  test "unknown API routes answer 404 in the error shape", %{conn: conn} do
    conn = get(conn, "/api/v1/nope")
    assert %{"error" => %{"code" => "not_found"}} = json_response(conn, 404)
  end

  test "GET /api/v1/openapi describes the API", %{conn: conn} do
    spec = conn |> get(~p"/api/v1/openapi") |> json_response(200)

    assert spec["info"]["title"] == "PEV Squad API"
    assert spec["paths"]["/api/v1/me"]["get"]
    assert spec["components"]["securitySchemes"]["bearer"]
    refute Map.has_key?(spec["paths"], "/events")
  end
end
