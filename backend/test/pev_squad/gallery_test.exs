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

  describe "featured photos" do
    test "only live photos in published albums, most recently featured first" do
      staff = staff_scope_fixture()
      album = album_fixture()
      draft = album_fixture(%{"published" => "false"})

      first = photo_fixture(album, %{"title" => "First"})
      second = photo_fixture(album, %{"title" => "Second"})
      _plain = photo_fixture(album)
      in_draft = photo_fixture(draft)

      {:ok, first} = Gallery.update_photo(staff, first, %{"featured" => "true"})
      assert first.featured_at

      # Featured a second later, so it leads the carousel.
      {:ok, second} = Gallery.update_photo(staff, second, %{"featured" => "true"})

      {:ok, second} =
        second
        |> Ecto.Changeset.change(featured_at: DateTime.add(first.featured_at, 1))
        |> Repo.update()

      {:ok, _} = Gallery.update_photo(staff, in_draft, %{"featured" => "true"})

      assert [%{id: a, album: %{id: album_id}}, %{id: b}] = Gallery.list_featured_photos()
      assert {a, b} == {second.id, first.id}
      assert album_id == album.id

      assert [_] = Gallery.list_featured_photos(limit: 1)

      {:ok, unfeatured} = Gallery.update_photo(staff, first, %{"featured" => "false"})
      assert is_nil(unfeatured.featured_at)
      assert [%{id: ^a}] = Gallery.list_featured_photos()
    end

    test "re-saving other fields keeps the featured time" do
      staff = staff_scope_fixture()

      {:ok, photo} =
        Gallery.update_photo(staff, photo_fixture(album_fixture()), %{"featured" => "true"})

      {:ok, again} =
        Gallery.update_photo(staff, photo, %{"featured" => "true", "title" => "Renamed"})

      assert again.featured_at == photo.featured_at
    end

    test "members can't feature photos" do
      photo = photo_fixture(album_fixture())

      assert_raise PevSquad.Gallery.NotAuthorizedError, fn ->
        Gallery.update_photo(user_scope_fixture(), photo, %{"featured" => "true"})
      end
    end
  end

  describe "move_photo/3" do
    test "moves a photo to the end of another album, keeping its state" do
      staff = staff_scope_fixture()
      from = album_fixture()
      to = album_fixture()
      _existing = photo_fixture(to)
      photo = photo_fixture(from)
      {:ok, photo} = Gallery.update_photo(staff, photo, %{"featured" => "true"})

      assert {:ok, moved} = Gallery.move_photo(staff, photo, to.id)
      assert moved.album_id == to.id
      assert moved.featured
      assert moved.status == :published

      assert [_, %{id: last_id}] = Gallery.get_published_album!(to.slug).photos
      assert last_id == photo.id
      assert Gallery.get_published_album!(from.slug).photos == []
    end

    test "refuses unknown and same albums, and members" do
      staff = staff_scope_fixture()
      album = album_fixture()
      photo = photo_fixture(album)

      assert {:error, :same_album} = Gallery.move_photo(staff, photo, album.id)
      assert {:error, :not_found} = Gallery.move_photo(staff, photo, -1)

      assert_raise PevSquad.Gallery.NotAuthorizedError, fn ->
        Gallery.move_photo(user_scope_fixture(), photo, album_fixture().id)
      end
    end
  end
end
