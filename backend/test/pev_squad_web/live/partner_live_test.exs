defmodule PevSquadWeb.PartnerLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.PartnersFixtures

  alias PevSquad.Partners

  test "the community page lists partner communities and brands", %{conn: conn} do
    partner_fixture(name: "REJS", region: "Jakarta Selatan", tagline: "EUC riders of Jaksel")
    partner_fixture(kind: :brand, name: "Wheelsxtreme", collaboration_types: [:dealer, :sponsor])

    {:ok, lv, html} = live(conn, ~p"/community")
    assert has_element?(lv, "#partner-communities", "REJS")
    assert html =~ "Jakarta Selatan · EUC"
    assert html =~ "EUC riders of Jaksel"
    assert has_element?(lv, "#brand-partners", "Wheelsxtreme")
    assert html =~ "Dealer · Sponsor"
  end

  test "sections are left out when empty", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/community")
    refute has_element?(lv, "#partner-communities")
    refute has_element?(lv, "#brand-partners")
  end

  test "a partner page shows details, links and events together", %{conn: conn} do
    partner =
      partner_fixture(
        name: "Eastlectric",
        region: "Surabaya & Malang",
        instagram: "eastlectric",
        collaboration_note: "Co-hosts our East Java rides.",
        partner_since: ~D[2025-01-01]
      )

    event = event_fixture(title: "Ngeride ke Bromo")
    {:ok, _} = Partners.set_event_partners(staff_scope_fixture(), event, [partner.id])

    {:ok, lv, html} = live(conn, ~p"/partners/#{partner.slug}")
    assert html =~ "Co-hosts our East Java rides."
    assert html =~ "January 2025"
    assert has_element?(lv, ~s|#partner-links a[href="https://instagram.com/eastlectric"]|)
    assert has_element?(lv, "#partner-events", "Ngeride ke Bromo")
    refute html =~ "Edit partner"

    {:ok, lv, _html} = live(conn, ~p"/events/#{event.slug}")
    assert has_element?(lv, ~s|#event-partners a[href="/partners/#{partner.slug}"]|)
  end

  test "hidden partners 404", %{conn: conn} do
    partner = partner_fixture(published: false)

    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/partners/#{partner.slug}") end
  end

  describe "admin" do
    setup %{conn: conn} do
      staff = staff_scope_fixture()
      %{conn: log_in_user(conn, staff.user), staff: staff}
    end

    test "creates a brand partner with a logo", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/partners/new?kind=brand")

      logo =
        file_input(lv, "#partner-form", :logo, [
          %{
            name: "logo.png",
            content: File.read!(PevSquad.RidersFixtures.image_fixture(300, 300)),
            type: "image/png"
          }
        ])

      render_upload(logo, "logo.png")

      {:ok, _show, html} =
        lv
        |> form("#partner-form",
          partner: %{
            kind: "brand",
            name: "Taco Bell",
            tagline: "Fed 40 riders at Senopati",
            collaboration_types: ["food_drink", "venue"]
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Partner saved"
      assert html =~ "Taco Bell"
      assert html =~ "Food &amp; drink · Venue"

      [partner] = Partners.list_partners(:brand)
      assert partner.logo_path =~ ".webp"
    end

    test "links partners from the event form", %{conn: conn} do
      partner = partner_fixture(name: "SNOI")
      event = event_fixture()

      {:ok, lv, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

      lv
      |> form("#event-form")
      |> render_submit(%{"partner_ids" => ["", "#{partner.id}"]})

      assert [%{name: "SNOI"}] = Partners.list_event_partners(event)
    end

    test "members can't reach the admin pages", %{conn: _conn} do
      conn = log_in_user(build_conn(), user_fixture())
      assert {:error, {:redirect, _}} = live(conn, ~p"/admin/partners")
    end
  end
end
