defmodule PevSquadWeb.API.Admin.EventControllerTest do
  use PevSquadWeb.ConnCase, async: true

  import PevSquadWeb.APIHelpers
  import PevSquad.EventsFixtures
  import PevSquad.PartnersFixtures
  import PevSquad.GalleryFixtures
  import PevSquad.RidersFixtures, only: [image_fixture: 2]

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

  describe "images and albums" do
    test "album_ids links albums, and an unknown id saves nothing", %{conn: conn} do
      album = album_fixture()

      data =
        conn
        |> post(~p"/api/v1/admin/events", Map.put(@create, "album_ids", [album.id]))
        |> json_response(201)
        |> Map.fetch!("data")

      assert data["album_ids"] == [album.id]
      assert data["cover_url"] == nil

      body =
        conn
        |> post(~p"/api/v1/admin/events", Map.put(@create, "album_ids", [album.id, -1]))
        |> json_response(422)

      assert body["error"]["fields"]["album_ids"] == ["no album with id -1"]

      data =
        conn
        |> patch(~p"/api/v1/admin/events/#{data["id"]}", %{"album_ids" => []})
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["album_ids"] == []
    end

    test "album_ids must be a list of ids", %{conn: conn} do
      body =
        conn
        |> post(~p"/api/v1/admin/events", Map.put(@create, "album_ids", "4"))
        |> json_response(422)

      assert body["error"]["fields"]["album_ids"]
    end

    test "cover sets the image of a draft, not of a published event", %{conn: conn} do
      %{"id" => id} =
        conn
        |> post(~p"/api/v1/admin/events", @create)
        |> json_response(201)
        |> Map.fetch!("data")

      file = %Plug.Upload{
        path: image_fixture(600, 750),
        filename: "p.png",
        content_type: "image/png"
      }

      data =
        conn
        |> post(~p"/api/v1/admin/events/#{id}/cover", %{"file" => file})
        |> json_response(200)
        |> Map.fetch!("data")

      assert data["cover_url"] =~ ~r{^http.*/uploads/events/night-ride-sudirman-.+\.webp$}

      published = event_fixture()

      assert json_response(
               post(conn, ~p"/api/v1/admin/events/#{published.id}/cover", %{"file" => file}),
               409
             )
    end

    test "albums lists every album for linking", %{conn: conn} do
      event = event_fixture()
      album = album_fixture(%{"published" => "false", "event_id" => event.id})

      data = conn |> get(~p"/api/v1/admin/albums") |> json_response(200) |> Map.fetch!("data")

      assert %{"slug" => _, "published" => false, "event_id" => event_id, "photo_count" => 0} =
               Enum.find(data, &(&1["id"] == album.id))

      assert event_id == event.id
    end
  end

  test "the spec documents the admin endpoints", %{conn: conn} do
    paths = conn |> get(~p"/api/v1/openapi") |> json_response(200) |> Map.fetch!("paths")

    for path <-
          ~w(/api/v1/admin/posts /api/v1/admin/posts/{id} /api/v1/admin/posts/{id}/cover /api/v1/admin/events /api/v1/admin/events/{id} /api/v1/admin/events/{id}/cover /api/v1/admin/partners /api/v1/admin/albums /api/v1/admin/uploads) do
      assert Map.has_key?(paths, path), path
    end
  end
end
