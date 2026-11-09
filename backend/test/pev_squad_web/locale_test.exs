defmodule PevSquadWeb.LocaleTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "picking the locale" do
    test "falls back to the configured default", %{conn: conn} do
      conn = get(conn, ~p"/for-sale")
      assert get_session(conn, "locale") == "en"
      assert html_response(conn, 200) =~ ~s(<html lang="en">)
    end

    test "follows the browser's Accept-Language", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "id-ID,id;q=0.9,en-US;q=0.8")
        |> get(~p"/for-sale")

      assert get_session(conn, "locale") == "id"
      html = html_response(conn, 200)
      assert html =~ ~s(<html lang="id">)
      assert html =~ "Beranda"
    end

    test "honours q-values and ignores unsupported languages", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "fr;q=1.0, en;q=0.5, id;q=0.8")
        |> get(~p"/for-sale")

      assert get_session(conn, "locale") == "id"
    end

    test "a saved choice beats the header", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{"locale" => "en"})
        |> put_req_header("accept-language", "id")
        |> get(~p"/for-sale")

      assert get_session(conn, "locale") == "en"
    end

    test "ignores unsupported ?locale values", %{conn: conn} do
      conn = get(conn, ~p"/for-sale?locale=fr")
      assert get_session(conn, "locale") == "en"
    end
  end

  describe "the language switch" do
    test "stores the choice and returns to the referring page", %{conn: conn} do
      conn =
        conn
        |> put_req_header("referer", "http://localhost/events?page=2")
        |> get(~p"/locale/id")

      assert redirected_to(conn) == "/events?page=2"
      assert get_session(conn, "locale") == "id"
    end

    test "never redirects off-site", %{conn: conn} do
      conn =
        conn
        |> put_req_header("referer", "https://evil.example//phish")
        |> get(~p"/locale/en")

      assert redirected_to(conn) == "/"
    end

    test "goes home without a referer", %{conn: conn} do
      assert conn |> get(~p"/locale/en") |> redirected_to() == "/"
    end
  end

  describe "LiveViews" do
    test "render in Indonesian when that's the session locale", %{conn: conn} do
      {:ok, _lv, html} = conn |> init_test_session(%{"locale" => "id"}) |> live(~p"/")

      assert html =~ "KECEPATAN · PETUALANGAN · KEBEBASAN"
      assert html =~ "Gabung Squad"
      assert html =~ "Komunitas"
    end

    test "render in English when that's the session locale", %{conn: conn} do
      {:ok, _lv, html} = conn |> init_test_session(%{"locale" => "en"}) |> live(~p"/")

      assert html =~ "SPEED · ADVENTURE · FREEDOM"
      assert html =~ "Join the Squad"
    end

    test "translate changeset errors", %{conn: conn} do
      {:ok, lv, _html} =
        conn |> init_test_session(%{"locale" => "id"}) |> live(~p"/users/register")

      html = lv |> form("#registration_form", user: %{email: ""}) |> render_change()
      assert html =~ "tidak boleh kosong"
    end
  end

  describe "strftime/2" do
    test "uses Indonesian month and day names" do
      Gettext.put_locale(PevSquadWeb.Gettext, "id")

      assert PevSquadWeb.Locale.strftime(~D[2026-11-11], "%a %d %b / %A %B") ==
               "Rab 11 Nov / Rabu November"

      assert PevSquadWeb.Locale.strftime(~D[2026-08-17], "%d %B") == "17 Agustus"
    end

    test "leaves English alone" do
      Gettext.put_locale(PevSquadWeb.Gettext, "en")
      assert PevSquadWeb.Locale.strftime(~D[2026-11-11], "%a %b") == "Wed Nov"
    end
  end
end
