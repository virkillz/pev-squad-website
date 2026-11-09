defmodule PevSquad.AccountsApiTokenTest do
  use PevSquad.DataCase, async: true

  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures, only: [staff_scope_fixture: 0, staff_scope_fixture: 1]

  alias PevSquad.Accounts
  alias PevSquad.Accounts.UserToken

  describe "create_api_token/2" do
    test "staff get a pevsq_ token that is stored only as a hash" do
      scope = staff_scope_fixture()

      assert {:ok, "pevsq_" <> _ = plaintext, token} =
               Accounts.create_api_token(scope, %{"name" => " CLI "})

      assert token.name == "CLI"
      assert token.context == "api"
      assert DateTime.diff(token.expires_at, DateTime.utc_now(), :day) in 364..365
      refute Repo.get_by(UserToken, token: plaintext)
    end

    test "requires a name" do
      assert {:error, changeset} =
               Accounts.create_api_token(staff_scope_fixture(), %{"name" => ""})

      assert "can't be blank" in errors_on(changeset).name
    end

    test "members can't create one" do
      assert {:error, :forbidden} =
               Accounts.create_api_token(user_scope_fixture(), %{"name" => "x"})
    end
  end

  describe "get_user_by_api_token/1" do
    setup do
      scope = staff_scope_fixture()
      {:ok, plaintext, token} = Accounts.create_api_token(scope, %{"name" => "CLI"})
      %{scope: scope, plaintext: plaintext, token: token}
    end

    test "returns the user and records last use", %{
      scope: scope,
      plaintext: plaintext,
      token: token
    } do
      assert %{id: id} = Accounts.get_user_by_api_token(plaintext)
      assert id == scope.user.id
      assert Repo.reload!(token).last_used_at
    end

    test "rejects unknown, malformed and session-shaped tokens", %{plaintext: plaintext} do
      refute Accounts.get_user_by_api_token(plaintext <> "x")

      refute Accounts.get_user_by_api_token(
               "pevsq_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
             )

      refute Accounts.get_user_by_api_token("pevsq_!!!")
      refute Accounts.get_user_by_api_token("")
    end

    test "rejects expired tokens", %{plaintext: plaintext, token: token} do
      token
      |> Ecto.Changeset.change(expires_at: DateTime.add(DateTime.utc_now(:second), -1, :day))
      |> Repo.update!()

      refute Accounts.get_user_by_api_token(plaintext)
    end

    test "stops working when the user is no longer staff", %{scope: scope, plaintext: plaintext} do
      {:ok, _} = Accounts.set_user_role(scope.user, :member)
      refute Accounts.get_user_by_api_token(plaintext)
    end

    test "is revoked by a password change", %{scope: scope, plaintext: plaintext} do
      {:ok, _} = Accounts.update_user_password(scope.user, %{password: "a brand new password"})
      refute Accounts.get_user_by_api_token(plaintext)
    end
  end

  test "staff list and revoke only their own tokens" do
    me = staff_scope_fixture()
    other = staff_scope_fixture(:admin)
    {:ok, _, mine} = Accounts.create_api_token(me, %{"name" => "mine"})
    {:ok, _, theirs} = Accounts.create_api_token(other, %{"name" => "theirs"})

    assert [%{name: "mine"}] = Accounts.list_api_tokens(me)
    assert {:error, :not_found} = Accounts.delete_api_token(me, theirs.id)
    assert {:ok, _} = Accounts.delete_api_token(me, mine.id)
    assert Accounts.list_api_tokens(me) == []
    assert [%{name: "theirs"}] = Accounts.list_api_tokens(other)
  end
end
