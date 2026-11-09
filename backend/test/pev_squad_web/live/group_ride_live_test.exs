defmodule PevSquadWeb.GroupRideLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures

  alias PevSquad.Events

  defp form_params(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: "Senayan Night Loop",
      kind: "night_ride",
      capacity: "12",
      starts_at: "2030-03-02T20:00",
      timezone: "Asia/Jakarta",
      location_name: "Senayan, Jakarta",
      meeting_point: "FX Sudirman"
    })
  end

  test "logged-out visitors are sent to log in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/group-rides/new")
  end

  test "members without a rider profile are asked to make one", %{conn: conn} do
    conn = log_in_user(conn, user_fixture())
    {:ok, lv, _html} = live(conn, ~p"/group-rides/new")

    assert has_element?(lv, "#needs-profile")
    refute has_element?(lv, "#group-ride-form")
  end

  test "members waiting for approval can't host yet", %{conn: conn} do
    user = user_fixture()

    {:ok, _} =
      PevSquad.Riders.save_my_profile(PevSquad.Accounts.Scope.for_user(user), %{alias: "Soon"})

    {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/group-rides/new")

    assert has_element?(lv, "#needs-approval")
    refute has_element?(lv, "#group-ride-form")
  end

  test "a member hosts a ride; it goes live with their name on it", %{conn: conn} do
    host = host_scope_fixture("Rangga")
    conn = log_in_user(conn, host.user)
    {:ok, lv, _html} = live(conn, ~p"/group-rides/new")

    {:ok, _show, html} =
      lv
      |> form("#group-ride-form", event: form_params())
      |> render_submit()
      |> follow_redirect(conn)

    assert html =~ "Your ride is live"
    assert html =~ "Senayan Night Loop"
    assert html =~ "hosted by Rangga"
    assert html =~ "not organized by PEV Squad"
    assert html =~ "Edit ride · see riders"

    [ride] = Events.list_upcoming_events(category: :group_ride)
    # 20:00 WIB is 13:00 UTC.
    assert ride.starts_at == ~U[2030-03-02 13:00:00Z]

    {:ok, _lv, index} = live(conn, ~p"/events?show=group")
    assert index =~ "Senayan Night Loop"
    assert index =~ "Group ride · hosted by Rangga"
  end

  test "shows validation errors", %{conn: conn} do
    conn = log_in_user(conn, host_scope_fixture().user)
    {:ok, lv, _html} = live(conn, ~p"/group-rides/new")

    html = lv |> form("#group-ride-form", event: form_params(capacity: "99")) |> render_submit()
    assert html =~ "must be between 1 and 30"
  end

  test "the host edits, sees riders by alias, and cancels", %{conn: conn} do
    host = host_scope_fixture()
    ride = group_ride_fixture(host)
    {:ok, _} = Events.rsvp(host_scope_fixture("Dinda"), ride)

    conn = log_in_user(conn, host.user)
    {:ok, lv, html} = live(conn, ~p"/group-rides/#{ride.id}/edit")
    assert html =~ "Dinda"

    {:ok, _show, html} =
      lv
      |> element("button", "Cancel the ride")
      |> render_click()
      |> follow_redirect(conn)

    assert html =~ "Ride cancelled"
    assert html =~ "This event has been cancelled"
  end

  test "other members can't edit someone's ride", %{conn: conn} do
    ride = group_ride_fixture(host_scope_fixture())
    conn = log_in_user(conn, user_fixture())

    assert_raise PevSquad.Events.NotAuthorizedError, fn ->
      live(conn, ~p"/group-rides/#{ride.id}/edit")
    end
  end

  test "other members see a report link; official events have none", %{conn: conn} do
    ride = group_ride_fixture(host_scope_fixture())
    event = event_fixture()
    conn = log_in_user(conn, user_fixture())

    {:ok, lv, _html} = live(conn, ~p"/events/#{ride.slug}")
    assert has_element?(lv, ~s|a[href="/report/event/#{ride.id}"]|)

    {:ok, lv, _html} = live(conn, ~p"/events/#{event.slug}")
    refute has_element?(lv, "a", "Report this ride")
    refute has_element?(lv, "#group-ride-note")
  end
end
