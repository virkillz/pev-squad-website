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
      Riders.save_my_profile(PevSquad.Accounts.Scope.for_user(user), %{"alias" => "Owlier"})

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
    {:ok, _} = Riders.save_my_profile(scope, %{"alias" => "Saini"})

    {:ok, photo} =
      Gallery.upload_photo(scope, album_fixture(), image_fixture(), %{"title" => "Lean"})

    {:ok, lv, html} = live(log_in_user(conn, staff_scope_fixture().user), ~p"/admin/photos")
    assert html =~ "Shot by Saini"

    html = lv |> element("#pending-#{photo.id} button", "Approve") |> render_click()
    assert html =~ "All clear"
  end
end
