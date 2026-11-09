defmodule PevSquadWeb.ReportLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures

  alias PevSquad.{Riders, Safety}

  setup %{conn: conn} do
    target = user_scope_fixture()

    {:ok, profile} =
      PevSquad.RidersFixtures.approved_profile(target, %{
        "alias" => "Troll",
        "is_public" => "true"
      })

    %{conn: conn, profile: profile, target: target}
  end

  test "reporting needs a login", %{conn: conn, profile: profile} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} =
             live(conn, ~p"/report/profile/#{profile.id}")
  end

  test "report and block a rider", %{conn: conn, profile: profile, target: target} do
    viewer = user_fixture()
    conn = log_in_user(conn, viewer)

    {:ok, lv, html} = live(conn, ~p"/report/profile/#{profile.id}")
    assert html =~ "Troll&#39;s rider profile"

    {:ok, _lv, html} =
      lv
      |> form("#report-form", report: %{reason: "harassment", notes: "Keeps posting rude stuff"})
      |> render_submit(%{"block" => "true"})
      |> follow_redirect(conn)

    assert html =~ "reported and blocked"
    refute html =~ "Troll"
    assert Safety.blocked?(PevSquad.Accounts.Scope.for_user(viewer), target.user.id)
  end

  test "a reason is required", %{conn: conn, profile: profile} do
    {:ok, lv, _html} = live(log_in_user(conn, user_fixture()), ~p"/report/profile/#{profile.id}")
    assert lv |> form("#report-form") |> render_submit() =~ "pick a reason"
  end

  test "staff resolve reports", %{conn: conn, profile: profile} do
    {:ok, _} = Safety.report(user_scope_fixture(), :profile, profile.id, %{"reason" => "spam"})

    {:ok, lv, html} = live(log_in_user(conn, staff_scope_fixture().user), ~p"/admin/reports")
    assert html =~ "Profile: Troll"
    assert html =~ "Spam or advertising ×1"

    html = lv |> form("#remove-profile-#{profile.id}") |> render_submit()
    assert html =~ "All clear"
  end
end
