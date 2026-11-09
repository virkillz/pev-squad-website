defmodule PevSquadWeb.API.AccountDeletionTest do
  use PevSquadWeb.ConnCase, async: true
  import PevSquad.AccountsFixtures
  import Ecto.Query
  alias PevSquad.Repo
  alias PevSquad.Accounts.{MobileAuth, User, UserToken}
  alias PevSquad.Riders.RiderProfile

  setup %{conn: conn} do
    user = user_fixture() |> set_password()
    {:ok, session} = MobileAuth.password(user.email, valid_user_password())
    conn = put_req_header(conn, "accept", "application/json")

    %{
      member: put_req_header(conn, "authorization", "Bearer " <> session.access_token),
      user: user
    }
  end

  test "the preview counts what goes", %{member: member} do
    member
    |> put(~p"/api/v1/me/profile", %{
      alias: "Gone #{System.unique_integer([:positive])}",
      primary_pev_type: "euc"
    })

    data = member |> get(~p"/api/v1/me/deletion") |> json_response(200) |> Map.fetch!("data")
    assert data["profile_alias"] =~ "Gone"
    assert data["reviews"] == 0 and data["listings"] == 0
  end

  test "a fresh login deletes the account, profile and sessions", %{member: member, user: user} do
    member
    |> put(~p"/api/v1/me/profile", %{
      alias: "Bye #{System.unique_integer([:positive])}",
      primary_pev_type: "euc"
    })

    assert member |> delete(~p"/api/v1/me") |> response(204)
    refute Repo.get(User, user.id)
    refute Repo.exists?(from p in RiderProfile, where: p.user_id == ^user.id)
    refute Repo.exists?(from t in UserToken, where: t.user_id == ^user.id)
    assert member |> get(~p"/api/v1/me") |> json_response(401)
  end

  test "a claimed imported profile is deleted too", %{member: member, user: user} do
    profile =
      Repo.insert!(%RiderProfile{
        alias: "Imported #{System.unique_integer([:positive])}",
        slug: "imported-#{System.unique_integer([:positive])}",
        primary_pev_type: :euc,
        source: :import,
        status: :active,
        user_id: user.id
      })

    assert member |> delete(~p"/api/v1/me") |> response(204)
    refute Repo.get(RiderProfile, profile.id)
  end

  test "an old login must log in again", %{member: member, user: user} do
    old = DateTime.add(DateTime.utc_now(:second), -30, :minute)

    Repo.update_all(from(t in UserToken, where: t.user_id == ^user.id and t.context == "refresh"),
      set: [authenticated_at: old]
    )

    body = member |> delete(~p"/api/v1/me") |> json_response(403)
    assert body["error"]["code"] == "reauth_required"
    assert Repo.get(User, user.id)
  end

  test "admins can't delete themselves here", %{member: member, user: user} do
    user |> Ecto.Changeset.change(role: :admin) |> Repo.update!()

    assert member |> delete(~p"/api/v1/me") |> json_response(403)
    assert Repo.get(User, user.id)
  end
end
