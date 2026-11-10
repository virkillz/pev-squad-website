defmodule PevSquadWeb.PrivacyLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest

  test "shows the policy with the account deletion section", %{conn: conn} do
    {:ok, lv, html} = live(conn, ~p"/privacy")

    assert html =~ "Privacy policy"
    assert has_element?(lv, "#privacy-policy h2#delete-account", "Deleting your account")
    assert has_element?(lv, "#privacy-policy a[href^='mailto:']")
    assert has_element?(lv, "#footer-privacy[href='/privacy']")
  end

  test "is in Indonesian when the locale is id", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/privacy?locale=id")

    assert has_element?(lv, "#privacy-policy h2#delete-account", "Menghapus akun")
  end
end
