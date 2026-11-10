defmodule PevSquadWeb.API.PublicControllerTest do
  use PevSquadWeb.ConnCase, async: true

  import PevSquadWeb.APIHelpers
  import PevSquad.EventsFixtures
  import PevSquad.GalleryFixtures
  import PevSquad.ListingsFixtures
  import PevSquad.PartnersFixtures
  import PevSquad.PostsFixtures
  import PevSquad.RidersFixtures, only: [rider_fixture: 1]

  alias PevSquad.{Listings, Partners, Safety}

  setup %{conn: conn} do
    %{conn: put_req_header(conn, "accept", "application/json")}
  end

  defp data(conn, path), do: conn |> get(path) |> json_response(200) |> Map.fetch!("data")

  describe "events" do
    test "upcoming by default, past on request, drafts never", %{conn: conn} do
      soon =
        event_fixture(%{
          title: "Soon Ride",
          starts_at: DateTime.add(DateTime.utc_now(:second), 2, :day)
        })

      later =
        event_fixture(%{
          title: "Later Ride",
          starts_at: DateTime.add(DateTime.utc_now(:second), 9, :day)
        })

      past =
        event_fixture(%{
          title: "Old Ride",
          starts_at: DateTime.add(DateTime.utc_now(:second), -9, :day)
        })

      _draft = event_fixture(%{title: "Secret Draft", status: :draft})

      assert Enum.map(data(conn, ~p"/api/v1/events"), & &1["id"]) == [soon.id, later.id]
      assert Enum.map(data(conn, ~p"/api/v1/events?when=past"), & &1["id"]) == [past.id]
      assert json_response(get(conn, ~p"/api/v1/events?when=someday"), 422)
    end

    test "pages with an opaque cursor", %{conn: conn} do
      for d <- 1..3,
          do: event_fixture(%{starts_at: DateTime.add(DateTime.utc_now(:second), d, :day)})

      first = conn |> get(~p"/api/v1/events?limit=2") |> json_response(200)
      assert length(first["data"]) == 2
      assert is_binary(first["next"])

      second =
        conn |> get(~p"/api/v1/events?limit=2&after=#{first["next"]}") |> json_response(200)

      assert length(second["data"]) == 1
      assert second["next"] == nil

      assert json_response(get(conn, ~p"/api/v1/events?after=bogus"), 422)["error"]["fields"][
               "after"
             ]

      assert json_response(get(conn, ~p"/api/v1/events?limit=500"), 422)["error"]["fields"][
               "limit"
             ]
    end

    test "detail has local times, partners and seats; drafts are 404", %{conn: conn} do
      partner = partner_fixture(%{name: "REJS"})

      event =
        event_fixture(%{
          starts_at: ~U[2030-11-28 23:00:00Z],
          capacity: 4,
          meeting_point: "Rest area KM 57"
        })

      {:ok, _} = Partners.set_event_partners(staff_scope_fixture(), event, [partner.id])

      d = data(conn, ~p"/api/v1/events/#{event.slug}")
      assert d["local"]["starts_at"] == "2030-11-29T06:00:00+07:00"
      assert d["seats_left"] == 4
      assert d["meeting_point"] == "Rest area KM 57"
      assert [%{"name" => "REJS"}] = d["partners"]

      draft = event_fixture(%{status: :draft})

      assert %{"error" => %{"code" => "not_found"}} =
               json_response(get(conn, ~p"/api/v1/events/#{draft.slug}"), 404)
    end
  end

  describe "posts" do
    test "come in the request language, falling back to Indonesian", %{conn: conn} do
      both =
        post_fixture(%{
          translations: [
            %{
              locale: "id",
              title: "Kabar ID",
              body: "Isi ![](/uploads/posts/a.webp) [web](/news)"
            },
            %{locale: "en", title: "News EN", body: "Body", machine_translated: true}
          ]
        })

      only_id = post_fixture(%{translations: [%{locale: "id", title: "Hanya ID", body: "Isi"}]})

      en = data(conn, ~p"/api/v1/posts?locale=en")
      assert Enum.find(en, &(&1["id"] == both.id))["title"] == "News EN"
      assert Enum.find(en, &(&1["id"] == both.id))["machine_translated"]
      assert %{"title" => "Hanya ID", "locale" => "id"} = Enum.find(en, &(&1["id"] == only_id.id))

      d = data(conn, ~p"/api/v1/posts/#{both.slug}?locale=id")
      assert d["title"] == "Kabar ID"
      assert d["body"] =~ ~r{!\[\]\(http[^)]+/uploads/posts/a\.webp\)}
      assert d["body"] =~ ~r{\[web\]\(http[^)]+/news\)}
      assert Enum.sort(d["available_locales"]) == ["en", "id"]
    end

    test "drafts and future posts stay hidden", %{conn: conn} do
      draft = post_fixture(%{status: :draft})
      future = post_fixture(%{published_at: DateTime.add(DateTime.utc_now(:second), 3600)})

      ids = conn |> data(~p"/api/v1/posts") |> Enum.map(& &1["id"])
      refute draft.id in ids
      refute future.id in ids
      assert json_response(get(conn, ~p"/api/v1/posts/#{draft.slug}"), 404)
    end

    test "filters by kind and pages in the database", %{conn: conn} do
      news = post_fixture(%{kind: :news})
      article = post_fixture(%{kind: :article})

      assert Enum.map(data(conn, ~p"/api/v1/posts?kind=article"), & &1["id"]) == [article.id]

      page = conn |> get(~p"/api/v1/posts?limit=1") |> json_response(200)
      assert length(page["data"]) == 1
      rest = conn |> get(~p"/api/v1/posts?limit=1&after=#{page["next"]}") |> json_response(200)

      assert Enum.map(page["data"] ++ rest["data"], & &1["id"]) |> Enum.sort() ==
               Enum.sort([news.id, article.id])
    end
  end

  describe "listings" do
    test "board shows live listings; contacts need a token", %{conn: conn} do
      seller = host_scope_fixture("Wheelie")
      listing = live_listing_fixture(seller, %{"instagram" => "seller.one"})
      _pending = listing_fixture(seller, %{"title" => "Pending Thing"})

      assert [
               %{
                 "id" => id,
                 "seller" => %{"alias" => "Wheelie"},
                 "photo" => %{"url" => "http" <> _}
               }
             ] =
               data(conn, ~p"/api/v1/listings")

      assert id == listing.id

      anon = data(conn, ~p"/api/v1/listings/#{listing.id}")
      assert anon["contact"] == nil
      assert anon["contact_requires_login"]

      signed =
        data(api_conn(build_conn(), staff_scope_fixture()), ~p"/api/v1/listings/#{listing.id}")

      assert signed["contact"]["instagram"] == "seller.one"
      assert signed["contact"]["whatsapp_url"] =~ "https://wa.me/62"
    end

    test "sold listings are a separate list and never show contacts", %{conn: conn} do
      seller = host_scope_fixture()
      {:ok, sold} = Listings.mark_sold(seller, live_listing_fixture(seller))

      assert data(conn, ~p"/api/v1/listings") == []
      assert [%{"state" => "sold"}] = data(conn, ~p"/api/v1/listings?sold=true")

      signed =
        data(api_conn(build_conn(), staff_scope_fixture()), ~p"/api/v1/listings/#{sold.id}")

      assert signed["contact"] == nil
      refute signed["contact_requires_login"]
    end

    test "a blocked seller's listings are left out for the blocker", %{conn: conn} do
      seller = host_scope_fixture()
      live_listing_fixture(seller)
      me = staff_scope_fixture()
      {:ok, _} = Safety.block(me, seller.user.id)

      assert length(data(conn, ~p"/api/v1/listings")) == 1
      assert data(api_conn(build_conn(), me), ~p"/api/v1/listings") == []
    end

    test "unknown ids are 404", %{conn: conn} do
      assert json_response(get(conn, ~p"/api/v1/listings/999999"), 404)
      assert json_response(get(conn, "/api/v1/listings/abc"), 404)
    end
  end

  describe "community" do
    test "stats, partners and the roster", %{conn: conn} do
      partner_fixture(%{name: "Jogwheel", kind: :community})
      partner_fixture(%{name: "Hyundai", kind: :brand})
      rider_fixture(%{alias: "AldoChill", city: "Jakarta", primary_pev_type: :euc})
      rider_fixture(%{alias: "Skoot", city: "Malang", primary_pev_type: :escooter})
      rider_fixture(%{alias: "Hidden", is_public: false})

      d = data(conn, ~p"/api/v1/community")
      assert d["stats"]["riders"] == 2
      assert d["stats"]["cities"] == 2
      assert [%{"name" => "Jogwheel"}] = d["communities"]
      assert [%{"name" => "Hyundai"}] = d["brands"]

      assert Enum.map(data(conn, ~p"/api/v1/riders"), & &1["alias"]) == ["AldoChill", "Skoot"]
      assert Enum.map(data(conn, ~p"/api/v1/riders?type=escooter"), & &1["alias"]) == ["Skoot"]
      assert Enum.map(data(conn, ~p"/api/v1/riders?search=malang"), & &1["alias"]) == ["Skoot"]

      assert Enum.map(data(conn, ~p"/api/v1/riders?sort=za"), & &1["alias"]) == [
               "Skoot",
               "AldoChill"
             ]

      assert %{"alias" => "AldoChill", "url" => "http" <> _} =
               data(conn, ~p"/api/v1/riders/aldochill")

      assert json_response(get(conn, ~p"/api/v1/riders/hidden"), 404)
    end

    test "partner detail lists events together", %{conn: conn} do
      partner = partner_fixture(%{name: "SNOI"})
      event = event_fixture()
      {:ok, _} = Partners.set_event_partners(staff_scope_fixture(), event, [partner.id])

      d = data(conn, ~p"/api/v1/partners/#{partner.slug}")
      assert d["event_count"] == 1
      assert [%{"id" => id}] = d["events"]
      assert id == event.id
    end
  end

  test "albums list and detail", %{conn: conn} do
    album = album_fixture(%{"title" => "Bromo 2026"})
    photo_fixture(album)
    _empty = album_fixture(%{"title" => "Empty"})

    assert [
             %{
               "title" => "Bromo 2026",
               "photo_count" => 1,
               "preview" => [%{"thumb_url" => "http" <> _}]
             }
           ] =
             data(conn, ~p"/api/v1/albums")

    d = data(conn, ~p"/api/v1/albums/#{album.slug}")
    assert [%{"url" => "http" <> _, "tile" => "normal"}] = d["photos"]
  end

  test "events and posts carry their image and photo album", %{conn: conn} do
    event = event_fixture()

    {:ok, _} =
      PevSquad.Events.set_cover(
        staff_scope_fixture(),
        event,
        PevSquad.RidersFixtures.image_fixture(600, 750)
      )

    album = album_fixture(%{"title" => "Fun Ride", "event_id" => event.id})
    photo_fixture(album)
    recap = post_fixture(%{event_id: event.id})

    d = data(conn, ~p"/api/v1/events/#{event.slug}")
    assert d["cover_url"] =~ ~r{^http.*/uploads/events/.+\.webp$}
    assert [%{"title" => "Fun Ride", "photo_count" => 1}] = d["albums"]

    d = data(conn, ~p"/api/v1/posts/#{recap.slug}")
    assert d["album_id"] == nil
    assert %{"title" => "Fun Ride", "url" => "http" <> _} = d["album"]

    assert data(conn, ~p"/api/v1/posts/#{post_fixture().slug}")["album"] == nil
  end

  test "home bundles the first screen", %{conn: conn} do
    event = event_fixture(%{starts_at: DateTime.add(DateTime.utc_now(:second), 1, :day)})
    post_fixture()
    album = album_fixture()
    photo_fixture(album)

    d = data(conn, ~p"/api/v1/home")
    assert d["next_event"]["id"] == event.id
    assert length(d["posts"]) == 1
    assert length(d["albums"]) == 1
    assert d["listings"] == []
    assert d["rider_of_the_day"] == nil

    rider =
      rider_fixture(%{alias: "Spotlit", bio: "Night owl."})
      |> Ecto.Changeset.change(avatar_path: "/uploads/avatars/spotlit.webp")
      |> PevSquad.Repo.update!()

    d = data(conn, ~p"/api/v1/home")
    date = Date.to_iso8601(PevSquad.Riders.today())

    assert %{
             "alias" => "Spotlit",
             "bio" => "Night owl.",
             "date" => ^date,
             "avatar_url" => "http" <> _,
             "url" => "http" <> _
           } = d["rider_of_the_day"]

    assert rider.slug == d["rider_of_the_day"]["slug"]
  end

  test "the spec names the public schemas", %{conn: conn} do
    spec = conn |> get(~p"/api/v1/openapi") |> json_response(200)

    for name <-
          ~w(Event EventDetail Post PostDetail Listing ListingDetail Rider Partner Album Home Community) do
      assert Map.has_key?(spec["components"]["schemas"], name), name
    end

    assert spec["paths"]["/api/v1/events/{slug}"]["get"]
  end
end
