defmodule PevSquadWeb.MemberLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.RidersFixtures

  alias PevSquad.Accounts

  test "moderators see members and their profiles but can't change roles", %{conn: conn} do
    moderator = staff_scope_fixture(:moderator)
    member = user_fixture(email: "wynn@example.com")
    {:ok, _} = approved_profile(Accounts.Scope.for_user(member), %{alias: "Wynn"})
    user_fixture(email: "lurker@example.com")

    {:ok, lv, html} = live(log_in_user(conn, moderator.user), ~p"/admin/members")

    assert html =~ "Only admins can change roles."
    assert lv |> element("#member-#{member.id}", "Wynn") |> has_element?()
    refute has_element?(lv, "#role-#{member.id}")

    lv |> form("#member-search", q: "lurker") |> render_change()
    assert_patch(lv, "/admin/members?q=lurker")
    refute has_element?(lv, "#member-#{member.id}")

    {:ok, lv, _html} = live(log_in_user(conn, moderator.user), ~p"/admin/members?profile=without")
    refute has_element?(lv, "#member-#{member.id}")
  end

  test "admins change other members' roles, not their own", %{conn: conn} do
    admin = staff_scope_fixture(:admin)
    member = user_fixture()

    {:ok, lv, _html} = live(log_in_user(conn, admin.user), ~p"/admin/members")
    refute has_element?(lv, "#role-#{admin.user.id}")

    html = lv |> form("#role-#{member.id}", role: "moderator") |> render_submit()
    assert html =~ "#{member.email} is now Moderator."
    assert Accounts.get_user!(member.id).role == :moderator
  end

  test "staff link a member to an unclaimed rider", %{conn: conn} do
    staff = staff_scope_fixture()
    member = user_fixture()
    rider = rider_fixture(alias: "Imported")

    {:ok, lv, _html} = live(log_in_user(conn, staff.user), ~p"/admin/members")

    html = lv |> form("#link-#{member.id}", rider_id: rider.id) |> render_submit()
    assert html =~ "#{member.email} is now linked to Imported."
    assert lv |> element("#member-#{member.id}", "Imported") |> has_element?()
    assert PevSquad.Repo.reload(rider).user_id == member.id
  end

  test "members can't open it", %{conn: conn} do
    conn = log_in_user(conn, user_fixture())
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/members")
  end
end
