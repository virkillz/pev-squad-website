defmodule PevSquad.RiderOfTheDayTest do
  use PevSquad.DataCase, async: true

  import PevSquad.EventsFixtures, only: [staff_scope_fixture: 0]
  import PevSquad.RidersFixtures, only: [rider_fixture: 1]

  alias PevSquad.Riders
  alias PevSquad.Riders.Spotlight

  # Eligible: listed, active, with a photo and a bio.
  defp eligible(alias_name, attrs \\ %{}) do
    rider_fixture(Map.merge(%{alias: alias_name, bio: "Rides every weekend."}, attrs))
    |> Ecto.Changeset.change(
      avatar_path: "/uploads/avatars/#{System.unique_integer([:positive])}.webp"
    )
    |> Repo.update!()
  end

  defp pick(date), do: Riders.rider_of_the_day(date: date)

  test "nobody qualifies: nil, and nothing is saved" do
    rider_fixture(alias: "No Photo", bio: "Has a bio")
    assert pick(~D[2026-11-10]) == nil
    assert Repo.aggregate(Spotlight, :count) == 0
  end

  test "the pick is saved and stays the same all day" do
    for n <- 1..5, do: eligible("Rider #{n}")

    first = pick(~D[2026-11-10])
    assert first

    for _ <- 1..5, do: assert(pick(~D[2026-11-10]).id == first.id)
    assert Repo.aggregate(Spotlight, :count) == 1
  end

  test "everyone gets a turn before anyone repeats" do
    riders = for n <- 1..4, do: eligible("Turn #{n}")

    picked = for day <- 1..4, do: pick(Date.add(~D[2026-11-01], day)).id
    assert Enum.sort(picked) == riders |> Enum.map(& &1.id) |> Enum.sort()

    # Day 5 starts the next round with whoever was featured longest ago.
    assert pick(~D[2026-11-06]).id == hd(picked)
  end

  test "a new rider goes before anyone already featured" do
    eligible("Old Hand")
    _ = pick(~D[2026-11-01])
    newcomer = eligible("Newcomer")

    assert pick(~D[2026-11-02]).id == newcomer.id
  end

  test "riders without a photo or bio, private, hidden or inactive aren't picked" do
    rider_fixture(alias: "No Photo", bio: "Bio")
    eligible("Blank Bio", %{bio: "  "})
    eligible("Private", %{is_public: false})

    eligible("Hidden") |> Ecto.Changeset.change(hidden_by_staff: true) |> Repo.update!()
    eligible("Retired") |> Ecto.Changeset.change(status: :inactive) |> Repo.update!()

    assert pick(~D[2026-11-10]) == nil
  end

  test "a rider who drops off the roster mid-day is replaced" do
    a = eligible("First")
    b = eligible("Second")
    today = ~D[2026-11-10]

    picked = pick(today)
    other = if picked.id == a.id, do: b, else: a

    picked
    |> Ecto.Changeset.change(
      status: :banned,
      banned_at: DateTime.utc_now(:second),
      ban_reason: "x"
    )
    |> Repo.update!()

    assert pick(today).id == other.id
    assert Repo.aggregate(Spotlight, :count) == 1
  end

  test "a viewer who blocked today's rider sees nobody" do
    member = PevSquad.AccountsFixtures.user_fixture()
    rider = eligible("Blocked One") |> Ecto.Changeset.change(user_id: member.id) |> Repo.update!()

    assert Riders.rider_of_the_day(date: ~D[2026-11-10]).id == rider.id

    assert Riders.rider_of_the_day(date: ~D[2026-11-10], exclude_users: [member.id]) == nil
  end

  test "staff can replace today's pick with any listed rider, photo or not" do
    staff = staff_scope_fixture()
    eligible("Auto Pick")
    _ = pick(Riders.today())
    chosen = rider_fixture(alias: "Staff Choice")

    assert {:ok, %{picked_by_id: by}} = Riders.set_rider_of_the_day(staff, chosen)
    assert by == staff.user.id
    assert Riders.rider_of_the_day().id == chosen.id
    assert Riders.spotlight_dates(chosen) == [Riders.today()]

    private = rider_fixture(alias: "Not Listed", is_public: false)
    assert {:error, :not_listed} = Riders.set_rider_of_the_day(staff, private)
  end
end
