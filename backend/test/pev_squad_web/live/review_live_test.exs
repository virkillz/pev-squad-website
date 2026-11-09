defmodule PevSquadWeb.ReviewLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.ReviewsFixtures

  alias PevSquad.{Reviews, Riders}

  defp with_profile(%{conn: conn}) do
    user = user_fixture()
    scope = PevSquad.Accounts.Scope.for_user(user)
    {:ok, _} = PevSquad.RidersFixtures.approved_profile(scope, %{"alias" => "Jarz"})
    %{conn: log_in_user(conn, user), scope: scope}
  end

  defp published_review(model) do
    scope = user_scope_fixture()

    {:ok, _} =
      PevSquad.RidersFixtures.approved_profile(scope, %{
        "alias" => "Rev#{System.unique_integer([:positive])}"
      })

    {:ok, review} = Reviews.create_review(scope, review_attrs(%{"pev_model_id" => model.id}))
    {:ok, review} = Reviews.approve_review(staff_scope_fixture(), review, fn _ -> "x" end)
    review
  end

  test "index shows the sheet and cards, filterable", %{conn: conn} do
    euc = model_fixture(%{"brand" => "Inmotion", "name" => "V13"})

    scooter =
      model_fixture(%{"pev_type" => "escooter", "brand" => "Dualtron", "name" => "Thunder 3"})

    published_review(euc)
    published_review(scooter)

    {:ok, lv, html} = live(conn, ~p"/reviews")
    assert html =~ "Inmotion V13"
    assert html =~ "Dualtron Thunder 3"
    assert html =~ "8.6"

    html = lv |> element(".filter-tag", "Scooter") |> render_click()
    assert html =~ "Dualtron Thunder 3"
    refute html =~ "Inmotion V13"
  end

  test "review and model pages", %{conn: conn} do
    model = model_fixture(%{"brand" => "Kingsong", "name" => "S22 Pro"})
    review = published_review(model)

    {:ok, _lv, html} = live(conn, ~p"/reviews/#{review.id}")
    assert html =~ "Most planted wheel"
    assert html =~ "Overall: 8.6 / 10"
    assert html =~ "2,100 km on unit"

    {:ok, _lv, html} = live(conn, ~p"/models/#{model.slug}")
    assert html =~ "Kingsong S22 Pro"
    assert html =~ "Most planted wheel" or html =~ "Planted at speed"
  end

  test "writing a review needs a rider profile", %{conn: conn} do
    conn = log_in_user(conn, user_fixture())

    assert {:error, {:live_redirect, %{to: "/users/profile"}}} = live(conn, ~p"/reviews/new")
  end

  describe "writing" do
    setup :with_profile

    test "submits a review for moderation", %{conn: conn} do
      model = model_fixture(%{"brand" => "Veteran", "name" => "Lynx"})
      {:ok, lv, html} = live(conn, ~p"/reviews/new?model=#{model.slug}")
      assert html =~ "Submit for review"

      {:ok, _lv, html} =
        lv
        |> form("#review-form", review: review_attrs())
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "A moderator will check it shortly"
      assert html =~ "Waiting for a moderator"
    end

    test "can add a missing model inline", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/reviews/new")

      html =
        lv
        |> form("#review-form", review: %{"pev_model_id" => "__new__"})
        |> render_change()

      assert html =~ "Add it to the catalog"

      {:ok, _lv, html} =
        lv
        |> form("#review-form",
          review: Map.put(review_attrs(), "pev_model_id", "__new__"),
          new_model: %{"pev_type" => "euc", "brand" => "Begode", "name" => "Blitz"}
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Begode Blitz"
    end
  end

  describe "moderation" do
    test "staff approve from the queue", %{conn: conn} do
      scope = user_scope_fixture()
      {:ok, _} = PevSquad.RidersFixtures.approved_profile(scope, %{"alias" => "Nanda"})
      model = model_fixture()
      {:ok, review} = Reviews.create_review(scope, review_attrs(%{"pev_model_id" => model.id}))

      staff = staff_scope_fixture()
      {:ok, lv, html} = live(log_in_user(conn, staff.user), ~p"/admin/reviews")
      assert html =~ "Most planted wheel"

      html = lv |> element("#review-#{review.id} button", "Approve") |> render_click()
      assert html =~ "All clear"
      assert Reviews.get_review!(nil, review.id).status == :published
    end

    test "staff send a review back with a reason", %{conn: conn} do
      scope = user_scope_fixture()
      {:ok, _} = PevSquad.RidersFixtures.approved_profile(scope, %{"alias" => "Ed"})

      {:ok, review} =
        Reviews.create_review(scope, review_attrs(%{"pev_model_id" => model_fixture().id}))

      {:ok, lv, _html} = live(log_in_user(conn, staff_scope_fixture().user), ~p"/admin/reviews")

      lv
      |> form("#reject-#{review.id}", reason: "Tell us about range in the rain.")
      |> render_submit()

      assert Reviews.get_review!(scope, review.id).status == :rejected
    end

    test "staff see the Admin link; members don't", %{conn: conn} do
      {:ok, _lv, html} = live(log_in_user(conn, staff_scope_fixture().user), ~p"/")
      assert html =~ ~s(href="/admin")

      {:ok, _lv, html} = live(log_in_user(build_conn(), user_fixture()), ~p"/")
      refute html =~ ~s(href="/admin")
    end
  end
end
