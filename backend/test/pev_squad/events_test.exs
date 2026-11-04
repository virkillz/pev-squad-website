defmodule PevSquad.EventsTest do
  use PevSquad.DataCase

  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures

  alias PevSquad.Events

  defp url(event), do: "http://localhost/events/#{event.slug}"

  describe "listing" do
    test "splits upcoming and past, hiding drafts" do
      upcoming = event_fixture()
      past = event_fixture(starts_at: DateTime.add(DateTime.utc_now(:second), -3, :day))
      _draft = event_fixture(status: :draft)

      assert [%{id: id}] = Events.list_upcoming_events()
      assert id == upcoming.id
      assert [%{id: past_id}] = Events.list_past_events()
      assert past_id == past.id
    end

    test "drafts are only visible to staff" do
      draft = event_fixture(status: :draft)

      assert_raise Ecto.NoResultsError, fn -> Events.get_public_event!(nil, draft.slug) end

      assert_raise Ecto.NoResultsError, fn ->
        Events.get_public_event!(user_scope_fixture(), draft.slug)
      end

      assert Events.get_public_event!(staff_scope_fixture(), draft.slug).id == draft.id
    end
  end

  describe "rsvp/2 — first come, first served" do
    test "gives seats until capacity is reached, then waitlists" do
      event = event_fixture(capacity: 2)
      [a, b, c] = for _ <- 1..3, do: user_scope_fixture()

      assert {:ok, %{status: :going}} = Events.rsvp(a, event)
      assert {:ok, %{status: :going}} = Events.rsvp(b, event)
      assert {:ok, %{status: :waitlist} = rsvp_c} = Events.rsvp(c, event)
      assert Events.waitlist_position(rsvp_c) == 1

      event = Events.reload_event(event)
      assert {event.going_count, event.waitlist_count} == {2, 1}
      assert Events.seats_left(event) == 0
    end

    test "unlimited events never waitlist" do
      event = event_fixture()

      for _ <- 1..5 do
        assert {:ok, %{status: :going}} = Events.rsvp(user_scope_fixture(), event)
      end
    end

    test "RSVPing twice keeps the original RSVP" do
      event = event_fixture(capacity: 1)
      scope = user_scope_fixture()

      assert {:ok, first} = Events.rsvp(scope, event)
      assert {:ok, again} = Events.rsvp(scope, event)
      assert first.id == again.id
      assert Events.reload_event(event).going_count == 1
    end

    test "is closed after the deadline, for past events and for cancelled events" do
      scope = user_scope_fixture()
      soon = DateTime.add(DateTime.utc_now(:second), -1, :hour)

      deadline_passed = event_fixture(rsvp_deadline: soon)
      started = event_fixture(starts_at: soon)
      cancelled = event_fixture(status: :cancelled)

      assert {:error, :closed} = Events.rsvp(scope, deadline_passed)
      assert {:error, :closed} = Events.rsvp(scope, started)
      assert {:error, :closed} = Events.rsvp(scope, cancelled)
    end

    test "broadcasts to subscribers" do
      event = event_fixture()
      Events.subscribe(event)

      {:ok, _} = Events.rsvp(user_scope_fixture(), event)
      event_id = event.id
      assert_receive {:rsvps_changed, ^event_id}
    end
  end

  describe "cancel_rsvp/3" do
    test "promotes the earliest waitlisted rider and emails them" do
      event = event_fixture(capacity: 1)
      [a, b, c] = for _ <- 1..3, do: user_scope_fixture()

      {:ok, _} = Events.rsvp(a, event)
      {:ok, %{status: :waitlist}} = Events.rsvp(b, event)
      {:ok, %{status: :waitlist}} = Events.rsvp(c, event)

      assert {:ok, promoted} = Events.cancel_rsvp(a, event, &url/1)
      assert promoted.user_id == b.user.id
      assert promoted.status == :going

      b_email = b.user.email
      assert_received {:email, %{subject: "You're in: " <> _, to: [{_, ^b_email}]}}

      assert Events.get_rsvp(a, event) == nil
      assert Events.waitlist_position(Events.get_rsvp(c, event)) == 1
    end

    test "leaving the waitlist promotes nobody" do
      event = event_fixture(capacity: 1)
      [a, b] = for _ <- 1..2, do: user_scope_fixture()

      {:ok, _} = Events.rsvp(a, event)
      {:ok, _} = Events.rsvp(b, event)

      assert {:ok, nil} = Events.cancel_rsvp(b, event, &url/1)
      assert Events.get_rsvp(a, event).status == :going
      refute_received {:email, %{subject: "You're in: " <> _}}
    end

    test "is a no-op without an RSVP" do
      assert {:ok, nil} = Events.cancel_rsvp(user_scope_fixture(), event_fixture(), &url/1)
    end
  end

  describe "update_event/4" do
    test "raising capacity promotes waitlisted riders in order" do
      staff = staff_scope_fixture()
      event = event_fixture(capacity: 1)
      [a, b, c, d] = for _ <- 1..4, do: user_scope_fixture()

      for s <- [a, b, c, d], do: {:ok, _} = Events.rsvp(s, event)

      {:ok, _} = Events.update_event(staff, event, %{capacity: 3}, &url/1)

      assert Events.get_rsvp(b, event).status == :going
      assert Events.get_rsvp(c, event).status == :going
      assert Events.get_rsvp(d, event).status == :waitlist
    end

    test "members cannot manage events" do
      assert_raise PevSquad.Events.NotAuthorizedError, fn ->
        Events.create_event(user_scope_fixture(), %{title: "Nope"})
      end
    end
  end

  test "slugify/2 handles dashes and accents" do
    assert PevSquad.Events.Event.slugify("Sudirman–Thamrin Loop", ~U[2026-08-02 13:00:00Z]) ==
             "sudirman-thamrin-loop-2026"

    assert PevSquad.Events.Event.slugify("Café Ride", nil) == "cafe-ride"
  end
end
