defmodule PevSquadWeb.AdminDashboardTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures

  alias PevSquad.{Riders, Safety}

  test "shows open reports and moderation counts", %{conn: conn} do
    target = user_scope_fixture()

    {:ok, profile} =
      PevSquad.RidersFixtures.approved_profile(target, %{
        "alias" => "Flagged",
        "is_public" => "true"
      })

    {:ok, _} = Safety.report(user_scope_fixture(), :profile, profile.id, %{"reason" => "spam"})

    {:ok, _lv, html} = live(log_in_user(conn, staff_scope_fixture().user), ~p"/admin")
    assert html =~ "1 OPEN"
    assert html =~ "0 WAITING"
  end

  test "members are redirected away", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(log_in_user(conn, user_fixture()), ~p"/admin")
  end
end
