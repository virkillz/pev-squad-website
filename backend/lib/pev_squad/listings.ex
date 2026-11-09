defmodule PevSquad.Listings do
  @moduledoc """
  The For Sale board: members selling gear to each other.

  * Only members with an **active** rider profile (and staff) can post.
  * Every new listing waits for a moderator. Once approved, the seller can
    change price, quantity, city and contact freely; changing the title,
    category, condition, description or photos sends it back to the queue.
  * **Decay**: an approved listing stays live for 7 days after the
    seller last confirmed it's still available ("check in"). The clock
    starts at approval. Sellers get one reminder email a couple of days
    before it lapses. An expired listing comes back with one check-in,
    unless it has been expired for over 30 days, in which case it goes
    back through review.
  * **Sold** listings stay on the board, marked sold, for 7 days.
  * Sellers can hide a listing (and unhide it) or delete it. Deleting is
    soft: the row stays for staff in case of a dispute.

  Nothing flips a status when time passes: visibility is worked out from
  `approved_at`, `last_checked_at`, `sold_at`, `hidden_at` and
  `deleted_at`.
  """

  import Ecto.Query, warn: false

  alias PevSquad.Accounts
  alias PevSquad.Accounts.Scope
  alias PevSquad.Listings.{Listing, Notifier, Processing}
  alias PevSquad.Repo
  alias PevSquad.Riders
  alias PevSquad.Riders.RiderProfile

  @fresh_days 7
  @sold_visible_days 7
  @remind_after_days 5
  @rereview_after_days 30

  def fresh_days, do: @fresh_days
  def sold_visible_days, do: @sold_visible_days

  ## State

  @doc """
  Where a listing stands at `now`: `:pending`, `:rejected`, `:live`,
  `:expired`, `:sold` (still on the board), `:sold_archived`, `:hidden`
  or `:deleted`.
  """
  def state(%Listing{} = l, now \\ DateTime.utc_now()) do
    cond do
      l.deleted_at -> :deleted
      l.status == :pending -> :pending
      l.status == :rejected -> :rejected
      l.sold_at && DateTime.after?(sold_until(l), now) -> :sold
      l.sold_at -> :sold_archived
      l.hidden_at -> :hidden
      DateTime.after?(expires_at(l), now) -> :live
      true -> :expired
    end
  end

  @doc "When an approved listing lapses unless the seller checks in."
  def expires_at(%Listing{last_checked_at: nil}), do: nil
  def expires_at(%Listing{last_checked_at: at}), do: DateTime.add(at, @fresh_days, :day)

  def sold_until(%Listing{sold_at: at}), do: DateTime.add(at, @sold_visible_days, :day)

  ## Public board

  @doc """
  Live listings, most recently confirmed first. Options: `:category`,
  `:exclude_users` (blocked sellers).
  """
  def list_live_listings(opts \\ []) do
    now = DateTime.utc_now()

    board_query(opts)
    |> where([l], is_nil(l.sold_at) and is_nil(l.hidden_at))
    |> where([l], l.last_checked_at > ^DateTime.add(now, -@fresh_days, :day))
    |> order_by([l], desc: l.last_checked_at, desc: l.id)
    |> Repo.all()
    |> attach_profiles()
  end

  @doc "Listings sold in the last #{@sold_visible_days} days, newest first."
  def list_recently_sold(opts \\ []) do
    since = DateTime.add(DateTime.utc_now(), -@sold_visible_days, :day)

    board_query(opts)
    |> where([l], l.sold_at > ^since)
    |> order_by([l], desc: l.sold_at, desc: l.id)
    |> Repo.all()
    |> attach_profiles()
  end

  # Approved, not deleted, and the seller is still in good standing.
  defp board_query(opts) do
    hidden = opts[:exclude_users] || []

    Listing
    |> join(:inner, [l], u in assoc(l, :seller))
    |> join(:left, [l, u], r in RiderProfile, on: r.user_id == u.id)
    |> where([l], l.status == :approved and is_nil(l.deleted_at))
    |> where([l, u, r], r.status == :active or u.role in [:moderator, :admin])
    |> where([l], l.seller_id not in ^hidden)
    |> then(fn q ->
      case opts[:category] do
        nil -> q
        category -> where(q, [l], l.category == ^category)
      end
    end)
  end

  @doc """
  A listing for its public page. Everyone sees live and recently sold
  listings; the seller and staff see their own in any state but deleted.
  Raises `Ecto.NoResultsError` otherwise.
  """
  def get_public_listing!(scope, id) do
    listing = Listing |> where([l], is_nil(l.deleted_at)) |> Repo.get!(id)
    [listing] = attach_profiles([listing])

    cond do
      owner?(scope, listing) or Scope.staff?(scope) -> listing
      state(listing) in [:live, :sold] and seller_in_good_standing?(listing) -> listing
      true -> raise Ecto.NoResultsError, queryable: Listing
    end
  end

  defp seller_in_good_standing?(%Listing{seller_profile: %RiderProfile{status: :active}}),
    do: true

  defp seller_in_good_standing?(%Listing{seller_id: id}) do
    Repo.get!(Accounts.User, id).role in [:moderator, :admin]
  end

  def owner?(%Scope{user: %{id: id}}, %Listing{seller_id: id}), do: true
  def owner?(_scope, _listing), do: false

  defp attach_profiles(listings) do
    ids = listings |> Enum.map(& &1.seller_id) |> Enum.uniq()

    profiles =
      RiderProfile |> where([r], r.user_id in ^ids) |> Repo.all() |> Map.new(&{&1.user_id, &1})

    Enum.map(listings, &%{&1 | seller_profile: Map.get(profiles, &1.seller_id)})
  end

  ## Selling

  @doc """
  Whether the scope can post listings: `:ok`, or `{:error, reason}` with
  `:no_profile`, `:pending` or `:inactive` (inactive or banned profile).
  """
  def can_sell?(nil), do: {:error, :no_profile}

  def can_sell?(%Scope{} = scope) do
    if Scope.staff?(scope) do
      :ok
    else
      case Riders.get_my_profile(scope) do
        nil -> {:error, :no_profile}
        %RiderProfile{status: :active} -> :ok
        %RiderProfile{status: :pending} -> {:error, :pending}
        %RiderProfile{} -> {:error, :inactive}
      end
    end
  end

  @doc "A blank listing with the city and Instagram from the seller's profile."
  def new_listing(%Scope{} = scope) do
    profile = Riders.get_my_profile(scope)

    %Listing{
      seller_id: scope.user.id,
      city: profile && profile.city,
      instagram: profile && profile.instagram
    }
  end

  def change_listing(%Listing{} = listing, attrs \\ %{}), do: Listing.changeset(listing, attrs)

  @doc "The seller's listings (not deleted), newest first."
  def list_my_listings(%Scope{user: user}) do
    Listing
    |> where([l], l.seller_id == ^user.id and is_nil(l.deleted_at))
    |> order_by([l], desc: l.inserted_at, desc: l.id)
    |> Repo.all()
  end

  @doc "One of the seller's own listings (staff can open any). Raises if not found."
  def get_my_listing!(%Scope{} = scope, id) do
    listing = Listing |> where([l], is_nil(l.deleted_at)) |> Repo.get!(id)

    if owner?(scope, listing) or Scope.staff?(scope),
      do: listing,
      else: raise(Ecto.NoResultsError, queryable: Listing)
  end

  @doc """
  Creates a pending listing from form `attrs` and uploaded image paths.
  Options: `:review_url` (fun listing -> admin URL) to email the
  moderators. Returns `{:ok, listing}`, `{:error, changeset}`,
  `{:error, :unreadable}` or `{:error, reason}` from `can_sell?/1`.
  """
  def create_listing(%Scope{} = scope, attrs, sources, opts \\ []) do
    with :ok <- can_sell?(scope),
         {:ok, photos} <- store_photos(sources) do
      %Listing{seller_id: scope.user.id}
      |> Listing.changeset(attrs)
      |> Listing.photos_changeset(photos)
      |> Repo.insert()
      |> after_save(photos, [], opts)
    end
  end

  @doc """
  Saves the seller's edits. `kept` is the list of existing photo
  `large_path`s to keep, in order; `sources` are new uploads appended
  after them. Editing a rejected listing, or changing a reviewed field of
  an approved one, sends it back to the queue.
  """
  def update_listing(%Scope{} = scope, %Listing{} = listing, attrs, kept, sources, opts \\ []) do
    ensure_manager!(scope, listing)

    with {:ok, new_photos} <- store_photos(sources) do
      kept_photos = Enum.filter(listing.photos, &(&1.large_path in kept))
      removed = listing.photos -- kept_photos

      changeset =
        listing
        |> Listing.changeset(attrs)
        |> Listing.photos_changeset(kept_photos ++ new_photos)
        |> requeue_if_needed(listing)

      changeset
      |> Repo.update()
      |> after_save(new_photos, removed, opts)
    end
  end

  defp requeue_if_needed(changeset, %Listing{status: status}) do
    reviewed_changed? = Enum.any?(Listing.reviewed_fields(), &Map.has_key?(changeset.changes, &1))

    if status == :rejected or (status == :approved and reviewed_changed?) do
      Ecto.Changeset.change(changeset, status: :pending, rejection_reason: nil)
    else
      changeset
    end
  end

  defp after_save({:ok, listing}, _new, removed, opts) do
    Enum.each(removed, &Processing.delete/1)
    if listing.status == :pending, do: notify_staff(listing, opts[:review_url])
    {:ok, listing}
  end

  defp after_save({:error, _} = error, new, _removed, _opts) do
    Enum.each(new, &Processing.delete/1)
    error
  end

  defp store_photos(sources) do
    Enum.reduce_while(sources, {:ok, []}, fn source, {:ok, acc} ->
      case Processing.store(source) do
        {:ok, photo} ->
          {:cont, {:ok, acc ++ [photo]}}

        {:error, _} ->
          Enum.each(acc, &Processing.delete/1)
          {:halt, {:error, :unreadable}}
      end
    end)
  end

  defp notify_staff(_listing, nil), do: :ok

  defp notify_staff(listing, url_fun) do
    url = url_fun.(listing)
    for staff <- Accounts.list_staff_contacts(), do: Notifier.deliver_waiting(staff, listing, url)
    :ok
  end

  @doc """
  "Still available": restarts the #{@fresh_days}-day clock. A listing that
  has been expired for more than #{@rereview_after_days} days goes back to
  the moderators instead. Returns `{:ok, listing}` or `{:error, :not_allowed}`.
  """
  def check_in(%Scope{} = scope, %Listing{} = listing, opts \\ []) do
    ensure_manager!(scope, listing)
    now = DateTime.utc_now(:second)

    cond do
      listing.status != :approved or listing.sold_at ->
        {:error, :not_allowed}

      long_expired?(listing, now) ->
        listing
        |> Ecto.Changeset.change(status: :pending)
        |> Repo.update()
        |> after_save([], [], opts)

      true ->
        listing |> Ecto.Changeset.change(last_checked_at: now) |> Repo.update()
    end
  end

  defp long_expired?(listing, now) do
    DateTime.before?(
      DateTime.add(expires_at(listing), @rereview_after_days, :day),
      now
    )
  end

  def mark_sold(%Scope{} = scope, %Listing{} = listing) do
    ensure_manager!(scope, listing)
    listing |> Ecto.Changeset.change(sold_at: DateTime.utc_now(:second)) |> Repo.update()
  end

  @doc "Undoes a sold mark (e.g. the buyer pulled out) and restarts the clock."
  def unmark_sold(%Scope{} = scope, %Listing{} = listing) do
    ensure_manager!(scope, listing)
    now = DateTime.utc_now(:second)
    changes = [sold_at: nil] ++ if(listing.approved_at, do: [last_checked_at: now], else: [])
    listing |> Ecto.Changeset.change(changes) |> Repo.update()
  end

  def hide(%Scope{} = scope, %Listing{} = listing) do
    ensure_manager!(scope, listing)
    listing |> Ecto.Changeset.change(hidden_at: DateTime.utc_now(:second)) |> Repo.update()
  end

  def unhide(%Scope{} = scope, %Listing{} = listing) do
    ensure_manager!(scope, listing)
    listing |> Ecto.Changeset.change(hidden_at: nil) |> Repo.update()
  end

  @doc "Soft delete: gone for everyone; the row and photos stay for staff."
  def delete_listing(%Scope{} = scope, %Listing{} = listing) do
    ensure_manager!(scope, listing)
    listing |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second)) |> Repo.update()
  end

  ## Reminders

  @doc """
  Emails sellers whose live listing lapses within the next
  #{@fresh_days - @remind_after_days} days, once per check-in.
  `url` is the "My listings" page. Returns how many were sent.
  """
  def send_reminders(url, now \\ DateTime.utc_now()) do
    due = DateTime.add(now, -@remind_after_days, :day)
    lapsed = DateTime.add(now, -@fresh_days, :day)

    listings =
      Listing
      |> where([l], l.status == :approved)
      |> where([l], is_nil(l.sold_at) and is_nil(l.hidden_at) and is_nil(l.deleted_at))
      |> where([l], l.last_checked_at <= ^due and l.last_checked_at > ^lapsed)
      |> where([l], is_nil(l.reminded_at) or l.reminded_at < l.last_checked_at)
      |> preload(:seller)
      |> Repo.all()

    for listing <- listings do
      Notifier.deliver_reminder(listing.seller, listing, url)

      listing
      |> Ecto.Changeset.change(reminded_at: DateTime.truncate(now, :second))
      |> Repo.update!()
    end

    length(listings)
  end

  ## Staff

  def list_pending(%Scope{} = scope) do
    ensure_staff!(scope)

    Listing
    |> where([l], l.status == :pending and is_nil(l.deleted_at))
    |> order_by([l], asc: l.updated_at, asc: l.id)
    |> preload(:seller)
    |> Repo.all()
    |> attach_profiles()
  end

  def count_pending(%Scope{} = scope) do
    ensure_staff!(scope)
    Repo.aggregate(where(Listing, [l], l.status == :pending and is_nil(l.deleted_at)), :count)
  end

  @doc "Approves a listing and starts its #{@fresh_days}-day clock."
  def approve(%Scope{} = scope, %Listing{} = listing, url_fun) do
    ensure_staff!(scope)
    now = DateTime.utc_now(:second)

    with {:ok, listing} <-
           listing
           |> Ecto.Changeset.change(
             status: :approved,
             rejection_reason: nil,
             approved_at: listing.approved_at || now,
             last_checked_at: now,
             moderated_by_id: scope.user.id
           )
           |> Repo.update() do
      listing = Repo.preload(listing, :seller)
      Notifier.deliver_approved(listing.seller, listing, url_fun.(listing))
      {:ok, listing}
    end
  end

  def reject(%Scope{} = scope, %Listing{} = listing, reason, url_fun) do
    ensure_staff!(scope)
    reason = reason && String.trim(reason)

    if reason in [nil, ""] do
      {:error, :reason_required}
    else
      with {:ok, listing} <-
             listing
             |> Ecto.Changeset.change(
               status: :rejected,
               rejection_reason: String.slice(reason, 0, 250),
               moderated_by_id: scope.user.id
             )
             |> Repo.update() do
        listing = Repo.preload(listing, :seller)
        Notifier.deliver_rejected(listing.seller, listing, url_fun.(listing))
        {:ok, listing}
      end
    end
  end

  defp ensure_manager!(scope, listing) do
    unless owner?(scope, listing) or Scope.staff?(scope),
      do: raise(PevSquad.Listings.NotAuthorizedError)
  end

  defp ensure_staff!(scope) do
    unless Scope.staff?(scope), do: raise(PevSquad.Listings.NotAuthorizedError)
  end
end

defmodule PevSquad.Listings.NotAuthorizedError do
  defexception message: "that listing isn't yours", plug_status: 403
end
