defmodule PevSquadWeb.EventLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.GalleryFixtures

  alias PevSquad.Events

  test "index lists upcoming events", %{conn: conn} do
    event = event_fixture(title: "Garut Getaway", capacity: 10)

    {:ok, _lv, html} = live(conn, ~p"/events")
    assert html =~ "Garut Getaway"
    assert html =~ "0 / 10 going"
    assert html =~ ~p"/events/#{event.slug}"
  end

  test "logged-out visitors are asked to log in", %{conn: conn} do
    event = event_fixture()
    {:ok, _lv, html} = live(conn, ~p"/events/#{event.slug}")
    assert html =~ "Log in to RSVP"
  end

  describe "RSVP" do
    setup :register_and_log_in_user

    test "takes a seat, then cancels", %{conn: conn} do
      event = event_fixture(capacity: 2)
      {:ok, lv, _html} = live(conn, ~p"/events/#{event.slug}")

      assert lv |> element("button", "RSVP — I'm going") |> render_click() =~ "You&#39;re going"
      assert lv |> element("#seat-count") |> render() =~ "1"

      assert lv |> element("button", "Cancel my RSVP") |> render_click() =~ "RSVP — I&#39;m going"
      assert lv |> element("#seat-count") |> render() =~ "0"
    end

    test "joins the waitlist when full and updates live when a seat frees up", %{conn: conn} do
      event = event_fixture(capacity: 1)
      holder = user_scope_fixture()
      {:ok, _} = Events.rsvp(holder, event)

      {:ok, lv, html} = live(conn, ~p"/events/#{event.slug}")
      assert html =~ "Full — join the waitlist"

      assert lv |> element("button", "Full — join the waitlist") |> render_click() =~
               "on the waitlist"

      # Another rider cancels elsewhere; this page hears about it over PubSub.
      {:ok, _promoted} = Events.cancel_rsvp(holder, event, fn _ -> "http://x" end)
      assert render(lv) =~ "You&#39;re going"
    end
  end

  describe "admin" do
    test "members are kept out", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/events")
    end

    test "staff can create an event in local time", %{conn: conn} do
      staff = staff_scope_fixture()
      conn = log_in_user(conn, staff.user)

      {:ok, lv, _html} = live(conn, ~p"/admin/events/new")

      {:ok, _show, html} =
        lv
        |> form("#event-form",
          event: %{
            title: "Bandung Loop",
            kind: "ride",
            status: "published",
            starts_at: "2030-03-01T20:00",
            timezone: "Asia/Jakarta",
            capacity: "12"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Bandung Loop"
      assert html =~ "20:00 WIB"

      event = Events.get_public_event!(nil, "bandung-loop-2030")
      assert event.starts_at == ~U[2030-03-01 13:00:00Z]
    end

    test "staff add an image and link a photo album", %{conn: conn} do
      conn = log_in_user(conn, staff_scope_fixture().user)
      event = event_fixture(title: "Fun Ride JIExpo")
      album = album_fixture(%{"title" => "Fun Ride Album"})
      photo_fixture(album)

      {:ok, lv, html} = live(conn, ~p"/admin/events/#{event.id}/edit")
      assert html =~ "Fun Ride Album"

      cover =
        file_input(lv, "#event-form", :cover, [
          %{
            name: "poster.png",
            content: File.read!(PevSquad.RidersFixtures.image_fixture(600, 750)),
            type: "image/jpeg"
          }
        ])

      render_upload(cover, "poster.png")

      {:ok, _show, html} =
        lv
        |> form("#event-form")
        |> render_submit(%{"album_ids" => ["", "#{album.id}"]})
        |> follow_redirect(conn)

      assert html =~ ~r{id="event-cover"[^>]*src="/uploads/events/fun-ride-jiexpo-}s or
               html =~ ~r{src="/uploads/events/fun-ride-jiexpo-[^"]+"[^>]*id="event-cover"}s

      assert html =~ "Fun Ride Album"
      assert html =~ ~p"/gallery/#{album.slug}"

      # Unticking unlinks it.
      {:ok, lv, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")
      lv |> form("#event-form") |> render_submit(%{"album_ids" => [""]})
      assert PevSquad.Gallery.list_event_album_ids(event) == []
    end
  end

  describe "admin rider list" do
    test "staff search, add, move and remove riders", %{conn: conn} do
      conn = log_in_user(conn, staff_scope_fixture().user)
      event = event_fixture(capacity: 1)
      rider = PevSquad.RidersFixtures.rider_fixture(alias: "Kemayoran Kid")

      {:ok, lv, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

      lv |> form("#rider-search", q: "kemayoran") |> render_change()
      assert has_element?(lv, "#result-#{rider.id}", "no account")

      lv
      |> element("#result-#{rider.id} button[phx-value-status=going]")
      |> render_click()

      [rsvp] = Events.list_rsvps(staff_scope_fixture(), event)
      assert has_element?(lv, "#rsvp-#{rsvp.id}", "Kemayoran Kid")
      assert has_element?(lv, "#rsvp-#{rsvp.id}", "going")
      refute has_element?(lv, "#rider-results")

      lv |> element("#rsvp-#{rsvp.id} button", "Move to waitlist") |> render_click()
      assert has_element?(lv, "#rsvp-#{rsvp.id}", "waitlist")

      lv |> element("#rsvp-#{rsvp.id} button", "Remove") |> render_click()
      refute has_element?(lv, "#rsvp-#{rsvp.id}")
      assert Events.list_rsvps(staff_scope_fixture(), event) == []
    end

    test "a search with no match says so", %{conn: conn} do
      conn = log_in_user(conn, staff_scope_fixture().user)
      event = event_fixture()

      {:ok, lv, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")
      lv |> form("#rider-search", q: "zzz-nobody") |> render_change()
      assert has_element?(lv, "#rider-no-results")
    end
  end

  describe "event page" do
    test "shows linked albums, and the album links back", %{conn: conn} do
      event = event_fixture(title: "Perklindo Ride")
      album = album_fixture(%{"title" => "Perklindo Photos", "event_id" => event.id})
      photo_fixture(album)

      {:ok, lv, _html} = live(conn, ~p"/events/#{event.slug}")
      assert has_element?(lv, "#album-#{album.id}", "Perklindo Photos")
      assert has_element?(lv, "#album-#{album.id}", "1 photo")
      refute has_element?(lv, "#event-cover")

      {:ok, lv, _html} = live(conn, ~p"/gallery/#{album.slug}")
      assert has_element?(lv, "#album-event a[href='/events/#{event.slug}']", "Perklindo Ride")
    end

    test "an album of a draft event doesn't link to it", %{conn: conn} do
      event = event_fixture(status: :draft)
      album = album_fixture(%{"event_id" => event.id})
      photo_fixture(album)

      {:ok, lv, _html} = live(conn, ~p"/gallery/#{album.slug}")
      refute has_element?(lv, "#album-event")
    end
  end
end
