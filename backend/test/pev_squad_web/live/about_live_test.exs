defmodule PevSquadWeb.AboutLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.EventsFixtures
  import PevSquad.PartnersFixtures

  test "shows the three pillars with real events under them", %{conn: conn} do
    past = fn days -> DateTime.add(DateTime.utc_now(:second), -days, :day) end
    event_fixture(title: "Mararia", kind: :race, starts_at: past.(30))
    event_fixture(title: "Ngeride ke Bromo", kind: :getaway, starts_at: past.(20))
    event_fixture(title: "TV One Interview", kind: :media, starts_at: past.(10))
    partner_fixture(name: "SNOI")

    {:ok, lv, html} = live(conn, ~p"/about")

    assert html =~ "Speed. Adventure."
    assert has_element?(lv, "#pillar-speed", "Mararia")
    assert has_element?(lv, "#pillar-adventure", "Ngeride ke Bromo")
    refute has_element?(lv, "#pillars", "TV One Interview")
    assert has_element?(lv, "#pillar-freedom", "public transport")
    assert has_element?(lv, "#about-stats", "3")
    assert html =~ "1 COMMUNITY"
  end

  test "the home page uses the new tagline", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/")
    assert html =~ "SPEED · ADVENTURE · FREEDOM"
    assert html =~ "Speed, adventure, freedom." or html =~ "speed, adventure, freedom."
    refute html =~ "RIDE OFTEN"
    assert html =~ ~s|href="/about"|
  end
end
