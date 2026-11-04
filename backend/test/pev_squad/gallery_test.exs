defmodule PevSquad.GalleryTest do
  use PevSquad.DataCase

  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.GalleryFixtures
  import PevSquad.RidersFixtures

  alias PevSquad.{Gallery, Riders, Uploads}

  defp member_with_profile do
    scope = user_scope_fixture()

    {:ok, _} =
      Riders.save_my_profile(scope, %{"alias" => "Snap#{System.unique_integer([:positive])}"})

    scope
  end

  defp file_for(url), do: Uploads.path(String.trim_leading(url, "/uploads/"))

  test "processing writes a 2048px large and an 800px thumb as WebP" do
    photo = photo_fixture(album_fixture())

    assert photo.large_path =~ ~r{^/uploads/gallery/.+\.webp$}
    assert photo.thumb_path =~ ~r{-t\.webp$}
    # 1200x800 source is never upscaled
    assert {photo.width, photo.height} == {1200, 800}
    {:ok, thumb} = Image.open(file_for(photo.thumb_path))
    assert Image.width(thumb) == 800
  end

  describe "upload_photo/4" do
    test "members' photos wait for moderation; staff photos go live" do
      album = album_fixture()
      staff_photo = photo_fixture(album)
      assert staff_photo.status == :published

      {:ok, member_photo} =
        Gallery.upload_photo(member_with_profile(), album, image_fixture(), %{
          "title" => "Lean In"
        })

      assert member_photo.status == :pending
      assert member_photo.title == "Lean In"
      assert member_photo.position == staff_photo.position + 1

      album = Gallery.get_published_album!(album.slug)
      assert Enum.map(album.photos, & &1.id) == [staff_photo.id]
    end

    test "members become trusted after 3 approved photos" do
      album = album_fixture()
      scope = member_with_profile()
      staff = staff_scope_fixture()

      for _ <- 1..3 do
        {:ok, photo} = Gallery.upload_photo(scope, album, image_fixture())
        {:ok, _} = Gallery.approve_photo(staff, photo)
      end

      {:ok, fourth} = Gallery.upload_photo(scope, album, image_fixture())
      assert fourth.status == :published
    end

    test "needs a rider profile, an open album, and a readable image" do
      album = album_fixture()

      assert {:error, :no_profile} =
               Gallery.upload_photo(user_scope_fixture(), album, image_fixture())

      closed = album_fixture(%{"open_for_uploads" => "false"})

      assert {:error, :closed} =
               Gallery.upload_photo(member_with_profile(), closed, image_fixture())

      bogus = Path.join(System.tmp_dir!(), "not-an-image.jpg")
      File.write!(bogus, "nope")
      assert {:error, :unreadable} = Gallery.upload_photo(member_with_profile(), album, bogus)
    end
  end

  test "rejecting deletes the photo and its files" do
    album = album_fixture()
    {:ok, photo} = Gallery.upload_photo(member_with_profile(), album, image_fixture())
    staff = staff_scope_fixture()

    assert [_] = Gallery.list_pending_photos(staff)
    {:ok, _} = Gallery.reject_photo(staff, photo)

    assert Gallery.list_pending_photos(staff) == []
    refute File.exists?(file_for(photo.large_path))
    refute File.exists?(file_for(photo.thumb_path))
  end

  test "list_published_albums/1 previews photos and hides drafts and empty albums" do
    album = album_fixture()
    for _ <- 1..3, do: photo_fixture(album)
    _draft = album_fixture(%{"published" => "false"}) |> photo_fixture()
    _empty = album_fixture()

    assert [listed] = Gallery.list_published_albums(preview: 2)
    assert listed.id == album.id
    assert listed.photo_count == 3
    assert length(listed.photos) == 2
  end

  test "members can delete their own photos, not others'" do
    album = album_fixture()
    owner = member_with_profile()
    {:ok, photo} = Gallery.upload_photo(owner, album, image_fixture())

    assert {:error, :not_allowed} = Gallery.delete_photo(member_with_profile(), photo)
    assert {:ok, _} = Gallery.delete_photo(owner, photo)
  end
end
