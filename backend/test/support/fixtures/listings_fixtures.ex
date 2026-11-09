defmodule PevSquad.ListingsFixtures do
  @moduledoc "Test helpers for For Sale listings."

  import PevSquad.RidersFixtures, only: [image_fixture: 0]

  alias PevSquad.Listings

  def listing_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      "title" => "Inmotion V11",
      "category" => "euc",
      "condition" => "used",
      "price_idr" => "18.500.000",
      "quantity" => "1",
      "city" => "Jakarta Selatan",
      "km" => "2.400",
      "description" => "Battery healthy, new tyre, comes with charger.",
      "whatsapp" => "0812 3456 7890"
    })
  end

  @doc "A pending listing with one photo, posted by `scope`."
  def listing_fixture(scope, attrs \\ %{}) do
    {:ok, listing} = Listings.create_listing(scope, listing_attrs(attrs), [image_fixture()])
    listing
  end

  @doc "An approved, live listing."
  def live_listing_fixture(scope, attrs \\ %{}) do
    {:ok, listing} =
      Listings.approve(
        PevSquad.EventsFixtures.staff_scope_fixture(),
        listing_fixture(scope, attrs),
        fn _ -> "http://localhost/for-sale" end
      )

    listing
  end

  @doc "Moves a listing's timestamps `days` into the past."
  def age_listing(listing, days) do
    shift = fn
      nil -> nil
      at -> DateTime.add(at, -days, :day)
    end

    listing
    |> Ecto.Changeset.change(
      approved_at: shift.(listing.approved_at),
      last_checked_at: shift.(listing.last_checked_at),
      sold_at: shift.(listing.sold_at)
    )
    |> PevSquad.Repo.update!()
  end
end
