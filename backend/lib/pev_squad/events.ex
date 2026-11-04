defmodule PevSquad.Events do
  @moduledoc """
  Rides, tours and meetups, plus RSVPs.

  RSVPs are first come, first served: while an event has free seats an RSVP
  is `:going`, after that it is `:waitlist`. When a going rider cancels, the
  earliest waitlisted rider is promoted. Seat checks run inside a transaction
  holding a row lock on the event, so two riders can never take the last seat.
  """

  import Ecto.Query, warn: false

  alias PevSquad.Accounts.Scope
  alias PevSquad.Events.{Event, Notifier, Rsvp}
  alias PevSquad.Repo

  ## PubSub

  @doc "Subscribe to RSVP changes for one event."
  def subscribe(%Event{id: id}), do: Phoenix.PubSub.subscribe(PevSquad.PubSub, topic(id))

  defp broadcast_rsvps_changed(%Event{id: id}) do
    Phoenix.PubSub.broadcast(PevSquad.PubSub, topic(id), {:rsvps_changed, id})
  end

  defp topic(event_id), do: "event:#{event_id}"

  ## Public listings

  @doc """
  Published events that haven't finished yet, soonest first.
  """
  def list_upcoming_events(now \\ DateTime.utc_now()) do
    published()
    |> where([e], coalesce(e.ends_at, e.starts_at) >= ^now)
    |> order_by([e], asc: e.starts_at)
    |> with_counts()
    |> Repo.all()
  end

  @doc """
  Published events that have finished, most recent first.
  """
  def list_past_events(now \\ DateTime.utc_now()) do
    published()
    |> where([e], coalesce(e.ends_at, e.starts_at) < ^now)
    |> order_by([e], desc: e.starts_at)
    |> Repo.all()
  end

  @doc "The next published event, for the home page. Returns nil if none."
  def next_event(now \\ DateTime.utc_now()) do
    published()
    |> where([e], e.starts_at >= ^now)
    |> order_by([e], asc: e.starts_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Fetches a published (or cancelled) event by slug, with seat counts.
  Drafts are only visible to staff.
  """
  def get_public_event!(scope, slug) do
    visible = if Scope.staff?(scope), do: Event.statuses(), else: [:published, :cancelled]

    Event
    |> where([e], e.slug == ^slug and e.status in ^visible)
    |> with_counts()
    |> Repo.one!()
  end

  @doc "Reloads seat counts for an event (after a PubSub notification)."
  def reload_counts(%Event{id: id} = event) do
    %{going_count: going, waitlist_count: waitlist} =
      Event |> where(id: ^id) |> with_counts() |> Repo.one!()

    %{event | going_count: going, waitlist_count: waitlist}
  end

  defp published, do: where(Event, [e], e.status == :published)

  defp with_counts(query) do
    counts =
      from r in Rsvp,
        group_by: r.event_id,
        select: %{
          event_id: r.event_id,
          going: filter(count(r.id), r.status == :going),
          waitlist: filter(count(r.id), r.status == :waitlist)
        }

    from e in query,
      left_join: c in subquery(counts),
      on: c.event_id == e.id,
      select_merge: %{
        going_count: coalesce(c.going, 0),
        waitlist_count: coalesce(c.waitlist, 0)
      }
  end

  ## Staff management

  @doc "All events for the admin list, newest first."
  def list_events_for_staff(%Scope{} = scope) do
    ensure_staff!(scope)

    Event
    |> order_by([e], desc: e.starts_at)
    |> with_counts()
    |> Repo.all()
  end

  def get_event!(%Scope{} = scope, id) do
    ensure_staff!(scope)
    Event |> where(id: ^id) |> with_counts() |> Repo.one!()
  end

  def create_event(%Scope{} = scope, attrs) do
    ensure_staff!(scope)

    %Event{created_by_id: scope.user.id}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an event. If the capacity went up (or was removed), waitlisted
  riders are promoted into the new seats in RSVP order and emailed.
  """
  def update_event(%Scope{} = scope, %Event{} = event, attrs, event_url_fun \\ nil) do
    ensure_staff!(scope)

    result =
      Repo.transact(fn ->
        _locked = lock_event!(event.id)

        with {:ok, updated} <- event |> Event.changeset(attrs) |> Repo.update() do
          {:ok, {updated, fill_open_seats(updated, [])}}
        end
      end)

    with {:ok, {updated, promoted}} <- result do
      if promoted != [], do: broadcast_rsvps_changed(updated)
      notify_promoted(promoted, updated, event_url_fun)
      {:ok, updated}
    end
  end

  defp fill_open_seats(event, acc) do
    case promote_next(event) do
      nil -> Enum.reverse(acc)
      rsvp -> fill_open_seats(event, [rsvp | acc])
    end
  end

  defp notify_promoted(_promoted, _event, nil), do: :ok

  defp notify_promoted(promoted, event, event_url_fun) do
    for rsvp <- Repo.preload(promoted, :user) do
      Notifier.deliver_waitlist_promotion(rsvp.user, event, event_url_fun.(event))
    end

    :ok
  end

  def delete_event(%Scope{} = scope, %Event{} = event) do
    ensure_staff!(scope)
    Repo.delete(event)
  end

  def change_event(%Event{} = event, attrs \\ %{}), do: Event.changeset(event, attrs)

  @doc "Going riders first (in RSVP order), then the waitlist. Staff only."
  def list_rsvps(%Scope{} = scope, %Event{id: event_id}) do
    ensure_staff!(scope)

    Rsvp
    |> where(event_id: ^event_id)
    |> order_by([r], asc: r.status, asc: r.inserted_at, asc: r.id)
    |> preload(:user)
    |> Repo.all()
  end

  defp ensure_staff!(scope) do
    unless Scope.staff?(scope), do: raise(PevSquad.Events.NotAuthorizedError)
  end

  ## RSVPs

  @doc "The current user's RSVP for an event, or nil."
  def get_rsvp(nil, _event), do: nil

  def get_rsvp(%Scope{user: user}, %Event{id: event_id}) do
    Repo.get_by(Rsvp, event_id: event_id, user_id: user.id)
  end

  @doc "1-based waitlist position for a waitlisted RSVP, nil otherwise."
  def waitlist_position(%Rsvp{status: :waitlist} = rsvp) do
    ahead =
      Rsvp
      |> where(event_id: ^rsvp.event_id, status: :waitlist)
      |> where(
        [r],
        r.inserted_at < ^rsvp.inserted_at or
          (r.inserted_at == ^rsvp.inserted_at and r.id < ^rsvp.id)
      )
      |> Repo.aggregate(:count)

    ahead + 1
  end

  def waitlist_position(_rsvp), do: nil

  @doc """
  Whether the event currently accepts RSVPs: published, not started, and
  before the RSVP deadline if one is set.
  """
  def rsvp_open?(%Event{} = event, now \\ DateTime.utc_now()) do
    event.status == :published and
      DateTime.compare(now, event.starts_at) == :lt and
      (is_nil(event.rsvp_deadline) or DateTime.compare(now, event.rsvp_deadline) == :lt)
  end

  def seats_left(%Event{capacity: nil}), do: nil
  def seats_left(%Event{capacity: cap, going_count: going}), do: max(cap - going, 0)

  @doc """
  RSVPs the current user. Returns `{:ok, rsvp}` with status `:going` or
  `:waitlist`, or `{:error, :closed}`. RSVPing twice returns the existing RSVP.
  """
  def rsvp(%Scope{user: user}, %Event{id: event_id}) do
    result =
      Repo.transact(fn ->
        event = lock_event!(event_id)

        cond do
          rsvp = Repo.get_by(Rsvp, event_id: event.id, user_id: user.id) ->
            {:ok, {rsvp, :unchanged}}

          not rsvp_open?(event) ->
            {:error, :closed}

          true ->
            status = if seat_available?(event), do: :going, else: :waitlist

            %Rsvp{event_id: event.id, user_id: user.id, status: status}
            |> Repo.insert()
            |> case do
              {:ok, rsvp} -> {:ok, {rsvp, :created}}
              error -> error
            end
        end
      end)

    case result do
      {:ok, {rsvp, :created}} ->
        broadcast_rsvps_changed(%Event{id: event_id})
        {:ok, rsvp}

      {:ok, {rsvp, :unchanged}} ->
        {:ok, rsvp}

      error ->
        error
    end
  end

  @doc """
  Cancels the current user's RSVP. If they held a seat, the earliest
  waitlisted rider takes it and is emailed. Returns `{:ok, promoted}` where
  `promoted` is the promoted RSVP or nil.

  `event_url_fun` builds the link for the promotion email.
  """
  def cancel_rsvp(%Scope{user: user}, %Event{id: event_id}, event_url_fun) do
    result =
      Repo.transact(fn ->
        event = lock_event!(event_id)

        case Repo.get_by(Rsvp, event_id: event.id, user_id: user.id) do
          nil ->
            {:ok, {event, nil, false}}

          %Rsvp{status: status} = rsvp ->
            Repo.delete!(rsvp)
            promoted = if status == :going, do: promote_next(event)
            {:ok, {event, promoted, true}}
        end
      end)

    case result do
      {:ok, {event, promoted, changed?}} ->
        if changed?, do: broadcast_rsvps_changed(event)

        if promoted, do: notify_promoted([promoted], event, event_url_fun)

        {:ok, promoted}

      error ->
        error
    end
  end

  # Must be called inside the transaction that holds the event lock.
  defp promote_next(%Event{} = event) do
    if seat_available?(event) do
      Rsvp
      |> where(event_id: ^event.id, status: :waitlist)
      |> order_by([r], asc: r.inserted_at, asc: r.id)
      |> limit(1)
      |> Repo.one()
      |> case do
        nil -> nil
        next -> next |> Ecto.Changeset.change(status: :going) |> Repo.update!()
      end
    end
  end

  defp lock_event!(event_id) do
    Event |> where(id: ^event_id) |> lock("FOR UPDATE") |> Repo.one!()
  end

  defp seat_available?(%Event{capacity: nil}), do: true
  defp seat_available?(%Event{capacity: cap, id: id}), do: going_count(id) < cap

  defp going_count(event_id) do
    Rsvp |> where(event_id: ^event_id, status: :going) |> Repo.aggregate(:count)
  end
end

defmodule PevSquad.Events.NotAuthorizedError do
  defexception message: "only moderators and admins can manage events", plug_status: 403
end
