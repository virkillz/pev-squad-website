defmodule PevSquad.GroupRidesTest do
  use PevSquad.DataCase

  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures

  alias PevSquad.Events
  alias PevSquad.Safety

  defp url(event), do: "http://localhost/events/#{event.slug}"

  describe "create_group_ride/2" do
    test "goes live immediately, hosted by the member" do
      host = host_scope_fixture("Kuntz")
      ride = group_ride_fixture(host)

      assert ride.category == :group_ride
      assert ride.status == :published
      assert ride.created_by_id == host.user.id
      assert ride.slug =~ ~r/^sunday-loop-[a-z0-9]+$/

      assert [%{id: id, host_alias: "Kuntz"}] = Events.list_upcoming_events()
      assert id == ride.id
    end

    test "two rides with the same title get different slugs" do
      host = host_scope_fixture()
      assert group_ride_fixture(host).slug != group_ride_fixture(host).slug
    end

    test "needs a rider profile" do
      assert {:error, :no_profile} =
               Events.create_group_ride(user_scope_fixture(), %{title: "x"})
    end

    test "a host can have at most 3 upcoming rides" do
      host = host_scope_fixture()
      for _ <- 1..3, do: group_ride_fixture(host)

      assert {:error, :limit} = Events.can_host?(host)
      assert {:error, :limit} = Events.create_group_ride(host, %{title: "Fourth"})
    end

    test "requires a capacity of at most 30 and a group-ride kind" do
      host = host_scope_fixture()

      {:error, changeset} =
        Events.create_group_ride(host, %{
          title: "Big Tour",
          kind: :expedition,
          capacity: 80,
          starts_at: DateTime.add(DateTime.utc_now(:second), 3, :day),
          location_name: "Bromo"
        })

      assert %{kind: [_], capacity: ["must be between 1 and 30"]} = errors_on(changeset)

      {:error, changeset} = Events.create_group_ride(host, %{title: "No seats"})
      assert "can't be blank" in errors_on(changeset).capacity
    end

    test "hosts can't set category, status or partners" do
      host = host_scope_fixture()
      ride = group_ride_fixture(host, %{status: :draft, category: :official, partners: "Acme"})

      assert ride.category == :group_ride
      assert ride.status == :published
      assert is_nil(ride.partners)
    end
  end

  describe "managing" do
    test "the host and staff can edit; other members can't" do
      host = host_scope_fixture()
      ride = group_ride_fixture(host)

      assert {:ok, %{title: "Renamed"}} = Events.update_event(host, ride, %{title: "Renamed"})
      assert {:ok, _} = Events.update_event(staff_scope_fixture(), ride, %{capacity: 12})

      assert_raise PevSquad.Events.NotAuthorizedError, fn ->
        Events.update_event(user_scope_fixture(), ride, %{title: "Mine now"})
      end

      assert_raise PevSquad.Events.NotAuthorizedError, fn ->
        Events.get_manageable_event!(host_scope_fixture(), ride.id)
      end
    end

    test "a host can't manage official events" do
      host = host_scope_fixture()
      event = event_fixture()

      refute Events.can_manage?(host, event)

      assert_raise PevSquad.Events.NotAuthorizedError, fn ->
        Events.update_event(host, event, %{title: "Mine"})
      end
    end

    test "the host sees riders by alias" do
      host = host_scope_fixture()
      ride = group_ride_fixture(host)
      rider = host_scope_fixture("Shaz")
      {:ok, _} = Events.rsvp(rider, ride)

      assert [%{rider_alias: "Shaz", status: :going}] = Events.list_rsvps(host, ride)
    end

    test "cancelling emails everyone who RSVP'd" do
      host = host_scope_fixture()
      ride = group_ride_fixture(host, %{capacity: 1})
      going = user_scope_fixture()
      waiting = user_scope_fixture()
      {:ok, _} = Events.rsvp(going, ride)
      {:ok, _} = Events.rsvp(waiting, ride)

      {:ok, cancelled} = Events.cancel_event(host, ride, &url/1)
      assert cancelled.status == :cancelled

      recipients =
        for _ <- 1..2 do
          assert_received {:email, %{subject: "Cancelled: Sunday Loop", to: [{_, to}]}}
          to
        end

      assert Enum.sort(recipients) == Enum.sort([going.user.email, waiting.user.email])

      refute Events.rsvp_open?(cancelled)
    end
  end

  describe "listing" do
    test "filters by category; next_event only shows official events" do
      ride =
        group_ride_fixture(host_scope_fixture(), %{
          starts_at: DateTime.add(DateTime.utc_now(:second), 1, :day)
        })

      official = event_fixture()

      assert [%{id: id}] = Events.list_upcoming_events(category: :group_ride)
      assert id == ride.id
      assert [%{id: ^id}] = Events.list_upcoming_events(category: :group_ride)
      assert Events.next_event().id == official.id
    end

    test "rides hosted by a blocked member are left out" do
      host = host_scope_fixture()
      _ride = group_ride_fixture(host)
      official = event_fixture()
      viewer = user_scope_fixture()
      {:ok, _} = Safety.block(viewer, host.user.id)

      assert [%{id: id}] =
               Events.list_upcoming_events(exclude_users: Safety.hidden_user_ids(viewer))

      assert id == official.id
    end
  end

  describe "reports" do
    test "three reporters hide a ride; dismissing restores it" do
      host = host_scope_fixture()
      ride = group_ride_fixture(host)

      for _ <- 1..3 do
        {:ok, _} = Safety.report(user_scope_fixture(), :event, ride.id, %{reason: :dangerous})
      end

      assert Events.reload_event(ride).status == :hidden
      assert Events.list_upcoming_events() == []

      # Still visible to the host and staff, not the public.
      assert Events.get_public_event!(host, ride.slug).status == :hidden
      assert Events.get_public_event!(staff_scope_fixture(), ride.slug)

      assert_raise Ecto.NoResultsError, fn ->
        Events.get_public_event!(user_scope_fixture(), ride.slug)
      end

      {:ok, 3} = Safety.dismiss(staff_scope_fixture(), :event, ride.id)
      assert Events.reload_event(ride).status == :published
    end

    test "official events can't be reported" do
      event = event_fixture()

      assert {:error, :not_found} =
               Safety.report(user_scope_fixture(), :event, event.id, %{reason: :spam})
    end

    test "removing takes the ride down" do
      ride = group_ride_fixture(host_scope_fixture())
      {:ok, _} = Safety.report(user_scope_fixture(), :event, ride.id, %{reason: :spam})

      {:ok, 1} = Safety.remove_content(staff_scope_fixture(), :event, ride.id, nil, & &1)
      assert Events.reload_event(ride).status == :hidden
    end
  end
end
