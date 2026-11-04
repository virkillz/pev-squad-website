defmodule PevSquad.GalleryFixtures do
  @moduledoc "Test helpers for albums and photos."

  import PevSquad.EventsFixtures
  import PevSquad.RidersFixtures

  alias PevSquad.Gallery

  def album_fixture(attrs \\ %{}) do
    {:ok, album} =
      Gallery.create_album(
        staff_scope_fixture(),
        Enum.into(attrs, %{
          "title" => "Night Session #{System.unique_integer([:positive])}",
          "subtitle" => "Level P10, after hours",
          "published" => "true"
        })
      )

    album
  end

  def photo_fixture(album, attrs \\ %{}) do
    {:ok, photo} =
      Gallery.upload_photo(staff_scope_fixture(), album, image_fixture(1200, 800), attrs)

    photo
  end
end
