defmodule PevSquad.ReviewsTest do
  use PevSquad.DataCase

  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.ReviewsFixtures

  alias PevSquad.{Reviews, Riders}
  alias PevSquad.Reviews.Score

  defp url(review), do: "http://localhost/reviews/#{review.id}"

  # A member with a rider profile (reviews are shown under the alias).
  defp rider_scope(opts \\ []) do
    scope = user_scope_fixture()

    {:ok, profile} =
      Riders.save_my_profile(scope, %{"alias" => "R#{System.unique_integer([:positive])}"})

    if opts[:featured], do: {:ok, _} = Riders.set_featured(staff_scope_fixture(), profile, true)
    scope
  end

  defp publish!(scope, model, attrs \\ %{}) do
    {:ok, review} =
      Reviews.create_review(scope, review_attrs(Map.put(attrs, "pev_model_id", model.id)))

    if review.status == :published do
      review
    else
      {:ok, review} = Reviews.approve_review(staff_scope_fixture(), review, &url/1)
      review
    end
  end

  test "Score casts decimals and stores tenths" do
    assert Score.cast("9.4") == {:ok, 9.4}
    assert Score.cast("8,75") == {:ok, 8.8}
    assert Score.cast(10) == {:ok, 10.0}
    assert {:error, _} = Score.cast("11")
    assert Score.dump(9.4) == {:ok, 94}
    assert Score.load(94) == {:ok, 9.4}
  end

  describe "create_review/3" do
    test "needs a rider profile" do
      model = model_fixture()

      assert {:error, :no_profile} =
               Reviews.create_review(
                 user_scope_fixture(),
                 review_attrs(%{"pev_model_id" => model.id})
               )
    end

    test "new members' reviews wait for moderation; overall is the average" do
      model = model_fixture()

      {:ok, review} =
        Reviews.create_review(rider_scope(), review_attrs(%{"pev_model_id" => model.id}))

      assert review.status == :pending
      assert review.overall == 8.6
      assert Reviews.list_published_reviews() == []
    end

    test "App/FW is optional but counts when given" do
      model = model_fixture()

      {:ok, review} =
        Reviews.create_review(
          rider_scope(),
          review_attrs(%{"pev_model_id" => model.id, "score_app" => "6.0"})
        )

      assert review.overall == 8.2
    end

    test "one review per model per member" do
      scope = rider_scope()
      model = model_fixture()
      {:ok, _} = Reviews.create_review(scope, review_attrs(%{"pev_model_id" => model.id}))

      assert {:error, changeset} =
               Reviews.create_review(scope, review_attrs(%{"pev_model_id" => model.id}))

      assert errors_on(changeset).pev_model_id |> hd() =~ "already reviewed"
    end

    test "can add a missing model, which stays pending" do
      scope = rider_scope()

      {:ok, review} =
        Reviews.create_review(scope, review_attrs(), %{
          "pev_type" => "escooter",
          "brand" => "Dualtron",
          "name" => "Thunder 3"
        })

      assert review.status == :pending
      refute review.pev_model.approved
      assert review.pev_model.slug == "dualtron-thunder-3"
      assert [_] = Reviews.list_selectable_models(scope)
      assert Reviews.list_selectable_models(user_scope_fixture()) == []
    end

    test "trusted members (2+ published reviews) publish straight away" do
      scope = rider_scope()
      publish!(scope, model_fixture())
      publish!(scope, model_fixture())

      {:ok, third} =
        Reviews.create_review(scope, review_attrs(%{"pev_model_id" => model_fixture().id}))

      assert third.status == :published
      assert third.published_at
    end
  end

  describe "moderation" do
    test "approve publishes, approves the model and emails the author" do
      scope = rider_scope()

      {:ok, review} =
        Reviews.create_review(scope, review_attrs(), %{
          "pev_type" => "euc",
          "brand" => "Begode",
          "name" => "Master Pro"
        })

      staff = staff_scope_fixture()
      assert [_] = Reviews.list_pending_reviews(staff)
      {:ok, review} = Reviews.approve_review(staff, review, &url/1)

      assert review.status == :published
      assert review.pev_model.approved
      assert review.moderated_by_id == staff.user.id
      assert_received {:email, %{subject: "Your Begode Master Pro review is live"}}
    end

    test "reject needs a reason, emails it, and an edit resubmits" do
      scope = rider_scope()
      model = model_fixture()
      {:ok, review} = Reviews.create_review(scope, review_attrs(%{"pev_model_id" => model.id}))
      staff = staff_scope_fixture()

      assert {:error, _} = Reviews.reject_review(staff, review, "  ", &url/1)
      {:ok, rejected} = Reviews.reject_review(staff, review, "Add some detail on range.", &url/1)
      assert rejected.status == :rejected
      assert_received {:email, %{subject: "Your " <> _, text_body: body}}
      assert body =~ "Add some detail on range."

      {:ok, resubmitted} =
        Reviews.update_review(scope, rejected, %{"the_ride" => "Longer ride notes."})

      assert resubmitted.status == :pending
      assert is_nil(resubmitted.rejection_reason)
    end

    test "members can't moderate" do
      assert_raise PevSquad.Reviews.NotAuthorizedError, fn ->
        Reviews.list_pending_reviews(user_scope_fixture())
      end
    end

    test "only authors and staff see unpublished reviews" do
      scope = rider_scope()

      {:ok, review} =
        Reviews.create_review(scope, review_attrs(%{"pev_model_id" => model_fixture().id}))

      assert Reviews.get_review!(scope, review.id).id == review.id
      assert Reviews.get_review!(staff_scope_fixture(), review.id)
      assert_raise Ecto.NoResultsError, fn -> Reviews.get_review!(nil, review.id) end

      assert_raise Ecto.NoResultsError, fn ->
        Reviews.get_review!(user_scope_fixture(), review.id)
      end
    end
  end

  describe "sheet/1" do
    test "ranks models by weighted overall, Featured reviews counting double" do
      wheel = model_fixture(%{"brand" => "Inmotion", "name" => "V13"})

      scooter =
        model_fixture(%{"pev_type" => "escooter", "brand" => "Kaabo", "name" => "Wolf 11"})

      # Inmotion: featured 9.0 (x2) + community 6.0 -> (180 + 60) / 3 = 8.0
      publish!(rider_scope(featured: true), wheel, %{
        "score_power" => "9",
        "score_range" => "9",
        "score_comfort" => "9",
        "score_build" => "9",
        "score_value" => "9"
      })

      publish!(rider_scope(), wheel, %{
        "score_power" => "6",
        "score_range" => "6",
        "score_comfort" => "6",
        "score_build" => "6",
        "score_value" => "6"
      })

      # Kaabo: one community review averaging 8.6
      publish!(rider_scope(), scooter)

      assert [first, second] = Reviews.sheet()
      assert {first.model.id, first.overall} == {scooter.id, 8.6}
      assert second.model.id == wheel.id
      assert second.overall == 8.0
      assert second.featured_avg == 9.0
      assert second.community_avg == 6.0
      assert second.reviews == 2

      assert [%{model: %{id: id}}] = Reviews.sheet(type: :escooter)
      assert id == scooter.id

      wheel_id = wheel.id
      assert [%{model: %{id: ^wheel_id}, overall: 9.0}] = Reviews.sheet(featured: true)
    end
  end
end
