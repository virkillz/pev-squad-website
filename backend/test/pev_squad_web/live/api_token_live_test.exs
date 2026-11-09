defmodule PevSquadWeb.ApiTokenLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures, only: [staff_scope_fixture: 0]

  alias PevSquad.Accounts

  test "staff create a token, see it once, and it works on the API", %{conn: conn} do
    scope = staff_scope_fixture()
    {:ok, lv, _html} = live(log_in_user(conn, scope.user), ~p"/admin/api-tokens")

    html = lv |> form("#token-form", token: %{name: "MacBook CLI"}) |> render_submit()
    assert html =~ "MacBook CLI"
    [token] = Regex.run(~r/pevsq_[A-Za-z0-9_-]+/, html)

    api =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token)
      |> get(~p"/api/v1/me")

    assert json_response(api, 200)["data"]["id"] == scope.user.id

    refute lv |> element("button", "Done") |> render_click() =~ token
  end

  test "a blank name shows an error", %{conn: conn} do
    {:ok, lv, _html} = live(log_in_user(conn, staff_scope_fixture().user), ~p"/admin/api-tokens")

    assert lv |> form("#token-form", token: %{name: ""}) |> render_submit() =~
             "can&#39;t be blank"
  end

  test "revoking removes the token", %{conn: conn} do
    scope = staff_scope_fixture()
    {:ok, plaintext, token} = Accounts.create_api_token(scope, %{"name" => "Old laptop"})
    {:ok, lv, html} = live(log_in_user(conn, scope.user), ~p"/admin/api-tokens")
    assert html =~ "Old laptop"

    html = lv |> element(~s([phx-click="revoke"][phx-value-id="#{token.id}"])) |> render_click()
    refute html =~ "Old laptop"
    refute Accounts.get_user_by_api_token(plaintext)
  end

  test "creating a token needs a recent login", %{conn: conn} do
    scope = staff_scope_fixture()
    long_ago = DateTime.add(DateTime.utc_now(:second), -60, :minute)
    conn = log_in_user(conn, scope.user, token_authenticated_at: long_ago)
    {:ok, lv, _html} = live(conn, ~p"/admin/api-tokens")

    assert {:error, {:redirect, %{to: "/users/log-in"}}} =
             lv |> form("#token-form", token: %{name: "CLI"}) |> render_submit()

    assert Accounts.list_api_tokens(scope) == []
  end

  test "members can't open the page", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} =
             live(log_in_user(conn, user_fixture()), ~p"/admin/api-tokens")
  end
end
