defmodule PevSquad.Gallery do
  @moduledoc """
  Photo albums and the photos in them.

  Staff create albums (optionally tied to an event). Members can add photos
  to published albums that are open for uploads; their photos wait for a
  moderator until they have 3 published, after which they go live
  straight away. Staff uploads are always live.
  """

  import Ecto.Query, warn: false

  alias PevSquad.Accounts.Scope
  alias PevSquad.Gallery.{Album, Photo, Processing}
  alias PevSquad.Repo
  alias PevSquad.Riders.RiderProfile

  @trusted_after 3

  ## Public

  @doc """
  Published albums with at least one live photo, newest first, each with
  `photo_count` and up to `preview` photos preloaded.

  Options: `:preview` (default 8), `:exclude_users`, `:event_id` (albums of
  that event), `:id` (just that album).
  """
  def list_published_albums(opts \\ []) do
    preview = Keyword.get(opts, :preview, 8)
    hidden = opts[:exclude_users] || []

    albums =
      Album
      |> where(published: true)
      |> then(fn q -> if id = opts[:event_id], do: where(q, event_id: ^id), else: q end)
      |> then(fn q -> if id = opts[:id], do: where(q, id: ^id), else: q end)
      |> join(:inner, [a], p in Photo,
        on:
          p.album_id == a.id and p.status == :published and
            (is_nil(p.uploader_id) or p.uploader_id not in ^hidden)
      )
      |> group_by([a], a.id)
      |> select_merge([a, p], %{photo_count: count(p.id)})
      |> order_by([a], desc_nulls_last: a.taken_on, desc: a.id)
      |> Repo.all()

    ids = Enum.map(albums, & &1.id)

    previews =
      from(p in Photo,
        where:
          p.album_id in ^ids and p.status == :published and
            (is_nil(p.uploader_id) or p.uploader_id not in ^hidden),
        select: %{p | position: over(row_number(), :w)},
        windows: [w: [partition_by: p.album_id, order_by: [asc: p.position, asc: p.id]]]
      )
      |> subquery()
      |> where([p], p.position <= ^preview)
      |> order_by([p], asc: p.position)
      |> Repo.all()
      |> Enum.group_by(& &1.album_id)

    Enum.map(albums, &%{&1 | photos: Map.get(previews, &1.id, [])})
  end

  @doc """
  The albums to show on an event page: published, with at least one live
  photo, each with `photo_count` and a few preview photos. Takes the same
  options as `list_published_albums/1`.
  """
  def list_event_albums(%{id: event_id}, opts \\ []) do
    opts
    |> Keyword.put(:event_id, event_id)
    |> Keyword.put_new(:preview, 4)
    |> list_published_albums()
  end

  @doc """
  The album to show with a news item or article: its own album if it has
  one, otherwise (for a recap) its event's newest album. Nil when there is
  none, or it isn't published or has no live photos yet.
  """
  def album_for_post(post, opts \\ [])

  def album_for_post(%{album_id: id}, opts) when is_integer(id) do
    opts
    |> Keyword.merge(id: id)
    |> Keyword.put_new(:preview, 4)
    |> list_published_albums()
    |> List.first()
  end

  def album_for_post(%{event_id: id}, opts) when is_integer(id),
    do: %{id: id} |> list_event_albums(opts) |> List.first()

  def album_for_post(_post, _opts), do: nil

  def get_published_album!(slug, opts \\ []) do
    hidden = opts[:exclude_users] || []

    Album
    |> where(slug: ^slug, published: true)
    |> Repo.one!()
    |> Repo.preload(
      event: where(PevSquad.Events.Event, status: :published),
      photos:
        where(published_photos(), [p], is_nil(p.uploader_id) or p.uploader_id not in ^hidden)
    )
    |> then(&%{&1 | photos: attach_profiles(&1.photos)})
  end

  defp published_photos do
    from p in Photo, where: p.status == :published, order_by: [asc: p.position, asc: p.id]
  end

  @doc """
  Featured photos for the home page carousel, most recently featured first:
  live photos in published albums, album preloaded. Options: `:limit`
  (default 8), `:exclude_users`.
  """
  def list_featured_photos(opts \\ []) do
    hidden = opts[:exclude_users] || []

    Photo
    |> join(:inner, [p], a in assoc(p, :album))
    |> where([p, a], p.featured and p.status == :published and a.published)
    |> where([p], is_nil(p.uploader_id) or p.uploader_id not in ^hidden)
    |> order_by([p], desc: p.featured_at, desc: p.id)
    |> limit(^Keyword.get(opts, :limit, 8))
    |> preload([p, a], album: a)
    |> Repo.all()
    |> attach_profiles()
  end

  def total_published_photos do
    Photo
    |> join(:inner, [p], a in assoc(p, :album))
    |> where([p, a], p.status == :published and a.published)
    |> Repo.aggregate(:count)
  end

  defp attach_profiles(photos) do
    ids = photos |> Enum.map(& &1.uploader_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    profiles =
      RiderProfile |> where([r], r.user_id in ^ids) |> Repo.all() |> Map.new(&{&1.user_id, &1})

    Enum.map(photos, &%{&1 | uploader_profile: Map.get(profiles, &1.uploader_id)})
  end

  ## Uploading

  @doc "Whether the scope can add photos to this album."
  def can_upload?(nil, _album), do: false

  def can_upload?(%Scope{} = scope, %Album{} = album) do
    Scope.staff?(scope) or (album.published and album.open_for_uploads)
  end

  def trusted?(%Scope{user: user} = scope) do
    Scope.staff?(scope) or
      Photo
      |> where(uploader_id: ^user.id, status: :published)
      |> Repo.aggregate(:count) >= @trusted_after
  end

  @doc """
  Processes and adds one photo. Returns `{:ok, photo}`, `{:error, :no_profile}`,
  `{:error, :pending}` (profile not approved yet), `{:error, :closed}`,
  `{:error, :unreadable}` or `{:error, changeset}`.
  """
  def upload_photo(%Scope{user: user} = scope, %Album{} = album, source, attrs \\ %{}) do
    cond do
      (blocked = PevSquad.Riders.can_post?(scope)) != :ok ->
        blocked

      not can_upload?(scope, album) ->
        {:error, :closed}

      true ->
        case Processing.store(source, album.slug) do
          {:ok, files} ->
            %Photo{
              album_id: album.id,
              uploader_id: user.id,
              status: if(trusted?(scope), do: :published, else: :pending),
              position: next_position(album)
            }
            |> Ecto.Changeset.change(files)
            |> Photo.details_changeset(attrs)
            |> Repo.insert()
            |> tap(fn
              {:error, _} -> Processing.delete(files)
              _ -> :ok
            end)

          {:error, _reason} ->
            {:error, :unreadable}
        end
    end
  end

  defp next_position(%Album{id: id}) do
    (Photo |> where(album_id: ^id) |> select([p], max(p.position)) |> Repo.one() || 0) + 1
  end

  def list_my_photos(%Scope{user: user}) do
    Photo
    |> where(uploader_id: ^user.id)
    |> order_by([p], desc: p.inserted_at)
    |> preload(:album)
    |> Repo.all()
  end

  @doc "Deletes a photo (uploader or staff) and its files."
  def delete_photo(%Scope{} = scope, %Photo{} = photo) do
    if Scope.staff?(scope) or photo.uploader_id == scope.user.id do
      with {:ok, photo} <- Repo.delete(photo) do
        Processing.delete(photo)
        {:ok, photo}
      end
    else
      {:error, :not_allowed}
    end
  end

  ## Staff: albums

  def list_albums_for_staff(%Scope{} = scope) do
    ensure_staff!(scope)

    Album
    |> join(:left, [a], p in Photo, on: p.album_id == a.id)
    |> group_by([a], a.id)
    |> select_merge([a, p], %{photo_count: count(p.id)})
    |> order_by([a], desc_nulls_last: a.taken_on, desc: a.id)
    |> Repo.all()
  end

  def get_album!(%Scope{} = scope, id) do
    ensure_staff!(scope)
    Album |> Repo.get!(id) |> Repo.preload(photos: from(p in Photo, order_by: [p.position, p.id]))
  end

  @doc "Any album by slug for staff; published ones for everyone else."
  def get_album_for_upload!(scope, slug) do
    if Scope.staff?(scope),
      do: Repo.get_by!(Album, slug: slug),
      else: Repo.get_by!(Album, slug: slug, published: true)
  end

  def create_album(%Scope{} = scope, attrs) do
    ensure_staff!(scope)
    %Album{created_by_id: scope.user.id} |> Album.changeset(attrs) |> Repo.insert()
  end

  def update_album(%Scope{} = scope, %Album{} = album, attrs) do
    ensure_staff!(scope)
    album |> Album.changeset(attrs) |> Repo.update()
  end

  def change_album(%Album{} = album, attrs \\ %{}), do: Album.changeset(album, attrs)

  @doc """
  Makes `album_ids` the event's albums: those albums now point at this event
  (moving them from any other event) and its other albums are unlinked.
  """
  def set_event_albums(%Scope{} = scope, %{id: event_id}, album_ids) when is_list(album_ids) do
    ensure_staff!(scope)

    Repo.transact(fn ->
      Album
      |> where([a], a.event_id == ^event_id and a.id not in ^album_ids)
      |> Repo.update_all(set: [event_id: nil, updated_at: now()])

      Album
      |> where([a], a.id in ^album_ids)
      |> Repo.update_all(set: [event_id: event_id, updated_at: now()])

      {:ok, list_event_album_ids(event_id)}
    end)
  end

  @doc "Ids of every album linked to the event, drafts included (for staff tools)."
  def list_event_album_ids(%{id: event_id}), do: list_event_album_ids(event_id)

  def list_event_album_ids(event_id) when is_integer(event_id) do
    Album |> where(event_id: ^event_id) |> order_by(:id) |> select([a], a.id) |> Repo.all()
  end

  @doc "Which of these album ids exist."
  def existing_album_ids(ids) when is_list(ids) do
    Album |> where([a], a.id in ^ids) |> select([a], a.id) |> Repo.all()
  end

  defp now, do: DateTime.utc_now(:second)

  def delete_album(%Scope{} = scope, %Album{} = album) do
    ensure_staff!(scope)
    photos = Repo.all(where(Photo, album_id: ^album.id))

    with {:ok, album} <- Repo.delete(album) do
      Enum.each(photos, &Processing.delete/1)
      {:ok, album}
    end
  end

  ## Staff: photos

  def list_pending_photos(%Scope{} = scope) do
    ensure_staff!(scope)

    Photo
    |> where(status: :pending)
    |> order_by([p], asc: p.inserted_at)
    |> preload(:album)
    |> Repo.all()
    |> attach_profiles()
  end

  def count_pending_photos(%Scope{} = scope) do
    ensure_staff!(scope)
    Repo.aggregate(where(Photo, status: :pending), :count)
  end

  def approve_photo(%Scope{} = scope, %Photo{} = photo) do
    ensure_staff!(scope)

    photo
    |> Ecto.Changeset.change(status: :published, moderated_by_id: scope.user.id)
    |> Repo.update()
  end

  @doc "Rejected photos are deleted outright, files included."
  def reject_photo(%Scope{} = scope, %Photo{} = photo) do
    ensure_staff!(scope)
    delete_photo(scope, photo)
  end

  def update_photo(%Scope{} = scope, %Photo{} = photo, attrs) do
    ensure_staff!(scope)
    photo |> Photo.staff_changeset(attrs) |> Repo.update()
  end

  @doc """
  Moves a photo to another album, at the end of its photo order. Status,
  featured flag and files stay as they are (files aren't stored per album).
  Returns `{:ok, photo}` or `{:error, :not_found}` / `{:error, :same_album}`.
  """
  def move_photo(%Scope{} = scope, %Photo{} = photo, album_id) do
    ensure_staff!(scope)

    with %Album{id: target_id} <- Repo.get(Album, album_id) || {:error, :not_found},
         true <- target_id != photo.album_id || {:error, :same_album} do
      last =
        Photo
        |> where(album_id: ^target_id)
        |> select([p], max(p.position))
        |> Repo.one()

      photo
      |> Ecto.Changeset.change(album_id: target_id, position: (last || 0) + 1)
      |> Repo.update()
    end
  end

  defp ensure_staff!(scope) do
    unless Scope.staff?(scope), do: raise(PevSquad.Gallery.NotAuthorizedError)
  end
end

defmodule PevSquad.Gallery.NotAuthorizedError do
  defexception message: "only moderators and admins can manage the gallery", plug_status: 403
end
