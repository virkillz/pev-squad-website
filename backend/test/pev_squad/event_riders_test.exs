defmodule PevSquad.EventRidersTest do
  @moduledoc "Staff editing an event's rider list, including riders without an account."
  use PevSquad.DataCase, async: true

  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.RidersFixtures, only: [rider_fixture: 1]

  alias PevSquad.{Accounts, Events, Riders}
  alias PevSquad.Accounts.Scope

  defp url(event), do: "https://x/events/#{event.slug}"
  defp aliases(scope, event), do: scope |> Events.list_rsvps(event) |> Enum.map(& &1.rider_alias)

  test "staff add riders with and without an account, over capacity and to past events" do
    staff = staff_scope_fixture()

    event =
      event_fixture(capacity: 1, starts_at: DateTime.add(DateTime.utc_now(:second), -2, :day))

    imported = rider_fixture(alias: "Imported Rider")
    member = host_scope_fixture("Member Rider")
    member_profile = Riders.get_my_profile(member)

    assert {:ok, %{rider_profile_id: id, user_id: nil, status: :going}} =
             Events.add_rider(staff, event, imported, :going)

    assert id == imported.id

    # A claimed profile is added under the member's account.
    assert {:ok, %{user_id: user_id, rider_profile_id: nil, status: :going}} =
             Events.add_rider(staff, event, member_profile, :going)

    assert user_id == member.user.id
    assert Events.get_rsvp(member, event).status == :going

    assert {:error, :already_listed} = Events.add_rider(staff, event, imported, :waitlist)
    assert Enum.sort(aliases(staff, event)) == ["Imported Rider", "Member Rider"]
    assert Events.reload_event(event).going_count == 2
  end

  test "moving between going and the waitlist promotes nobody" do
    staff = staff_scope_fixture()
    event = event_fixture(capacity: 1)
    {:ok, seat} = Events.rsvp(user_scope_fixture(), event)
    {:ok, waiting} = Events.rsvp(user_scope_fixture(), event)

    {:ok, %{status: :waitlist}} = Events.set_rsvp_status(staff, seat, :waitlist)
    assert Repo.reload!(waiting).status == :waitlist

    {:ok, %{status: :going}} = Events.set_rsvp_status(staff, waiting, :going)
    {:ok, %{status: :going}} = Events.set_rsvp_status(staff, seat, :going)
    assert Events.reload_event(event).going_count == 2
  end

  test "removing a seat on an upcoming event moves the waitlist up and emails" do
    staff = staff_scope_fixture()
    event = event_fixture(capacity: 1)
    {:ok, seat} = Events.add_rider(staff, event, rider_fixture(alias: "No Account"), :going)
    waiting = user_scope_fixture()
    email = waiting.user.email
    {:ok, %{status: :waitlist}} = Events.rsvp(waiting, event)

    assert {:ok, %{status: :going}} = Events.remove_rsvp(staff, seat, &url/1)
    assert Events.get_rsvp(waiting, event).status == :going
    assert_received {:email, %{subject: "You're in: " <> _, to: [{_, ^email}]}}
  end

  test "a promoted rider without an account isn't emailed" do
    staff = staff_scope_fixture()
    event = event_fixture(capacity: 1)
    {:ok, seat} = Events.rsvp(user_scope_fixture(), event)
    {:ok, _} = Events.add_rider(staff, event, rider_fixture(alias: "Waiting"), :waitlist)

    assert {:ok, %{status: :going, user_id: nil}} = Events.remove_rsvp(staff, seat, &url/1)
    refute_received {:email, %{subject: "You're in: " <> _}}
  end

  test "removing from a past event promotes nobody" do
    staff = staff_scope_fixture()

    event =
      event_fixture(capacity: 1, starts_at: DateTime.add(DateTime.utc_now(:second), -1, :day))

    {:ok, seat} = Events.add_rider(staff, event, rider_fixture(alias: "Rider A"), :going)
    {:ok, waiting} = Events.add_rider(staff, event, rider_fixture(alias: "Rider B"), :waitlist)

    assert {:ok, nil} = Events.remove_rsvp(staff, seat, &url/1)
    assert Repo.reload!(waiting).status == :waitlist
  end

  test "claiming a profile moves its RSVPs to the member, keeping their own" do
    staff = staff_scope_fixture()
    rider = rider_fixture(alias: "Claimed Later")
    member = user_scope_fixture()
    only_staff = event_fixture()
    both = event_fixture()

    {:ok, _} = Events.add_rider(staff, only_staff, rider, :going)
    {:ok, _} = Events.add_rider(staff, both, rider, :waitlist)
    {:ok, %{status: :going}} = Events.rsvp(member, both)

    {:ok, _} = Riders.link_to_member(staff_scope_fixture(:admin), rider, member.user.email)

    assert Events.get_rsvp(member, only_staff).status == :going
    assert Events.get_rsvp(member, both).status == :going
    assert aliases(staff, both) == ["Claimed Later"]
  end

  test "deleting an account that keeps its imported profile keeps past events on the profile" do
    admin = staff_scope_fixture(:admin)
    member = user_fixture()
    rider = rider_fixture(alias: "Veteran")
    {:ok, _} = Riders.link_to_member(admin, rider, member.email)
    past = event_fixture(starts_at: DateTime.add(DateTime.utc_now(:second), -3, :day))
    {:ok, _} = Events.add_rider(admin, past, Repo.reload!(rider), :going)

    {:ok, _} = Accounts.delete_member(admin, member, &url/1, "x")

    assert [%{rider_alias: "Veteran", user: nil}] = Events.list_rsvps(admin, past)
  end

  test "group ride cancellation skips riders without an account" do
    host = host_scope_fixture()
    ride = group_ride_fixture(host)

    {:ok, _} =
      Events.add_rider(staff_scope_fixture(), ride, rider_fixture(alias: "Quiet"), :going)

    assert {:ok, _} = Events.cancel_event(host, ride, &url/1)
  end

  test "only staff edit the list" do
    member = Scope.for_user(user_fixture())
    event = event_fixture()
    rider = rider_fixture(alias: "Not Staff")

    assert_raise PevSquad.Events.NotAuthorizedError, fn ->
      Events.add_rider(member, event, rider, :going)
    end
  end

  test "search finds riders by alias and leaves out banned ones" do
    staff = staff_scope_fixture()
    rider_fixture(alias: "Searchable Sam")

    rider_fixture(alias: "Searchable Banned")
    |> Ecto.Changeset.change(status: :banned)
    |> Repo.update!()

    assert [%{alias: "Searchable Sam"}] = Riders.search_riders_for_staff(staff, "searchable")
    assert Riders.search_riders_for_staff(staff, "  ") == []
  end
end
