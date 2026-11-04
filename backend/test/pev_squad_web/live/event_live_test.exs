defmodule PevSquadWeb.EventLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures

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
  end
end
