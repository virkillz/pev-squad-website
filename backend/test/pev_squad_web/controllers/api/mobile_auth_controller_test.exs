defmodule PevSquadWeb.API.MobileAuthControllerTest do
  use PevSquadWeb.ConnCase, async: true
  import PevSquad.AccountsFixtures
  import Ecto.Query
  alias PevSquad.{Accounts, Repo, Riders}
  alias PevSquad.Accounts.{MobileAuth, Scope, UserToken}

  setup %{conn: conn} do
    user = user_fixture() |> set_password()
    {:ok, session} = MobileAuth.password(user.email, valid_user_password())
    conn = put_req_header(conn, "accept", "application/json")

    %{
      conn: conn,
      member: put_req_header(conn, "authorization", "Bearer " <> session.access_token),
      user: user,
      session: session
    }
  end

  test "password login returns hashed expiring member credentials", %{
    conn: conn,
    user: user,
    member: member
  } do
    result =
      conn
      |> post(~p"/api/v1/auth/password", %{email: user.email, password: valid_user_password()})
      |> json_response(200)

    assert result["data"]["expires_in"] == 900
    assert result["data"]["refresh_token"] =~ "pevm_r_"

    assert member |> get(~p"/api/v1/me") |> json_response(200) |> get_in(["data", "id"]) ==
             user.id

    for row <-
          Repo.all(from t in UserToken, where: t.context == "refresh" and t.user_id == ^user.id) do
      assert byte_size(row.token) == 32
      assert DateTime.diff(row.expires_at, DateTime.utc_now(), :day) in 29..30
    end
  end

  test "wrong, missing, and unconfirmed credentials are rejected", %{conn: conn, user: user} do
    assert conn
           |> post(~p"/api/v1/auth/password", %{email: user.email, password: "wrong"})
           |> json_response(401)

    assert conn |> post(~p"/api/v1/auth/password", %{}) |> json_response(401)
    user = unconfirmed_user_fixture() |> set_password()

    assert conn
           |> post(~p"/api/v1/auth/password", %{
             email: user.email,
             password: valid_user_password()
           })
           |> json_response(401)
  end

  test "refresh rotates once and logout revokes both credentials", %{
    conn: conn,
    session: old,
    member: member
  } do
    next =
      conn
      |> post(~p"/api/v1/auth/refresh", %{refresh_token: old.refresh_token})
      |> json_response(200)
      |> Map.fetch!("data")

    assert conn
           |> post(~p"/api/v1/auth/refresh", %{refresh_token: old.refresh_token})
           |> json_response(401)

    assert member |> get(~p"/api/v1/me") |> json_response(401)
    assert MobileAuth.get_user(next["access_token"])

    assert conn
           |> post(~p"/api/v1/auth/logout", %{refresh_token: next["refresh_token"]})
           |> response(204)

    assert MobileAuth.get_user(next["access_token"]) == nil
    assert MobileAuth.refresh(next["refresh_token"]) == {:error, :unauthorized}
  end

  test "expired and malformed tokens are rejected", %{conn: conn, user: user, session: session} do
    Repo.update_all(from(t in UserToken, where: t.context == "refresh" and t.user_id == ^user.id),
      set: [expires_at: ~U[2000-01-01 00:00:00Z]]
    )

    assert MobileAuth.get_user(session.access_token) == nil
    assert MobileAuth.refresh(session.refresh_token) == {:error, :unauthorized}
    assert conn |> post(~p"/api/v1/auth/exchange", %{token: "broken"}) |> json_response(401)
    assert conn |> post(~p"/api/v1/auth/exchange", %{}) |> json_response(401)
  end

  test "app email tokens confirm an account once and reject web tokens", %{conn: conn} do
    user = unconfirmed_user_fixture()
    {token, row} = UserToken.build_email_token(user, "app_login")
    Repo.insert!(row)
    assert conn |> post(~p"/api/v1/auth/exchange", %{token: token}) |> json_response(200)
    assert Accounts.get_user!(user.id).confirmed_at
    assert conn |> post(~p"/api/v1/auth/exchange", %{token: token}) |> json_response(401)
    {web, _hash} = generate_user_magic_link_token(user)
    assert conn |> post(~p"/api/v1/auth/exchange", %{token: web}) |> json_response(401)
  end

  test "email request registers and sends an app link", %{conn: conn} do
    email = unique_user_email()

    assert conn |> post(~p"/api/v1/auth/magic-link", %{email: email}) |> json_response(202) == %{
             "data" => %{"sent" => true}
           }

    assert Accounts.get_user_by_email(email).confirmed_at == nil
    assert_receive {:email, %Swoosh.Email{to: [{_, ^email}]} = message}
    assert message.text_body =~ "pevsquad:///auth/confirm?token="
    assert conn |> post(~p"/api/v1/auth/magic-link", %{}) |> json_response(422)
  end

  test "password changes revoke app sessions", %{user: user, session: session} do
    {:ok, _} = Accounts.update_user_password(user, %{password: "a different secure password"})
    assert MobileAuth.get_user(session.access_token) == nil
    assert MobileAuth.refresh(session.refresh_token) == {:error, :unauthorized}
  end

  test "profile is scoped, pending and private by default; locale persists", %{
    conn: conn,
    member: member,
    user: user
  } do
    profile = %{
      alias: "Mobile #{System.unique_integer([:positive])}",
      city: "Jakarta",
      primary_pev_type: "euc",
      status: "active",
      user_id: 1
    }

    result = member |> put(~p"/api/v1/me/profile", profile) |> json_response(200)
    assert result["data"]["rider_profile"]["status"] == "pending"
    assert result["data"]["rider_profile"]["is_public"] == false
    assert Riders.get_my_profile(Scope.for_user(user)).user_id == user.id

    assert member
           |> put(~p"/api/v1/me/profile", %{alias: "!", primary_pev_type: "euc"})
           |> json_response(422)

    assert conn |> put(~p"/api/v1/me/profile", profile) |> json_response(401)

    assert member
           |> patch(~p"/api/v1/me", %{locale: "id"})
           |> json_response(200)
           |> get_in(["data", "locale"]) == "id"

    assert member |> patch(~p"/api/v1/me", %{locale: "invalid"}) |> json_response(422)
  end

  test "a new app profile emails staff a link to review it", %{member: member} do
    admin = user_fixture() |> Ecto.Changeset.change(role: :admin) |> Repo.update!()
    profile = %{alias: "Staff #{System.unique_integer([:positive])}", primary_pev_type: "euc"}
    member |> put(~p"/api/v1/me/profile", profile) |> json_response(200)

    email = admin.email

    assert_received {:email,
                     %Swoosh.Email{
                       to: [{_, ^email}],
                       subject: "New rider waiting" <> _,
                       text_body: body
                     }}

    assert body =~ "/admin/riders/"
  end

  test "repeated password attempts are throttled", %{conn: conn} do
    email = unique_user_email()

    for _ <- 1..5,
        do:
          assert(
            conn
            |> post(~p"/api/v1/auth/password", %{email: email, password: "wrong"})
            |> json_response(401)
          )

    assert conn
           |> post(~p"/api/v1/auth/password", %{email: email, password: "wrong"})
           |> json_response(429)
  end
end
