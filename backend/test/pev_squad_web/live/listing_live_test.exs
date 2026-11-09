defmodule PevSquadWeb.ListingLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.ListingsFixtures
  import PevSquad.RidersFixtures

  alias PevSquad.Listings

  test "the board shows live and recently sold listings, with a category filter", %{conn: conn} do
    seller = host_scope_fixture("Wheelie")
    live_listing_fixture(seller, %{"title" => "Inmotion V11"})
    live_listing_fixture(seller, %{"title" => "Leaperkim Helmet", "category" => "gear"})
    {:ok, _} = Listings.mark_sold(seller, live_listing_fixture(seller, %{"title" => "KS S22"}))
    listing_fixture(seller, %{"title" => "Pending Thing"})

    {:ok, lv, html} = live(conn, ~p"/for-sale")
    assert html =~ "Inmotion V11"
    assert html =~ "Rp 18.500.000"
    assert html =~ "Wheelie"
    assert html =~ "Recently sold"
    assert html =~ "KS S22"
    refute html =~ "Pending Thing"

    html = lv |> element("a.filter-tag", "Safety gear") |> render_click()
    assert html =~ "Leaperkim Helmet"
    refute html =~ "Inmotion V11"
  end

  test "contact details are only shown to logged-in members", %{conn: conn} do
    listing = live_listing_fixture(host_scope_fixture(), %{"instagram" => "seller.one"})

    {:ok, _lv, html} = live(conn, ~p"/for-sale/#{listing.id}")
    assert html =~ "Log in to see how to contact the seller"
    refute html =~ "wa.me"
    refute html =~ "seller.one"

    {:ok, _lv, html} = live(log_in_user(conn, user_fixture()), ~p"/for-sale/#{listing.id}")
    assert html =~ "https://wa.me/6281234567890?text="
    assert html =~ "https://ig.me/m/seller.one"
  end

  test "pending listings are hidden from everyone but the seller and staff", %{conn: conn} do
    seller = host_scope_fixture()
    listing = listing_fixture(seller)

    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/for-sale/#{listing.id}") end

    {:ok, _lv, html} = live(log_in_user(conn, seller.user), ~p"/for-sale/#{listing.id}")
    assert html =~ "Waiting for review"
  end

  test "members without an active profile can't sell", %{conn: conn} do
    {:ok, _lv, html} = live(log_in_user(conn, user_fixture()), ~p"/for-sale/new")
    assert html =~ "Set up your rider profile first"
    refute html =~ "listing-form"
  end

  test "a member submits a listing with photos", %{conn: conn} do
    staff_scope_fixture()
    seller = host_scope_fixture()
    conn = log_in_user(conn, seller.user)

    {:ok, lv, _html} = live(conn, ~p"/for-sale/new")

    upload =
      file_input(lv, "#listing-form", :photos, [
        %{name: "wheel.jpg", content: File.read!(image_fixture()), type: "image/jpeg"}
      ])

    render_upload(upload, "wheel.jpg")

    {:ok, _lv, html} =
      lv
      |> form("#listing-form", listing: listing_attrs() |> Map.drop(["km"]))
      |> render_submit()
      |> follow_redirect(conn)

    assert html =~ "A moderator will check your listing"
    assert [listing] = Listings.list_pending(staff_scope_fixture())
    assert listing.price_idr == 18_500_000
    assert [_photo] = listing.photos
  end

  test "submitting without a photo asks for one", %{conn: conn} do
    seller = host_scope_fixture()
    {:ok, lv, _html} = live(log_in_user(conn, seller.user), ~p"/for-sale/new")

    html = lv |> form("#listing-form", listing: listing_attrs()) |> render_submit()
    assert html =~ "Add at least one photo"
  end

  test "sellers check in, mark sold, hide and delete from My listings", %{conn: conn} do
    seller = host_scope_fixture()
    listing = seller |> live_listing_fixture() |> age_listing(8)

    {:ok, lv, html} = live(log_in_user(conn, seller.user), ~p"/for-sale/mine")
    assert html =~ "Expired"

    html = lv |> element("#my-listing-#{listing.id} button", "Still available") |> render_click()
    assert html =~ "stays on the board for another 7 days"
    assert [_] = Listings.list_live_listings()

    html = lv |> element("#my-listing-#{listing.id} button", "Mark sold") |> render_click()
    assert html =~ "Marked sold"
    assert [_] = Listings.list_recently_sold()

    html =
      lv |> element("#my-listing-#{listing.id} button", "Not sold after all") |> render_click()

    assert html =~ "back on the board"

    html = lv |> element("#my-listing-#{listing.id} button", "Hide") |> render_click()
    assert html =~ "Only you can see it"
    assert Listings.list_live_listings() == []

    html = lv |> element("#my-listing-#{listing.id} button", "Delete") |> render_click()
    assert html =~ "Listing deleted"
    refute has_element?(lv, "#my-listing-#{listing.id}")
  end

  test "staff approve and send back from the listing queue", %{conn: conn} do
    seller = host_scope_fixture()
    good = listing_fixture(seller, %{"title" => "Good Wheel"})
    bad = listing_fixture(seller, %{"title" => "Blurry Wheel"})

    {:ok, lv, html} = live(log_in_user(conn, staff_scope_fixture().user), ~p"/admin/listings")
    assert html =~ "2 waiting"

    lv |> element("#pending-#{good.id} button", "Approve") |> render_click()

    html =
      lv
      |> form("#reject-#{bad.id}", reason: "Photos are too blurry")
      |> render_submit()

    assert html =~ "All clear"
    assert [%{title: "Good Wheel"}] = Listings.list_live_listings()
    assert Listings.get_my_listing!(seller, bad.id).rejection_reason == "Photos are too blurry"
  end

  test "the admin dashboard counts waiting listings", %{conn: conn} do
    listing_fixture(host_scope_fixture())
    {:ok, _lv, html} = live(log_in_user(conn, staff_scope_fixture().user), ~p"/admin")
    assert html =~ "Listing Queue"
    assert html =~ "1 WAITING"
  end
end
