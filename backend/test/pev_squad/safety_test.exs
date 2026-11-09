defmodule PevSquad.SafetyTest do
  use PevSquad.DataCase

  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.GalleryFixtures
  import PevSquad.ReviewsFixtures
  import PevSquad.RidersFixtures

  alias PevSquad.{Gallery, Reviews, Riders, Safety}

  defp member do
    scope = user_scope_fixture()

    {:ok, profile} =
      Riders.save_my_profile(scope, %{
        "alias" => "M#{System.unique_integer([:positive])}",
        "is_public" => "true"
      })

    {scope, profile}
  end

  defp published_review_by(scope) do
    {:ok, review} =
      Reviews.create_review(scope, review_attrs(%{"pev_model_id" => model_fixture().id}))

    {:ok, review} = Reviews.approve_review(staff_scope_fixture(), review, fn _ -> "x" end)
    review
  end

  describe "report/4" do
    test "files a report with the content owner recorded" do
      {author, _} = member()
      review = published_review_by(author)

      assert {:ok, report} =
               Safety.report(user_scope_fixture(), :review, review.id, %{"reason" => "spam"})

      assert report.target_user_id == author.user.id
      assert report.status == :open
    end

    test "one open report per member per item; can't report your own" do
      {author, _} = member()
      review = published_review_by(author)
      reporter = user_scope_fixture()

      {:ok, _} = Safety.report(reporter, :review, review.id, %{"reason" => "spam"})

      assert {:error, changeset} =
               Safety.report(reporter, :review, review.id, %{"reason" => "other"})

      assert errors_on(changeset).reason |> hd() =~ "already reported"

      assert {:error, :own_content} =
               Safety.report(author, :review, review.id, %{"reason" => "spam"})

      assert {:error, :not_found} = Safety.report(reporter, :review, -1, %{"reason" => "spam"})
    end

    test "three different reporters hide a photo until staff decide" do
      album = album_fixture()
      photo = photo_fixture(album)

      for _ <- 1..2,
          do:
            {:ok, _} =
              Safety.report(user_scope_fixture(), :photo, photo.id, %{"reason" => "offensive"})

      assert [_] = Gallery.get_published_album!(album.slug).photos

      {:ok, _} = Safety.report(user_scope_fixture(), :photo, photo.id, %{"reason" => "offensive"})
      assert Gallery.get_published_album!(album.slug).photos == []

      # Dismissing puts it back.
      {:ok, 3} = Safety.dismiss(staff_scope_fixture(), :photo, photo.id)
      assert [_] = Gallery.get_published_album!(album.slug).photos
    end

    test "profiles are never auto-hidden" do
      {_, profile} = member()

      for _ <- 1..3,
          do:
            {:ok, _} =
              Safety.report(user_scope_fixture(), :profile, profile.id, %{"reason" => "spam"})

      assert Riders.get_public_rider!(profile.slug)
    end
  end

  describe "remove_content/5" do
    test "a review is sent back to its author with the note" do
      {author, _} = member()
      review = published_review_by(author)

      {:ok, _} =
        Safety.report(user_scope_fixture(), :review, review.id, %{"reason" => "dangerous"})

      staff = staff_scope_fixture()

      {:ok, 1} =
        Safety.remove_content(
          staff,
          :review,
          review.id,
          "Please drop the highway speed bit.",
          fn _ -> "x" end
        )

      review = Reviews.get_review!(author, review.id)
      assert review.status == :rejected
      assert review.rejection_reason == "Please drop the highway speed bit."
      assert Safety.list_open_reports(staff) == []
    end

    test "a profile is hidden from the public site" do
      {author, profile} = member()

      {:ok, _} =
        Safety.report(user_scope_fixture(), :profile, profile.id, %{"reason" => "not_theirs"})

      {:ok, 1} = Safety.remove_content(staff_scope_fixture(), :profile, profile.id, nil, nil)

      assert_raise Ecto.NoResultsError, fn -> Riders.get_public_rider!(profile.slug) end

      # The member can't bring it back by re-ticking Public.
      {:ok, _} = Riders.save_my_profile(author, %{is_public: true})
      assert_raise Ecto.NoResultsError, fn -> Riders.get_public_rider!(profile.slug) end
    end
  end

  describe "blocking" do
    test "hides the blocked member's profile, reviews and photos" do
      {author, profile} = member()
      review = published_review_by(author)
      album = album_fixture()
      {:ok, photo} = Gallery.upload_photo(author, album, image_fixture())
      {:ok, _} = Gallery.approve_photo(staff_scope_fixture(), photo)

      viewer = user_scope_fixture()
      {:ok, _} = Safety.block(viewer, author.user.id)
      hidden = Safety.hidden_user_ids(viewer)

      refute Enum.any?(Riders.list_public_riders(exclude_users: hidden), &(&1.id == profile.id))

      refute Enum.any?(
               Reviews.list_published_reviews(exclude_users: hidden),
               &(&1.id == review.id)
             )

      assert Gallery.get_published_album!(album.slug, exclude_users: hidden).photos == []

      # Everyone else still sees it all.
      assert Enum.any?(Reviews.list_published_reviews(), &(&1.id == review.id))

      :ok = Safety.unblock(viewer, author.user.id)
      assert Safety.hidden_user_ids(viewer) == []
    end

    test "can't block yourself; blocking twice is harmless" do
      viewer = user_scope_fixture()
      other = user_fixture()

      assert {:error, :self} = Safety.block(viewer, viewer.user.id)
      {:ok, _} = Safety.block(viewer, other.id)
      {:ok, _} = Safety.block(viewer, other.id)
      assert [%{user_id: id}] = Safety.list_blocked(viewer)
      assert id == other.id
    end
  end

  test "members can't see the report queue" do
    assert_raise PevSquad.Safety.NotAuthorizedError, fn ->
      Safety.list_open_reports(user_scope_fixture())
    end
  end
end
