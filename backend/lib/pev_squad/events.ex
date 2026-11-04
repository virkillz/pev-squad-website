defmodule PevSquad.Events do
  @moduledoc """
  Rides, tours and meetups, plus RSVPs.

  Events come in two categories. `:official` events are run by PEV Squad
  (as organizer or collaborator) and managed by staff. `:group_ride`s are
  hosted by members: any member with a rider profile can post one, it goes
  live immediately, and the host (or staff) manages it. Reports are the
  safety net — see `PevSquad.Safety`.

  RSVPs are first come, first served: while an event has free seats an RSVP
  is `:going`, after that it is `:waitlist`. When a going rider cancels, the
  earliest waitlisted rider is promoted. Seat checks run inside a transaction
  holding a row lock on the event, so two riders can never take the last seat.
  """

  import Ecto.Query, warn: false

  alias PevSquad.Accounts.Scope
  alias PevSquad.Events.{Event, Notifier, Rsvp}
  alias PevSquad.Repo
  alias PevSquad.Riders.RiderProfile

  @max_upcoming_per_host 3

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

  Options: `:category` (`:official` or `:group_ride`; both when nil),
  `:exclude_users` (group rides hosted by these users are left out — blocked
  members) and `:now`.
  """
  def list_upcoming_events(opts \\ []) do
    now = opts[:now] || DateTime.utc_now()

    published()
    |> where([e], coalesce(e.ends_at, e.starts_at) >= ^now)
    |> filter_category(opts[:category])
    |> exclude_hosts(opts[:exclude_users])
    |> order_by([e], asc: e.starts_at)
    |> with_counts()
    |> with_host()
    |> Repo.all()
  end

  @doc """
  Published events that have finished, most recent first. Takes the same
  options as `list_upcoming_events/1`.
  """
  def list_past_events(opts \\ []) do
    now = opts[:now] || DateTime.utc_now()

    published()
    |> where([e], coalesce(e.ends_at, e.starts_at) < ^now)
    |> filter_category(opts[:category])
    |> exclude_hosts(opts[:exclude_users])
    |> order_by([e], desc: e.starts_at)
    |> with_host()
    |> Repo.all()
  end

  @doc "Published events linked to a partner, most recent first, with seat counts."
  def list_partner_events(partner_id) do
    published()
    |> join(:inner, [e], ep in "event_partners", on: ep.event_id == e.id)
    |> where([e, ep], ep.partner_id == ^partner_id)
    |> order_by([e], desc: e.starts_at)
    |> with_counts()
    |> with_host()
    |> Repo.all()
  end

  defp filter_category(query, nil), do: query
  defp filter_category(query, category), do: where(query, [e], e.category == ^category)

  # Official events are never hidden by a block; group rides by that host are.
  defp exclude_hosts(query, ids) when ids in [nil, []], do: query

  defp exclude_hosts(query, ids) do
    where(
      query,
      [e],
      e.category == :official or is_nil(e.created_by_id) or e.created_by_id not in ^ids
    )
  end

  @doc "The next official event, for the home page. Returns nil if none."
  def next_event(now \\ DateTime.utc_now()) do
    published()
    |> where([e], e.category == :official and e.starts_at >= ^now)
    |> order_by([e], asc: e.starts_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Fetches a published (or cancelled) event by slug, with seat counts.
  Drafts are only visible to staff; a hidden group ride to staff and its host.
  """
  def get_public_event!(scope, slug) do
    event =
      Event
      |> where([e], e.slug == ^slug)
      |> with_counts()
      |> with_host()
      |> Repo.one!()

    if event.status in [:published, :cancelled] or Scope.staff?(scope) or
         (event.status == :hidden and host?(scope, event)) do
      event
    else
      raise Ecto.NoResultsError, queryable: Event
    end
  end

  @doc "Reloads an event and its seat counts (after a PubSub notification)."
  def reload_event(%Event{id: id}) do
    Event |> where(id: ^id) |> with_counts() |> with_host() |> Repo.one!()
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

  defp with_host(query) do
    from e in query,
      left_join: p in RiderProfile,
      on: p.user_id == e.created_by_id and e.category == :group_ride,
      select_merge: %{host_alias: p.alias, host_slug: p.slug}
  end

  ## Permissions

  @doc "Whether the scope's user hosts this group ride."
  def host?(nil, _event), do: false

  def host?(%Scope{user: user}, %Event{category: :group_ride, created_by_id: id}),
    do: id == user.id

  def host?(_scope, _event), do: false

  @doc "Staff manage every event; hosts manage their own group rides."
  def can_manage?(scope, %Event{} = event), do: Scope.staff?(scope) or host?(scope, event)

  defp ensure_can_manage!(scope, event) do
    unless can_manage?(scope, event), do: raise(PevSquad.Events.NotAuthorizedError)
  end

  ## Staff management

  @doc "All events for the admin list, newest first."
  def list_events_for_staff(%Scope{} = scope) do
    ensure_staff!(scope)

    Event
    |> order_by([e], desc: e.starts_at)
    |> with_counts()
    |> with_host()
    |> Repo.all()
  end

  def get_event!(%Scope{} = scope, id) do
    ensure_staff!(scope)
    Event |> where(id: ^id) |> with_counts() |> with_host() |> Repo.one!()
  end

  @doc "An event the scope may edit: any for staff, their own group rides for hosts."
  def get_manageable_event!(%Scope{} = scope, id) do
    event = Event |> where(id: ^id) |> with_counts() |> with_host() |> Repo.one!()
    ensure_can_manage!(scope, event)
    event
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
    ensure_can_manage!(scope, event)

    result =
      Repo.transact(fn ->
        _locked = lock_event!(event.id)

        with {:ok, updated} <- event |> change_event(attrs) |> Repo.update() do
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

  def change_event(event, attrs \\ %{})

  def change_event(%Event{category: :group_ride} = event, attrs),
    do: Event.group_ride_changeset(event, attrs)

  def change_event(%Event{} = event, attrs), do: Event.changeset(event, attrs)

  @doc "Going riders first (in RSVP order), then the waitlist. Staff and the host."
  def list_rsvps(%Scope{} = scope, %Event{id: event_id} = event) do
    ensure_can_manage!(scope, event)

    from(r in Rsvp,
      where: r.event_id == ^event_id,
      left_join: p in RiderProfile,
      on: p.user_id == r.user_id,
      order_by: [asc: r.status, asc: r.inserted_at, asc: r.id],
      select_merge: %{rider_alias: p.alias},
      preload: :user
    )
    |> Repo.all()
  end

  defp ensure_staff!(scope) do
    unless Scope.staff?(scope), do: raise(PevSquad.Events.NotAuthorizedError)
  end

  ## Group rides

  def max_upcoming_per_host, do: @max_upcoming_per_host

  @doc "A blank group ride for the host form."
  def new_group_ride, do: %Event{category: :group_ride, kind: :ride, status: :published}

  @doc """
  Whether the member can post another group ride. Returns `:ok`,
  `{:error, :no_profile}` (they need a rider profile so riders know who's
  hosting) or `{:error, :limit}` (already hosting the maximum upcoming rides).
  """
  def can_host?(%Scope{user: user} = scope, now \\ DateTime.utc_now()) do
    cond do
      Scope.staff?(scope) ->
        :ok

      is_nil(Repo.get_by(RiderProfile, user_id: user.id)) ->
        {:error, :no_profile}

      upcoming_hosted_count(user.id, now) >= @max_upcoming_per_host ->
        {:error, :limit}

      true ->
        :ok
    end
  end

  defp upcoming_hosted_count(user_id, now) do
    Event
    |> where(
      [e],
      e.category == :group_ride and e.created_by_id == ^user_id and
        e.status in [:published, :hidden] and e.starts_at >= ^now
    )
    |> Repo.aggregate(:count)
  end

  @doc """
  Posts a group ride hosted by the scope's user. It goes live immediately.
  Returns `{:ok, event}`, `{:error, :no_profile}`, `{:error, :limit}` or
  `{:error, changeset}`.
  """
  def create_group_ride(%Scope{user: user} = scope, attrs) do
    with :ok <- can_host?(scope) do
      %Event{category: :group_ride, status: :published, created_by_id: user.id}
      |> Event.group_ride_changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Cancels an event and emails everyone who RSVP'd (going and waitlist).
  Staff or the host. RSVPs are kept so riders still see it on their list.
  """
  def cancel_event(%Scope{} = scope, %Event{} = event, event_url_fun) do
    ensure_can_manage!(scope, event)

    with {:ok, cancelled} <- event |> Ecto.Changeset.change(status: :cancelled) |> Repo.update() do
      broadcast_rsvps_changed(cancelled)

      Rsvp
      |> where(event_id: ^event.id)
      |> preload(:user)
      |> Repo.all()
      |> Enum.each(
        &Notifier.deliver_event_cancelled(&1.user, cancelled, event_url_fun.(cancelled))
      )

      {:ok, cancelled}
    end
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
