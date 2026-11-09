defmodule PevSquadWeb.GalleryLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.GalleryFixtures
  import PevSquad.RidersFixtures

  alias PevSquad.{Gallery, Riders}

  test "gallery and album pages show published photos with lightbox data", %{conn: conn} do
    album = album_fixture(%{"title" => "Bromo 2026"})
    photo_fixture(album, %{"title" => "Sunrise Crater", "caption" => "Cold air, thin light."})

    {:ok, _lv, html} = live(conn, ~p"/gallery")
    assert html =~ "Bromo 2026"
    assert html =~ "Sunrise Crater"
    assert html =~ ~s(phx-hook="Lightbox")

    {:ok, _lv, html} = live(conn, ~p"/gallery/#{album.slug}")
    assert html =~ ~s(data-desc="Cold air, thin light.")
    assert html =~ "Log in to add photos"
  end

  test "members upload photos for moderation", %{conn: conn} do
    user = user_fixture()

    {:ok, _} =
      PevSquad.RidersFixtures.approved_profile(PevSquad.Accounts.Scope.for_user(user), %{
        "alias" => "Owlier"
      })

    album = album_fixture()

    {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/gallery/#{album.slug}/upload")

    upload =
      file_input(lv, "#upload-form", :photos, [
        %{name: "a.jpg", content: File.read!(image_fixture()), type: "image/jpeg"}
      ])

    render_upload(upload, "a.jpg")

    {:ok, _lv, html} =
      lv |> form("#upload-form") |> render_submit() |> follow_redirect(conn)

    assert html =~ "sent to the moderators"
    assert [_] = Gallery.list_pending_photos(staff_scope_fixture())
  end

  test "staff approve from the photo queue", %{conn: conn} do
    scope = user_scope_fixture()
    {:ok, _} = PevSquad.RidersFixtures.approved_profile(scope, %{"alias" => "Saini"})

    {:ok, photo} =
      Gallery.upload_photo(scope, album_fixture(), image_fixture(), %{"title" => "Lean"})

    {:ok, lv, html} = live(log_in_user(conn, staff_scope_fixture().user), ~p"/admin/photos")
    assert html =~ "Shot by Saini"

    html = lv |> element("#pending-#{photo.id} button", "Approve") |> render_click()
    assert html =~ "All clear"
  end

  test "the home page shows featured photos as a carousel", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/")
    refute html =~ "featured-carousel"
    assert html =~ "/images/community.png"

    album = album_fixture(%{"title" => "Night Session"})
    staff = staff_scope_fixture()

    for title <- ["Level P10", "Ramp Exit"] do
      {:ok, _} =
        Gallery.update_photo(staff, photo_fixture(album, %{"title" => title}), %{
          "featured" => "true"
        })
    end

    {:ok, lv, html} = live(conn, ~p"/")
    assert has_element?(lv, "#featured-carousel .carousel-slide", "Level P10")
    assert has_element?(lv, "#featured-carousel .carousel-slide", "Ramp Exit")
    assert has_element?(lv, ~s|#featured-carousel a[href="/gallery/#{album.slug}"]|)
    assert has_element?(lv, ".carousel-count", "02")
    refute html =~ "/images/community.png"
  end

  test "staff feature a photo from the album editor", %{conn: conn} do
    staff = staff_scope_fixture()
    album = album_fixture()
    photo = photo_fixture(album)

    {:ok, lv, _html} = live(log_in_user(conn, staff.user), ~p"/admin/albums/#{album.id}/edit")

    lv
    |> form("#photo-#{photo.id}")
    |> render_change(%{"photo_id" => "#{photo.id}", "photo" => %{"featured" => "true"}})

    assert has_element?(lv, "#photo-#{photo.id}", "★ Featured")
    assert [%{id: id}] = Gallery.list_featured_photos()
    assert id == photo.id
  end

  test "staff move a photo to another album from the album editor", %{conn: conn} do
    staff = staff_scope_fixture()
    album = album_fixture()
    other = album_fixture(%{"title" => "Morning Ride"})
    photo = photo_fixture(album)

    {:ok, lv, _html} = live(log_in_user(conn, staff.user), ~p"/admin/albums/#{album.id}/edit")
    refute has_element?(lv, "#move-#{photo.id} option", album.title)

    html =
      lv
      |> form("#move-#{photo.id}")
      |> render_change(%{"photo_id" => "#{photo.id}", "album_id" => "#{other.id}"})

    assert html =~ "Photo moved to Morning Ride."
    refute has_element?(lv, "#photo-card-#{photo.id}")
    assert [%{id: id}] = Gallery.get_published_album!(other.slug).photos
    assert id == photo.id
  end
end
