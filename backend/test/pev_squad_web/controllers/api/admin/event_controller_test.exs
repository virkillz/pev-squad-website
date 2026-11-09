defmodule PevSquadWeb.API.Admin.EventControllerTest do
  use PevSquadWeb.ConnCase, async: true

  import PevSquadWeb.APIHelpers
  import PevSquad.EventsFixtures
  import PevSquad.PartnersFixtures

  setup %{conn: conn} do
    scope = staff_scope_fixture()
    %{conn: api_conn(conn, scope), scope: scope}
  end

  @create %{
    "title" => "Night Ride Sudirman",
    "kind" => "night_ride",
    "starts_at" => "2026-12-05T20:00",
    "location_name" => "FX Sudirman",
    "capacity" => 40
  }

  test "create makes a draft official event; local times use the event zone", %{conn: conn} do
    data =
      conn |> post(~p"/api/v1/admin/events", @create) |> json_response(201) |> Map.fetch!("data")

    assert data["status"] == "draft"
    assert data["category"] == "official"
    assert data["slug"] =~ "night-ride-sudirman"
    assert data["timezone"] == "Asia/Jakarta"
    assert data["starts_at"] == "2026-12-05T13:00:00Z"
    assert data["local"]["starts_at"] == "2026-12-05T20:00:00+07:00"
    assert data["partner_ids"] == []
  end

  test "times with an offset are taken as given, in any zone", %{conn: conn} do
    data =
      conn
      |> post(
        ~p"/api/v1/admin/events",
        %{@create | "starts_at" => "2026-12-05T20:00:00+08:00"}
        |> Map.put("timezone", "Asia/Jakarta")
      )
      |> json_response(201)
      |> Map.fetch!("data")

    assert data["starts_at"] == "2026-12-05T12:00:00Z"

    data =
      conn
      |> post(
        ~p"/api/v1/admin/events",
        @create |> Map.merge(%{"timezone" => "Asia/Makassar", "title" => "Bali"})
      )
      |> json_response(201)
      |> Map.fetch!("data")

    assert data["starts_at"] == "2026-12-05T12:00:00Z"
  end

  test "links partners and validates partner_ids", %{conn: conn} do
    partner = partner_fixture()

    data =
      conn
      |> post(~p"/api/v1/admin/events", Map.put(@create, "partner_ids", [partner.id]))
      |> json_response(201)
      |> Map.fetch!("data")

    assert data["partner_ids"] == [partner.id]

    body =
      conn
      |> post(~p"/api/v1/admin/events", Map.put(@create, "partner_ids", ["x"]))
      |> json_response(422)

    assert body["error"]["fields"]["partner_ids"]
  end

  test "refuses to publish and reports changeset errors", %{conn: conn} do
    body =
      conn
      |> post(~p"/api/v1/admin/events", Map.put(@create, "status", "published"))
      |> json_response(422)

    assert body["error"]["fields"]["status"]

    body =
      conn
      |> post(~p"/api/v1/admin/events", Map.delete(@create, "starts_at"))
      |> json_response(422)

    assert body["error"]["fields"]["starts_at"] == ["can't be blank"]
  end

  test "update changes a draft, keeping its zone for local times", %{conn: conn} do
    %{"data" => %{"id" => id}} =
      conn
      |> post(~p"/api/v1/admin/events", Map.put(@create, "timezone", "Asia/Jayapura"))
      |> json_response(201)

    partner = partner_fixture()

    data =
      conn
      |> patch(~p"/api/v1/admin/events/#{id}", %{
        "starts_at" => "2026-12-06T19:00",
        "partner_ids" => [partner.id]
      })
      |> json_response(200)
      |> Map.fetch!("data")

    assert data["starts_at"] == "2026-12-06T10:00:00Z"
    assert data["title"] == "Night Ride Sudirman"
    assert data["partner_ids"] == [partner.id]
  end

  test "published events and group rides are off limits", %{conn: conn} do
    published = event_fixture()
    assert published.status == :published

    assert %{"error" => %{"code" => "conflict"}} =
             conn
             |> patch(~p"/api/v1/admin/events/#{published.slug}", %{"title" => "x"})
             |> json_response(409)
  end

  test "index filters and show finds by slug", %{conn: conn} do
    published = event_fixture()
    %{"data" => draft} = conn |> post(~p"/api/v1/admin/events", @create) |> json_response(201)

    ids = fn q ->
      conn
      |> get(~p"/api/v1/admin/events?#{q}")
      |> json_response(200)
      |> Map.fetch!("data")
      |> Enum.map(& &1["id"])
    end

    assert draft["id"] in ids.(%{})
    assert ids.(%{status: "draft"}) == [draft["id"]]
    assert published.id in ids.(%{status: "published"})

    assert conn
           |> get(~p"/api/v1/admin/events/#{draft["slug"]}")
           |> json_response(200)
           |> get_in(["data", "id"]) == draft["id"]

    assert json_response(get(conn, ~p"/api/v1/admin/events/nope-not-here"), 404)
  end

  test "partners lists ids for linking", %{conn: conn} do
    partner = partner_fixture()
    data = conn |> get(~p"/api/v1/admin/partners") |> json_response(200) |> Map.fetch!("data")

    assert %{"id" => _, "slug" => _, "kind" => "community"} =
             Enum.find(data, &(&1["id"] == partner.id))
  end

  test "the spec documents the admin endpoints", %{conn: conn} do
    paths = conn |> get(~p"/api/v1/openapi") |> json_response(200) |> Map.fetch!("paths")

    for path <-
          ~w(/api/v1/admin/posts /api/v1/admin/posts/{id} /api/v1/admin/posts/{id}/cover /api/v1/admin/events /api/v1/admin/events/{id} /api/v1/admin/partners /api/v1/admin/uploads) do
      assert Map.has_key?(paths, path), path
    end
  end
end
