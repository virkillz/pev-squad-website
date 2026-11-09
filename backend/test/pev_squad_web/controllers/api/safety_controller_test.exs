defmodule PevSquadWeb.API.SafetyControllerTest do
  use PevSquadWeb.ConnCase, async: true
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.RidersFixtures
  alias PevSquad.Accounts.MobileAuth
  alias PevSquad.Riders.RiderProfile
  alias PevSquad.{Repo, Safety}

  setup %{conn: conn} do
    user = user_fixture() |> set_password()
    {:ok, session} = MobileAuth.password(user.email, valid_user_password())
    conn = put_req_header(conn, "accept", "application/json")
    member = put_req_header(conn, "authorization", "Bearer " <> session.access_token)

    other = host_scope_fixture()
    profile = Repo.get_by!(RiderProfile, user_id: other.user.id)
    %{conn: conn, member: member, user: user, other: other, profile: profile}
  end

  test "reasons come labelled", %{member: member} do
    reasons =
      member |> get(~p"/api/v1/reports/reasons") |> json_response(200) |> Map.fetch!("data")

    assert %{"value" => "spam", "label" => _} = hd(reasons)
  end

  test "report a profile and block its owner in one step", %{
    member: member,
    user: user,
    other: other,
    profile: profile
  } do
    body = %{
      target_type: "profile",
      target_id: profile.id,
      reason: "harassment",
      notes: "DMs",
      block: true
    }

    assert %{"data" => %{"blocked" => true}} =
             member |> post(~p"/api/v1/reports", body) |> json_response(201)

    assert Safety.blocked?(PevSquad.Accounts.Scope.for_user(user), other.user.id)

    # Rider detail reflects it, and a second report is refused.
    rider =
      member
      |> get(~p"/api/v1/riders/#{profile.slug}")
      |> json_response(200)
      |> Map.fetch!("data")

    assert rider["blocked"] and rider["has_account"] and rider["id"] == profile.id

    assert %{"error" => %{"fields" => %{"reason" => [_]}}} =
             member |> post(~p"/api/v1/reports", body) |> json_response(422)
  end

  test "report a group ride without blocking", %{member: member, other: other} do
    ride = group_ride_fixture(other)
    body = %{target_type: "event", target_id: ride.id, reason: "dangerous"}

    assert %{"data" => %{"blocked" => false}} =
             member |> post(~p"/api/v1/reports", body) |> json_response(201)
  end

  test "bad targets", %{member: member, conn: conn, profile: profile} do
    assert member
           |> post(~p"/api/v1/reports", %{target_type: "profile", target_id: 0, reason: "spam"})
           |> json_response(404)

    assert member
           |> post(~p"/api/v1/reports", %{target_type: "listing", target_id: 1, reason: "spam"})
           |> json_response(422)

    assert member
           |> post(~p"/api/v1/reports", %{target_type: "profile", target_id: profile.id})
           |> json_response(422)

    assert conn
           |> post(~p"/api/v1/reports", %{
             target_type: "profile",
             target_id: profile.id,
             reason: "spam"
           })
           |> json_response(401)
  end

  test "you can't report or block yourself", %{member: member, user: user} do
    {:ok, mine} =
      approved_profile(PevSquad.Accounts.Scope.for_user(user), %{
        alias: "Me #{System.unique_integer([:positive])}",
        primary_pev_type: :euc,
        is_public: true
      })

    assert member
           |> post(~p"/api/v1/reports", %{
             target_type: "profile",
             target_id: mine.id,
             reason: "spam"
           })
           |> json_response(422)

    assert member
           |> post(~p"/api/v1/blocks", %{target_type: "profile", target_id: mine.id})
           |> json_response(422)
  end

  test "an unclaimed profile can't be blocked", %{member: member} do
    imported = rider_fixture()

    assert member
           |> post(~p"/api/v1/blocks", %{target_type: "profile", target_id: imported.id})
           |> json_response(422)
  end

  test "block, list, unblock", %{member: member, other: other, profile: profile} do
    assert %{"data" => %{"user_id" => id, "alias" => alias}} =
             member
             |> post(~p"/api/v1/blocks", %{target_type: "profile", target_id: profile.id})
             |> json_response(201)

    assert id == other.user.id and alias == profile.alias

    assert [%{"user_id" => ^id}] =
             member |> get(~p"/api/v1/blocks") |> json_response(200) |> Map.fetch!("data")

    assert member |> delete(~p"/api/v1/blocks/#{id}") |> response(204)
    assert [] = member |> get(~p"/api/v1/blocks") |> json_response(200) |> Map.fetch!("data")
  end
end
