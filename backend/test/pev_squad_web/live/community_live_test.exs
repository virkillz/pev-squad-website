defmodule PevSquadWeb.CommunityLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.RidersFixtures

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

    test "members can't open it", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/riders")
    end
  end
end
