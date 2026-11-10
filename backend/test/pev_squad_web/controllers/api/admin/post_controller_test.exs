defmodule PevSquadWeb.API.Admin.PostControllerTest do
  use PevSquadWeb.ConnCase, async: true

  import PevSquadWeb.APIHelpers
  import PevSquad.EventsFixtures, only: [staff_scope_fixture: 0, event_fixture: 0]
  import PevSquad.PostsFixtures
  import PevSquad.RidersFixtures, only: [image_fixture: 0]

  alias PevSquad.Posts

  setup %{conn: conn} do
    scope = staff_scope_fixture()
    %{conn: api_conn(conn, scope), scope: scope}
  end

  @create %{
    "kind" => "article",
    "topic" => "safety",
    "translations" => %{
      "id" => %{
        "title" => "Cara Aman Night Ride",
        "body" => "Pakai **lampu**.",
        "machine_translated" => false
      },
      "en" => %{"title" => "Riding Safely at Night", "body" => "Use **lights**."}
    }
  }

  describe "create" do
    test "makes a draft, slug from the Indonesian title, en flagged as machine translated",
         %{conn: conn, scope: scope} do
      body = conn |> post(~p"/api/v1/admin/posts", @create) |> json_response(201)
      data = body["data"]

      assert data["status"] == "draft"
      assert data["kind"] == "article"
      assert data["slug"] == "cara-aman-night-ride"
      assert data["translations"]["id"]["machine_translated"] == false
      assert data["translations"]["en"]["machine_translated"] == true
      assert data["url"] =~ "/articles/cara-aman-night-ride"
      assert data["admin_url"] =~ "/admin/posts/#{data["id"]}/edit"

      {:ok, post} = Posts.fetch_post(scope, data["id"])
      assert post.author_id == scope.user.id
      refute Posts.live?(post)
    end

    test "refuses to publish", %{conn: conn} do
      body =
        conn
        |> post(
          ~p"/api/v1/admin/posts",
          Map.merge(@create, %{"status" => "published", "published_at" => "2026-01-01T00:00:00Z"})
        )
        |> json_response(422)

      assert body["error"]["code"] == "validation_failed"
      assert Map.keys(body["error"]["fields"]) |> Enum.sort() == ["published_at", "status"]
    end

    test "validation errors come back per field", %{conn: conn} do
      body =
        conn
        |> post(~p"/api/v1/admin/posts", %{"translations" => %{"id" => %{"title" => "Tanpa isi"}}})
        |> json_response(422)

      assert body["error"]["fields"]["translations"] == [%{"body" => ["can't be blank"]}]
    end

    test "rejects unknown languages and non-object translations", %{conn: conn} do
      for translations <- [%{"fr" => %{"title" => "x", "body" => "y"}}, [%{"title" => "x"}]] do
        body =
          conn
          |> post(~p"/api/v1/admin/posts", %{"translations" => translations})
          |> json_response(422)

        assert body["error"]["fields"]["translations"]
      end
    end

    test "can link an event as a recap", %{conn: conn} do
      event = event_fixture()

      body =
        conn
        |> post(~p"/api/v1/admin/posts", Map.put(@create, "event_id", event.id))
        |> json_response(201)

      assert body["data"]["event_id"] == event.id
    end
  end

  describe "update" do
    setup %{conn: conn} do
      %{"data" => data} = conn |> post(~p"/api/v1/admin/posts", @create) |> json_response(201)
      %{post_id: data["id"], slug: data["slug"]}
    end

    test "changes only what's sent and keeps other languages", %{conn: conn, post_id: id} do
      body =
        conn
        |> patch(~p"/api/v1/admin/posts/#{id}", %{
          "topic" => "guide",
          "translations" => %{"en" => %{"title" => "Night Riding Safety"}}
        })
        |> json_response(200)

      t = body["data"]["translations"]
      assert body["data"]["topic"] == "guide"
      assert t["en"]["title"] == "Night Riding Safety"
      assert t["en"]["body"] == "Use **lights**."
      assert t["id"]["title"] == "Cara Aman Night Ride"
      assert t["id"]["machine_translated"] == false
    end

    test "album_id links an album; an unknown one is a validation error", %{
      conn: conn,
      post_id: id
    } do
      album = PevSquad.GalleryFixtures.album_fixture()

      body =
        conn
        |> patch(~p"/api/v1/admin/posts/#{id}", %{"album_id" => album.id})
        |> json_response(200)

      assert body["data"]["album_id"] == album.id

      body =
        conn |> patch(~p"/api/v1/admin/posts/#{id}", %{"album_id" => -1}) |> json_response(422)

      assert body["error"]["fields"]["album_id"]

      body =
        conn |> patch(~p"/api/v1/admin/posts/#{id}", %{"album_id" => nil}) |> json_response(200)

      assert body["data"]["album_id"] == nil
    end

    test "null removes a language and the slug stays", %{conn: conn, post_id: id, slug: slug} do
      body =
        conn
        |> patch(~p"/api/v1/admin/posts/#{slug}", %{"translations" => %{"en" => nil}})
        |> json_response(200)

      assert Map.keys(body["data"]["translations"]) == ["id"]
      assert body["data"]["slug"] == slug
      assert body["data"]["id"] == id
    end

    test "published posts are off limits", %{conn: conn} do
      published = post_fixture()

      body =
        conn
        |> patch(~p"/api/v1/admin/posts/#{published.id}", %{"topic" => "story"})
        |> json_response(409)

      assert body["error"]["code"] == "conflict"
    end

    test "unknown ids are 404", %{conn: conn} do
      assert json_response(patch(conn, ~p"/api/v1/admin/posts/999999", %{}), 404)
    end
  end

  test "index lists posts and filters by status and kind", %{conn: conn} do
    published = post_fixture()
    %{"data" => draft} = conn |> post(~p"/api/v1/admin/posts", @create) |> json_response(201)

    ids = fn query ->
      conn
      |> get(~p"/api/v1/admin/posts?#{query}")
      |> json_response(200)
      |> Map.fetch!("data")
      |> Enum.map(& &1["id"])
    end

    assert draft["id"] in ids.(%{})
    assert published.id in ids.(%{})
    assert ids.(%{status: "draft"}) == [draft["id"]]
    assert ids.(%{kind: "news"}) == [published.id]
    assert json_response(get(conn, ~p"/api/v1/admin/posts?status=bogus"), 422)
  end

  test "show returns the full text by id or slug", %{conn: conn} do
    post = post_fixture()
    by_id = conn |> get(~p"/api/v1/admin/posts/#{post.id}") |> json_response(200)
    by_slug = conn |> get(~p"/api/v1/admin/posts/#{post.slug}") |> json_response(200)

    assert by_id == by_slug
    assert by_id["data"]["translations"]["id"]["body"] =~ "Isi kabar"
  end

  describe "cover and uploads" do
    test "sets a cover on a draft", %{conn: conn} do
      %{"data" => %{"id" => id}} =
        conn |> post(~p"/api/v1/admin/posts", @create) |> json_response(201)

      file = %Plug.Upload{path: image_fixture(), filename: "c.jpg", content_type: "image/jpeg"}

      body =
        conn |> post(~p"/api/v1/admin/posts/#{id}/cover", %{"file" => file}) |> json_response(200)

      assert body["data"]["cover_url"] =~ ~r{^http.*/uploads/posts/cara-aman-night-ride-.+\.webp$}
    end

    test "inline uploads return a Markdown snippet", %{conn: conn} do
      file = %Plug.Upload{path: image_fixture(), filename: "a.png", content_type: "image/png"}
      body = conn |> post(~p"/api/v1/admin/uploads", %{"file" => file}) |> json_response(201)

      assert "/uploads/posts/inline-" <> _ = body["data"]["path"]
      assert body["data"]["markdown"] == "![](#{body["data"]["path"]})"

      assert File.exists?(
               PevSquad.Uploads.path(String.trim_leading(body["data"]["path"], "/uploads/"))
             )
    end

    test "non-images are refused", %{conn: conn} do
      text = Path.join(System.tmp_dir!(), "pev-#{System.unique_integer([:positive])}.txt")
      File.write!(text, "hello")

      for file <- [
            %Plug.Upload{path: text, filename: "x.txt", content_type: "text/plain"},
            %Plug.Upload{path: text, filename: "x.jpg", content_type: "image/jpeg"}
          ] do
        body = conn |> post(~p"/api/v1/admin/uploads", %{"file" => file}) |> json_response(422)
        assert body["error"]["fields"]["file"]
      end

      assert json_response(post(conn, ~p"/api/v1/admin/uploads", %{}), 422)
    end
  end

  test "a demoted staff member's token stops working", %{conn: conn, scope: scope} do
    {:ok, _} = PevSquad.Accounts.set_user_role(scope.user, :member)
    assert json_response(get(conn, ~p"/api/v1/admin/posts"), 401)
  end
end
