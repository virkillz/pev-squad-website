defmodule PevSquadWeb.LocaleTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures

  defp in_indonesian(conn), do: init_test_session(conn, %{"locale" => "id"})

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

  describe "events in Indonesian" do
    test "the list shows translated labels and dates", %{conn: conn} do
      event_fixture(
        title: "Night Loop SCBD",
        kind: :night_ride,
        capacity: 10,
        starts_at: ~U[2099-08-15 13:00:00Z]
      )

      {:ok, _lv, html} = conn |> in_indonesian() |> live(~p"/events")

      assert html =~ "Catat di kalender"
      assert html =~ "Adakan Group Ride"
      assert html =~ "0 / 10 ikut"
      assert html =~ "Agu"
      assert html =~ "Night Loop SCBD"
    end

    test "the detail page shows the RSVP box and translated flashes", %{conn: conn} do
      event = event_fixture(capacity: 3, starts_at: ~U[2099-08-17 01:00:00Z])

      {:ok, _lv, html} = conn |> in_indonesian() |> live(~p"/events/#{event.slug}")
      assert html =~ "Masuk untuk RSVP"
      assert html =~ "Sen 17 Agu 2099"

      user = user_fixture()
      conn = conn |> in_indonesian() |> log_in_user(user)
      {:ok, lv, html} = live(conn, ~p"/events/#{event.slug}")
      assert html =~ "Sisa 3 kursi."
      assert lv |> element("button", "RSVP — Saya ikut") |> render_click() =~ "Kamu ikut"
    end
  end

  describe "auth in Indonesian" do
    test "login and registration pages", %{conn: conn} do
      {:ok, _lv, html} = conn |> in_indonesian() |> live(~p"/users/log-in")
      assert html =~ "Masuk dengan email"
      assert html =~ "Belum punya akun?"

      {:ok, _lv, html} = conn |> in_indonesian() |> live(~p"/users/register")
      assert html =~ "Daftar akun"
    end

    test "the language choice survives logging in and out", %{conn: conn} do
      user = user_fixture() |> set_password()

      conn =
        conn
        |> in_indonesian()
        |> post(~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, "locale") == "id"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Selamat datang kembali!"

      conn = conn |> recycle() |> delete(~p"/users/log-out")
      assert get_session(conn, "locale") == "id"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Berhasil keluar."
    end
  end

  describe "public pages in Indonesian" do
    test "community, gallery, reviews and about", %{conn: conn} do
      conn = in_indonesian(conn)

      {:ok, _lv, html} = live(conn, ~p"/community")
      assert html =~ "Cari alias, kota, atau kendaraan"
      assert html =~ "Rider terdaftar"

      {:ok, _lv, html} = live(conn, ~p"/gallery")
      assert html =~ "Kirim ke Kami."

      {:ok, _lv, html} = live(conn, ~p"/reviews")
      assert html =~ "Tulis Review"

      {:ok, _lv, html} = live(conn, ~p"/about")
      assert html =~ "Riding Bareng Kami"
    end

    test "the mobile menu button carries both labels", %{conn: conn} do
      html = conn |> in_indonesian() |> get(~p"/for-sale") |> html_response(200)
      assert html =~ ~s(data-label-open="Tutup")
      assert html =~ ~s(data-label-closed="Menu")
    end
  end

  describe "core labels and validation messages" do
    test "are translated in the caller's locale" do
      Gettext.put_locale(PevSquadWeb.Gettext, "id")

      assert {:spam, "Spam atau iklan"} in PevSquad.Safety.Report.reasons()
      assert PevSquad.Partners.Partner.collaboration_label(:venue) == "Venue"
      assert {:power, "Tenaga"} in PevSquad.Reviews.Review.criteria()

      changeset = PevSquad.Safety.Report.changeset(%PevSquad.Safety.Report{}, %{})
      [error] = Keyword.get_values(changeset.errors, :reason)
      assert PevSquadWeb.CoreComponents.translate_error(error) == "pilih alasan"
    end
  end

  describe "the account remembers the language" do
    test "registering saves the language being browsed in", %{conn: conn} do
      {:ok, lv, _html} = conn |> in_indonesian() |> live(~p"/users/register")
      email = unique_user_email()

      assert {:error, {:live_redirect, _}} =
               lv |> form("#registration_form", user: %{email: email}) |> render_submit()

      assert PevSquad.Accounts.get_user_by_email(email).locale == "id"
    end

    test "switching while logged in saves the choice", %{conn: conn} do
      user = user_fixture()
      conn |> log_in_user(user) |> get(~p"/locale/en")

      assert PevSquad.Accounts.get_user!(user.id).locale == "en"
    end

    test "logging in brings back the saved language", %{conn: conn} do
      user = user_fixture() |> set_password()
      {:ok, user} = PevSquad.Accounts.update_user_locale(user, "id")

      conn =
        conn
        |> put_req_header("accept-language", "en")
        |> post(~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, "locale") == "id"
    end

    test "a language picked just before logging in wins and is saved", %{conn: conn} do
      user = user_fixture() |> set_password()
      {:ok, user} = PevSquad.Accounts.update_user_locale(user, "id")

      conn = get(conn, ~p"/locale/en")

      conn =
        conn
        |> recycle()
        |> post(~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, "locale") == "en"
      assert PevSquad.Accounts.get_user!(user.id).locale == "en"
    end

    test "an account without a language takes the one being browsed in", %{conn: conn} do
      user = user_fixture() |> set_password()

      conn
      |> in_indonesian()
      |> post(~p"/users/log-in", %{
        "user" => %{"email" => user.email, "password" => valid_user_password()}
      })

      assert PevSquad.Accounts.get_user!(user.id).locale == "id"
    end
  end

  describe "emails" do
    test "go out in the recipient's language, whoever triggers them" do
      Gettext.put_locale(PevSquadWeb.Gettext, "en")
      event = event_fixture(title: "Bromo Run")

      {:ok, email} =
        PevSquad.Events.Notifier.deliver_waitlist_promotion(
          %{email: "rider@example.com", locale: "id"},
          event,
          "https://pev-squad.org/events/bromo"
        )

      assert email.subject == "Kamu ikut: Bromo Run"
      assert email.text_body =~ "Ada kursi kosong di Bromo Run"
      assert email.text_body =~ "https://pev-squad.org/events/bromo"
      # The caller's own locale is left alone.
      assert Gettext.get_locale(PevSquadWeb.Gettext) == "en"
    end

    test "use the site default when the recipient never picked one" do
      event = event_fixture(title: "Bromo Run")

      {:ok, email} =
        PevSquad.Events.Notifier.deliver_event_cancelled(
          %{email: "rider@example.com", locale: nil},
          event,
          "https://pev-squad.org/events/bromo"
        )

      assert email.subject == "Cancelled: Bromo Run"
    end

    test "login links follow the language the rider is browsing in", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = conn |> in_indonesian() |> live(~p"/users/log-in")

      assert {:error, {:live_redirect, _}} =
               lv |> form("#login_form_magic", user: %{email: user.email}) |> render_submit()

      assert_received {:email, %{subject: "Petunjuk masuk"}}
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
