defmodule PevSquad.ListingsTest do
  use PevSquad.DataCase

  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.ListingsFixtures
  import PevSquad.RidersFixtures

  alias PevSquad.{Listings, Riders}
  alias PevSquad.Listings.Listing

  defp url(_), do: "http://localhost/x"

  describe "who can sell" do
    test "only members with an active rider profile, and staff" do
      assert Listings.can_sell?(nil) == {:error, :no_profile}

      scope = user_scope_fixture()
      assert Listings.can_sell?(scope) == {:error, :no_profile}

      {:ok, _} = Riders.save_my_profile(scope, %{alias: "Newbie", primary_pev_type: :euc})
      assert Listings.can_sell?(scope) == {:error, :pending}

      profile = Riders.get_my_profile(scope)
      {:ok, _} = Riders.approve_rider(staff_scope_fixture(), profile)
      assert Listings.can_sell?(scope) == :ok

      {:ok, _} =
        Riders.update_rider(staff_scope_fixture(), Riders.get_my_profile(scope), %{
          status: :inactive
        })

      assert Listings.can_sell?(scope) == {:error, :inactive}
      assert {:error, :inactive} = Listings.create_listing(scope, listing_attrs(), [])

      assert Listings.can_sell?(staff_scope_fixture()) == :ok
    end
  end

  describe "creating" do
    test "starts pending, cleans up price and phone, and emails the moderators" do
      staff_scope_fixture()
      seller = host_scope_fixture()

      {:ok, listing} =
        Listings.create_listing(seller, listing_attrs(), [image_fixture()], review_url: &url/1)

      assert listing.status == :pending
      assert listing.price_idr == 18_500_000
      assert listing.km == 2400
      assert listing.whatsapp == "6281234567890"
      assert [%{thumb_path: "/uploads/listings/" <> _}] = listing.photos
      assert Listings.state(listing) == :pending
      assert_received {:email, %{subject: "Listing waiting for approval: Inmotion V11"}}
    end

    test "needs at least one photo and a way to reach the seller" do
      seller = host_scope_fixture()

      assert {:error, changeset} = Listings.create_listing(seller, listing_attrs(), [])
      assert changeset.errors[:photos]

      assert {:error, changeset} =
               Listings.create_listing(seller, listing_attrs(%{"whatsapp" => ""}), [
                 image_fixture()
               ])

      assert changeset.errors[:whatsapp]

      {:ok, listing} =
        Listings.create_listing(
          seller,
          listing_attrs(%{"whatsapp" => "", "instagram" => "@rider.one"}),
          [image_fixture()]
        )

      assert listing.instagram == "rider.one"
    end

    test "takes at most five photos" do
      sources = for _ <- 1..6, do: image_fixture()

      assert {:error, changeset} =
               Listings.create_listing(host_scope_fixture(), listing_attrs(), sources)

      assert changeset.errors[:photos]
    end
  end

  describe "moderation" do
    test "approving starts the clock and emails the seller" do
      seller = host_scope_fixture()
      listing = listing_fixture(seller)

      {:ok, listing} = Listings.approve(staff_scope_fixture(), listing, &url/1)

      assert listing.status == :approved
      assert listing.last_checked_at
      assert Listings.state(listing) == :live
      assert [%{id: id}] = Listings.list_live_listings()
      assert id == listing.id
      assert_received {:email, %{subject: "Your listing is live: Inmotion V11"}}
    end

    test "rejecting needs a reason; editing a rejected listing resubmits it" do
      seller = host_scope_fixture()
      listing = listing_fixture(seller)
      staff = staff_scope_fixture()

      assert {:error, :reason_required} = Listings.reject(staff, listing, " ", &url/1)
      {:ok, listing} = Listings.reject(staff, listing, "Show the battery", &url/1)
      assert Listings.state(listing) == :rejected
      assert_received {:email, %{subject: "Your listing needs changes: Inmotion V11"}}

      kept = Enum.map(listing.photos, & &1.large_path)

      {:ok, listing} =
        Listings.update_listing(seller, listing, %{"price_idr" => "17000000"}, kept, [])

      assert listing.status == :pending
      assert listing.rejection_reason == nil
    end

    test "price changes stay live; description changes go back to the queue" do
      seller = host_scope_fixture()
      listing = live_listing_fixture(seller)
      kept = Enum.map(listing.photos, & &1.large_path)

      {:ok, listing} =
        Listings.update_listing(seller, listing, %{"price_idr" => "17.000.000"}, kept, [])

      assert listing.status == :approved
      assert listing.price_idr == 17_000_000

      {:ok, listing} =
        Listings.update_listing(seller, listing, %{"description" => "Now with a stand"}, kept, [])

      assert listing.status == :pending
    end

    test "removing a photo counts as a reviewed change" do
      seller = host_scope_fixture()

      {:ok, listing} =
        Listings.create_listing(seller, listing_attrs(), [image_fixture(), image_fixture()])

      {:ok, listing} = Listings.approve(staff_scope_fixture(), listing, &url/1)
      [first, second] = listing.photos

      {:ok, listing} = Listings.update_listing(seller, listing, %{}, [first.large_path], [])
      assert listing.status == :pending
      assert length(listing.photos) == 1

      refute File.exists?(
               PevSquad.Uploads.path(String.trim_leading(second.large_path, "/uploads/"))
             )
    end

    test "other members can't change someone's listing" do
      listing = live_listing_fixture(host_scope_fixture())

      assert_raise PevSquad.Listings.NotAuthorizedError, fn ->
        Listings.mark_sold(host_scope_fixture(), listing)
      end
    end
  end

  describe "decay" do
    test "a listing not checked in for 7 days drops off the board; checking in brings it back" do
      seller = host_scope_fixture()
      listing = seller |> live_listing_fixture() |> age_listing(8)

      assert Listings.state(listing) == :expired
      assert Listings.list_live_listings() == []

      {:ok, listing} = Listings.check_in(seller, listing)
      assert listing.status == :approved
      assert Listings.state(listing) == :live
      assert [_] = Listings.list_live_listings()
    end

    test "after a month off the board, checking in sends it back to review" do
      seller = host_scope_fixture()
      listing = seller |> live_listing_fixture() |> age_listing(40)

      {:ok, listing} = Listings.check_in(seller, listing)
      assert listing.status == :pending
    end

    test "sellers get one reminder two days before a listing lapses" do
      seller = host_scope_fixture()
      listing = seller |> live_listing_fixture() |> age_listing(6)
      _fresh = live_listing_fixture(host_scope_fixture())

      assert Listings.send_reminders("http://localhost/for-sale/mine") == 1
      assert_received {:email, %{subject: "Is your Inmotion V11 still available?"}}
      assert Listings.send_reminders("http://localhost/for-sale/mine") == 0

      # Checking in re-arms the reminder for the next cycle.
      {:ok, listing} = Listings.check_in(seller, Repo.reload!(listing))
      later = DateTime.add(listing.last_checked_at, 6, :day)
      assert Listings.send_reminders("http://localhost/for-sale/mine", later) == 1
    end
  end

  describe "sold, hidden, deleted" do
    test "sold listings stay on the board for 7 days" do
      seller = host_scope_fixture()
      {:ok, listing} = Listings.mark_sold(seller, live_listing_fixture(seller))

      assert Listings.state(listing) == :sold
      assert Listings.list_live_listings() == []
      assert [_] = Listings.list_recently_sold()

      listing = age_listing(listing, 8)
      assert Listings.state(listing) == :sold_archived
      assert Listings.list_recently_sold() == []
      assert {:error, :not_allowed} = Listings.check_in(seller, listing)

      {:ok, listing} = Listings.unmark_sold(seller, listing)
      assert Listings.state(listing) == :live
    end

    test "hidden and deleted listings leave the board" do
      seller = host_scope_fixture()
      listing = live_listing_fixture(seller)

      {:ok, listing} = Listings.hide(seller, listing)
      assert Listings.state(listing) == :hidden
      assert Listings.list_live_listings() == []

      assert_raise Ecto.NoResultsError, fn ->
        Listings.get_public_listing!(nil, listing.id)
      end

      # The seller still sees it.
      assert Listings.get_public_listing!(seller, listing.id)

      {:ok, listing} = Listings.unhide(seller, listing)
      assert [_] = Listings.list_live_listings()

      {:ok, _} = Listings.delete_listing(seller, listing)
      assert Listings.list_live_listings() == []
      assert Listings.list_my_listings(seller) == []
      assert Repo.get!(Listing, listing.id).deleted_at
    end

    test "listings from banned sellers and blocked members are left out" do
      seller = host_scope_fixture()
      listing = live_listing_fixture(seller)
      viewer = user_scope_fixture()

      {:ok, _} = PevSquad.Safety.block(viewer, seller.user.id)

      assert Listings.list_live_listings(exclude_users: PevSquad.Safety.hidden_user_ids(viewer)) ==
               []

      {:ok, _} =
        Riders.update_rider(staff_scope_fixture(), Riders.get_my_profile(seller), %{
          status: :banned,
          ban_reason: "Scam"
        })

      assert Listings.list_live_listings() == []

      assert_raise Ecto.NoResultsError, fn ->
        Listings.get_public_listing!(nil, listing.id)
      end
    end
  end
end
