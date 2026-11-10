defmodule PevSquad.EventMediaTest do
  @moduledoc "Event images, and the albums shown with events and posts."
  use PevSquad.DataCase, async: true

  import PevSquad.EventsFixtures
  import PevSquad.GalleryFixtures
  import PevSquad.PostsFixtures
  import PevSquad.RidersFixtures, only: [image_fixture: 2]

  alias PevSquad.{Events, Gallery, Uploads}

  describe "event images" do
    test "set_cover stores a WebP and replaces the old file" do
      scope = staff_scope_fixture()
      event = event_fixture()

      {:ok, event} = Events.set_cover(scope, event, image_fixture(1200, 800))
      assert event.cover_path =~ ~r{^/uploads/events/.+\.webp$}
      first = Uploads.path(String.trim_leading(event.cover_path, "/uploads/"))
      assert File.exists?(first)

      {:ok, event} = Events.set_cover(scope, event, image_fixture(800, 1000))
      refute File.exists?(first)

      {:ok, event} = Events.remove_cover(scope, event)
      assert event.cover_path == nil
    end

    test "set_cover refuses a file that isn't an image" do
      text = Path.join(System.tmp_dir!(), "not-an-image-#{System.unique_integer()}.jpg")
      File.write!(text, "hello")

      assert {:error, :bad_image} = Events.set_cover(staff_scope_fixture(), event_fixture(), text)
    end

    test "deleting an event removes its image" do
      scope = staff_scope_fixture()
      {:ok, event} = Events.set_cover(scope, event_fixture(), image_fixture(600, 400))
      file = Uploads.path(String.trim_leading(event.cover_path, "/uploads/"))

      {:ok, _} = Events.delete_event(scope, event)
      refute File.exists?(file)
    end

    test "only staff can set an image" do
      assert_raise PevSquad.Events.NotAuthorizedError, fn ->
        Events.set_cover(
          PevSquad.AccountsFixtures.user_scope_fixture(),
          event_fixture(),
          image_fixture(10, 10)
        )
      end
    end
  end

  describe "event albums" do
    test "set_event_albums links, moves and unlinks" do
      scope = staff_scope_fixture()
      event = event_fixture()
      other = event_fixture()
      a = album_fixture()
      b = album_fixture(%{"event_id" => other.id})
      c = album_fixture(%{"event_id" => event.id})

      assert {:ok, ids} = Gallery.set_event_albums(scope, event, [a.id, b.id])
      assert Enum.sort(ids) == Enum.sort([a.id, b.id])
      # b moved over from the other event; c was unlinked.
      assert Gallery.list_event_album_ids(other) == []
      assert Repo.reload!(c).event_id == nil
    end

    test "only published albums with live photos are shown" do
      event = event_fixture()
      shown = album_fixture(%{"event_id" => event.id})
      photo_fixture(shown)
      _empty = album_fixture(%{"event_id" => event.id})
      draft = album_fixture(%{"event_id" => event.id, "published" => "false"})
      photo_fixture(draft)

      assert [album] = Gallery.list_event_albums(event)
      assert album.id == shown.id
      assert album.photo_count == 1
      assert [_preview] = album.photos
    end
  end

  describe "album_for_post/2" do
    test "a post's own album wins over its event's" do
      event = event_fixture()
      event_album = album_fixture(%{"event_id" => event.id})
      photo_fixture(event_album)
      own = album_fixture()
      photo_fixture(own)

      assert Gallery.album_for_post(post_fixture(%{event_id: event.id, album_id: own.id})).id ==
               own.id

      assert Gallery.album_for_post(post_fixture(%{event_id: event.id})).id == event_album.id
      assert Gallery.album_for_post(post_fixture()) == nil
    end

    test "an unpublished album isn't shown" do
      draft = album_fixture(%{"published" => "false"})
      photo_fixture(draft)

      assert Gallery.album_for_post(post_fixture(%{album_id: draft.id})) == nil
    end
  end
end
