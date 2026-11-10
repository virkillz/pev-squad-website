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

  test "riders without a partner community still show the Squad mark", %{conn: conn} do
    rider_fixture(alias: "Solo")

    {:ok, lv, _html} = live(conn, ~p"/community")
    assert lv |> element("#roster .rider-community[title='PEV Squad'] img") |> has_element?()
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

  test "the roster searches and sorts, keeping both in the URL and pager", %{conn: conn} do
    for i <- 1..10, do: rider_fixture(alias: "Rider #{String.pad_leading("#{i}", 2, "0")}")
    rider_fixture(alias: "Wynn", city: "Malang")

    {:ok, lv, _html} = live(conn, ~p"/community")

    lv |> form("#roster-controls", q: "malang", sort: "az") |> render_change()
    assert_patch(lv, "/community?q=malang")
    assert lv |> element("#roster", "Wynn") |> has_element?()
    refute lv |> element("#roster", "Rider 01") |> has_element?()

    lv |> form("#roster-controls", q: "nobody", sort: "az") |> render_change()
    assert render(lv) =~ "No riders match “nobody”."

    lv |> form("#roster-controls", q: "rider", sort: "za") |> render_change()
    assert_patch(lv, "/community?sort=za&q=rider")
    assert lv |> element("#roster .card:first-child", "Rider 10") |> has_element?()

    assert lv |> element("#roster-pager a[rel=next]") |> render() =~
             "sort=za&amp;q=rider&amp;page=2"

    {:ok, lv, _html} = live(conn, ~p"/community?sort=bogus&type=euc")
    assert lv |> element("#roster-sort option[selected]") |> render() =~ "A to Z"
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

  test "a rider's photo is the link-preview image", %{conn: conn} do
    rider =
      rider_fixture(alias: "Popo")
      |> Ecto.Changeset.change(avatar_path: "/uploads/avatars/popo.webp")
      |> PevSquad.Repo.update!()

    html = conn |> get(~p"/community/#{rider.slug}") |> html_response(200)
    assert html =~ ~r{<meta property="og:image" content="http[^"]*/uploads/avatars/popo\.webp"}
    assert html =~ ~s(<meta property="og:type" content="profile")
    assert html =~ ~s(<meta name="twitter:card" content="summary_large_image")

    no_photo = rider_fixture()
    html = build_conn() |> get(~p"/community/#{no_photo.slug}") |> html_response(200)
    assert html =~ ~r{<meta property="og:image" content="http[^"]*/images/logo\.jpg"}

    banned =
      rider
      |> Ecto.Changeset.change(
        status: :banned,
        banned_at: DateTime.utc_now(:second),
        ban_reason: "Banned."
      )
      |> PevSquad.Repo.update!()

    html = build_conn() |> get(~p"/community/#{banned.slug}") |> html_response(200)
    refute html =~ "popo.webp"
  end

  test "the old Featured Riders link goes to the community page", %{conn: conn} do
    assert redirected_to(get(conn, ~p"/riders")) == ~p"/community"
  end

  describe "my profile" do
    setup :register_and_log_in_user

    test "a banned member sees a notice instead of the form", %{conn: conn, scope: scope} do
      {:ok, profile} = PevSquad.Riders.save_my_profile(scope, %{alias: "Outlaw"})

      {:ok, _} =
        PevSquad.Riders.update_rider(staff_scope_fixture(), profile, %{
          status: :banned,
          ban_reason: "Theft."
        })

      {:ok, lv, _html} = live(conn, ~p"/users/profile")
      assert has_element?(lv, "#profile-banned")
      refute has_element?(lv, "#profile-form")
    end

    test "a member sees when staff hid their profile", %{conn: conn, scope: scope} do
      {:ok, profile} = PevSquad.Riders.save_my_profile(scope, %{alias: "Shy", is_public: true})

      {:ok, _} =
        PevSquad.Riders.update_rider(staff_scope_fixture(), profile, %{hidden_by_staff: true})

      {:ok, lv, _html} = live(conn, ~p"/users/profile")
      assert has_element?(lv, "#profile-hidden")
      assert has_element?(lv, "#profile-form")
    end

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

      assert html =~ "A moderator will check it before it goes live."
      assert has_element?(lv, "#profile-pending")

      # Hidden until approved.
      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/community/night-owl") end

      profile = PevSquad.Repo.get_by!(PevSquad.Riders.RiderProfile, alias: "Night Owl")
      {:ok, _} = PevSquad.Riders.approve_rider(staff_scope_fixture(), profile)

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

      # Every card leads with the Squad mark, affiliations or not.
      assert html =~ ~r{title="PEV Squad".*title="REJS"}s

      {:ok, lv, _html} = live(conn, ~p"/community/#{rider.slug}")
      assert lv |> element("#rider-communities a", "REJS") |> has_element?()

      {:ok, lv, _html} = live(conn, ~p"/partners/#{rejs.slug}")
      assert lv |> element("#partner-riders", "Awang") |> has_element?()
    end

    test "staff add a new rider from the riders list", %{conn: conn} do
      staff = staff_scope_fixture()
      rejs = partner_fixture(name: "REJS")
      conn = log_in_user(conn, staff.user)

      {:ok, lv, _html} = live(conn, ~p"/admin/riders")

      {:ok, lv, _html} =
        lv |> element("a", "New Rider") |> render_click() |> follow_redirect(conn)

      refute has_element?(lv, "#link-form")

      assert lv
             |> form("#rider-form", rider_profile: %{alias: "x"})
             |> render_change() =~ "should be at least 2 character"

      {:ok, _lv, html} =
        lv
        |> form("#rider-form",
          rider_profile: %{alias: "Coach Inno", city: "Jakarta", is_public: "true"}
        )
        |> render_submit(%{"community_ids" => ["", "#{rejs.id}"]})
        |> follow_redirect(conn)

      assert html =~ "Coach Inno added."
      assert html =~ "Added by staff."
      assert html =~ "link-form"

      rider = PevSquad.Repo.get_by!(PevSquad.Riders.RiderProfile, alias: "Coach Inno")
      assert PevSquad.Riders.community_ids(staff, rider) == [rejs.id]
    end

    test "staff ban a rider with a public statement", %{conn: conn} do
      staff = staff_scope_fixture()
      rider = rider_fixture(alias: "Outlaw", bio: "Fast rider")
      admin_conn = log_in_user(conn, staff.user)

      {:ok, lv, html} = live(admin_conn, ~p"/admin/riders/#{rider}/edit")
      refute html =~ "Public statement"

      assert lv
             |> form("#rider-form", rider_profile: %{status: "banned"})
             |> render_change() =~ "Public statement"

      html = lv |> form("#rider-form", rider_profile: %{status: "banned"}) |> render_submit()
      assert html =~ "write the public statement for the ban"

      lv
      |> form("#rider-form",
        rider_profile: %{
          status: "banned",
          ban_reason: "Rode drunk at an event.\n\nReported to police."
        }
      )
      |> render_submit()

      assert render(lv) =~ "Saved."

      {:ok, _lv, html} = live(build_conn(), ~p"/community")
      refute html =~ "Outlaw"

      {:ok, lv, html} = live(build_conn(), ~p"/community/#{rider.slug}")
      assert has_element?(lv, "#rider-banned", "Outlaw has been banned")
      assert has_element?(lv, "#rider-banned p", "Reported to police.")
      refute html =~ "Fast rider"

      {:ok, _lv, html} = live(admin_conn, ~p"/admin/riders")
      assert html =~ "Banned"
    end

    test "inactive riders show a badge on the roster and their page", %{conn: conn} do
      staff = staff_scope_fixture()
      rider = rider_fixture(alias: "Retired")
      {:ok, _} = PevSquad.Riders.update_rider(staff, rider, %{status: :inactive})

      {:ok, lv, _html} = live(conn, ~p"/community")
      assert lv |> element("#roster", "Inactive") |> has_element?()

      {:ok, lv, _html} = live(conn, ~p"/community/#{rider.slug}")
      assert has_element?(lv, "#rider-inactive")
    end

    test "staff hide and delete a rider", %{conn: conn} do
      staff = staff_scope_fixture()
      rider = rider_fixture(alias: "Vanish")
      admin_conn = log_in_user(conn, staff.user)

      {:ok, lv, _html} = live(admin_conn, ~p"/admin/riders/#{rider}/edit")
      lv |> form("#rider-form", rider_profile: %{hidden_by_staff: "true"}) |> render_submit()

      assert_raise Ecto.NoResultsError, fn -> live(build_conn(), ~p"/community/#{rider.slug}") end

      {:ok, _lv, html} =
        lv
        |> element("#rider-delete button", "Delete rider")
        |> render_click()
        |> follow_redirect(admin_conn)

      assert html =~ "Vanish deleted."
      refute PevSquad.Repo.get(PevSquad.Riders.RiderProfile, rider.id)
    end

    test "staff approve a pending profile from the dashboard", %{conn: conn} do
      staff = staff_scope_fixture()
      member = user_scope_fixture()
      member_email = member.user.email
      {:ok, profile} = PevSquad.Riders.save_my_profile(member, %{alias: "Fresh", is_public: true})
      conn = log_in_user(conn, staff.user)

      {:ok, lv, html} = live(conn, ~p"/admin")
      assert html =~ "1 PENDING"

      {:ok, lv, _html} =
        lv |> element("a", "Riders") |> render_click() |> follow_redirect(conn)

      assert lv |> element("#riders", "Fresh") |> has_element?()
      assert lv |> element("#rider-status-filter .active", "Pending (1)") |> has_element?()

      {:ok, lv, _html} = live(conn, ~p"/admin/riders/#{profile}/edit")
      assert render(lv |> element("#rider-approval button", "Approve")) =~ "Approve"
      lv |> element("#rider-approval button", "Approve") |> render_click()

      assert render(lv) =~ "Fresh approved."
      refute has_element?(lv, "#rider-approval")
      assert_received {:email, %{subject: "You're in the Squad, Fresh", to: [{_, ^member_email}]}}

      {:ok, _lv, html} = live(build_conn(), ~p"/community")
      assert html =~ "Fresh"
    end

    test "members can't add riders", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/riders/new")
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
