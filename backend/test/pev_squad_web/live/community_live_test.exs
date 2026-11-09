defmodule PevSquadWeb.CommunityLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.RidersFixtures
  import PevSquad.PartnersFixtures

  test "roster shows public riders and filters by type", %{conn: conn} do
    rider_fixture(alias: "Wynn", main_ride: "Sherman OG")
    rider_fixture(alias: "Ben Esk8", primary_pev_type: :esk8)
    rider_fixture(alias: "Hidden Rider", is_public: false)

    {:ok, lv, html} = live(conn, ~p"/community")
    assert html =~ "Wynn"
    assert html =~ "SHERMAN OG"
    assert html =~ "Ben Esk8"
    refute html =~ "Hidden Rider"

    html = lv |> element(".filter-tag", "Esk8") |> render_click()
    assert_patch(lv, ~p"/community?type=esk8")
    assert html =~ "Ben Esk8"
    refute html =~ "Wynn"
  end

  test "the roster shows 9 riders a page", %{conn: conn} do
    for i <- 1..10, do: rider_fixture(alias: "Rider #{String.pad_leading("#{i}", 2, "0")}")

    {:ok, lv, _html} = live(conn, ~p"/community")
    assert has_element?(lv, "#roster", "Rider 09")
    refute has_element?(lv, "#roster", "Rider 10")
    assert has_element?(lv, "#roster-pager", "1–9 of 10 riders")

    lv |> element("#roster-pager a", "Next") |> render_click()
    assert_patch(lv, "/community?page=2")
    assert has_element?(lv, "#roster", "Rider 10")
    refute has_element?(lv, "#roster", "Rider 01")
    assert has_element?(lv, "#roster-pager", "10–10 of 10 riders")

    # Filtering goes back to page 1; no pager when it all fits.
    lv |> element(".filter-tag", "Esk8") |> render_click()
    refute has_element?(lv, "#roster-pager")

    {:ok, lv, _html} = live(conn, ~p"/community?page=abc")
    assert has_element?(lv, "#roster", "Rider 01")
  end

  test "rider page", %{conn: conn} do
    rider =
      rider_fixture(
        alias: "Si Ganteng",
        bio: "Best-looking rider in Bogor.",
        instagram: "siganteng"
      )

    {:ok, _lv, html} = live(conn, ~p"/community/#{rider.slug}")
    assert html =~ "Si Ganteng"
    assert html =~ "Best-looking rider in Bogor."
    assert html =~ "instagram.com/siganteng"
  end

  test "the old Featured Riders link goes to the community page", %{conn: conn} do
    assert redirected_to(get(conn, ~p"/riders")) == ~p"/community"
  end

  describe "my profile" do
    setup :register_and_log_in_user

    test "creates a profile with a photo", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/profile")

      photo =
        file_input(lv, "#profile-form", :avatar, [
          %{name: "me.jpg", content: File.read!(image_fixture()), type: "image/jpeg"}
        ])

      render_upload(photo, "me.jpg")

      html =
        lv
        |> form("#profile-form",
          rider_profile: %{
            alias: "Night Owl",
            city: "Depok",
            primary_pev_type: "euc",
            is_public: "true"
          }
        )
        |> render_submit()

      assert html =~ "Profile saved."
      assert html =~ "/community/night-owl"

      {:ok, _lv, html} = live(conn, ~p"/community/night-owl")
      assert html =~ ~r{/uploads/avatars/night-owl-.+\.webp}
    end

    test "shows validation errors", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/profile")

      html = lv |> form("#profile-form", rider_profile: %{alias: "x"}) |> render_change()
      assert html =~ "should be at least 2 character"
    end
  end

  describe "admin" do
    test "staff link an imported profile to a member", %{conn: conn} do
      staff = staff_scope_fixture()
      rider = rider_fixture(alias: "Awang")
      member = user_fixture()

      {:ok, lv, _html} = live(log_in_user(conn, staff.user), ~p"/admin/riders/#{rider}/edit")

      html = lv |> form("#link-form", email: member.email) |> render_submit()
      assert html =~ "Linked to #{member.email}"
    end

    test "staff set a rider's partner communities; they show on the roster, rider and partner pages",
         %{conn: conn} do
      staff = staff_scope_fixture()
      rider = rider_fixture(alias: "Awang")
      rejs = partner_fixture(name: "REJS")
      partner_fixture(kind: :brand, name: "Hyundai")

      {:ok, lv, html} = live(log_in_user(conn, staff.user), ~p"/admin/riders/#{rider}/edit")
      assert html =~ "REJS"
      refute html =~ "Hyundai"

      lv
      |> form("#rider-form")
      |> render_submit(%{"community_ids" => ["", "#{rejs.id}"]})

      assert render(lv) =~ "Saved."

      {:ok, _lv, html} = live(conn, ~p"/community")
      assert html =~ ~s(title="REJS")

      {:ok, lv, _html} = live(conn, ~p"/community/#{rider.slug}")
      assert lv |> element("#rider-communities a", "REJS") |> has_element?()

      {:ok, lv, _html} = live(conn, ~p"/partners/#{rejs.slug}")
      assert lv |> element("#partner-riders", "Awang") |> has_element?()
    end

    test "staff can't pick more than three communities", %{conn: conn} do
      staff = staff_scope_fixture()
      rider = rider_fixture()
      ids = for _ <- 1..4, do: "#{partner_fixture().id}"

      {:ok, lv, _html} = live(log_in_user(conn, staff.user), ~p"/admin/riders/#{rider}/edit")
      html = lv |> form("#rider-form") |> render_submit(%{"community_ids" => ids})

      assert html =~ "Pick at most 3"
      assert PevSquad.Riders.community_ids(staff, rider) == []
    end

    test "members can't open it", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/riders")
    end
  end
end
