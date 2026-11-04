defmodule PevSquad.Safety do
  @moduledoc """
  Reporting and blocking — required for any app with member-written content
  (Apple App Review 1.2, Google Play UGC policy).

  * Members report a review, photo or rider profile with a reason.
  * When 3 different members have open reports on the same review or
    photo, it is pulled back into the moderation queue automatically until
    staff look at it. Profiles are only flagged, never auto-hidden.
  * Blocking a member hides their profile, reviews and photos from you.
  * Staff resolve reports by dismissing them or removing the content.
  """

  import Ecto.Query, warn: false

  alias PevSquad.Accounts.Scope
  alias PevSquad.Gallery
  alias PevSquad.Gallery.Photo
  alias PevSquad.Repo
  alias PevSquad.Reviews
  alias PevSquad.Reviews.Review
  alias PevSquad.Riders.RiderProfile
  alias PevSquad.Safety.{Block, Report}

  @auto_hide_after 3

  ## Targets

  @doc """
  Loads a reportable item that the reporter can currently see. Returns
  `{:ok, target}` or `{:error, :not_found}`.
  """
  def get_target(:review, id) do
    case Repo.get(Review, id) do
      %Review{status: :published} = r -> {:ok, Repo.preload(r, :pev_model)}
      _ -> {:error, :not_found}
    end
  end

  def get_target(:photo, id) do
    case Repo.get(Photo, id) do
      %Photo{status: :published} = p -> {:ok, Repo.preload(p, :album)}
      _ -> {:error, :not_found}
    end
  end

  def get_target(:profile, id) do
    case Repo.get(RiderProfile, id) do
      %RiderProfile{is_public: true} = p -> {:ok, p}
      _ -> {:error, :not_found}
    end
  end

  def target_user_id(%Review{author_id: id}), do: id
  def target_user_id(%Photo{uploader_id: id}), do: id
  def target_user_id(%RiderProfile{user_id: id}), do: id

  def parse_type(type) when type in ~w(review photo profile),
    do: {:ok, String.to_existing_atom(type)}

  def parse_type(_), do: :error

  ## Reporting

  def change_report(attrs \\ %{}), do: Report.changeset(%Report{}, attrs)

  @doc """
  Files a report. Returns `{:ok, report}`, `{:error, :not_found}`,
  `{:error, :own_content}` or `{:error, changeset}`.
  """
  def report(%Scope{user: user}, type, id, attrs) do
    with {:ok, target} <- get_target(type, id),
         owner_id = target_user_id(target),
         :ok <- if(owner_id == user.id, do: {:error, :own_content}, else: :ok),
         {:ok, report} <-
           %Report{
             reporter_id: user.id,
             target_type: type,
             target_id: id,
             target_user_id: owner_id
           }
           |> Report.changeset(attrs)
           |> Repo.insert() do
      maybe_auto_hide(type, target)
      {:ok, report}
    end
  end

  defp maybe_auto_hide(type, target) when type in [:review, :photo] do
    reporters =
      Report
      |> where(target_type: ^type, target_id: ^target.id, status: :open)
      |> select([r], count(r.reporter_id, :distinct))
      |> Repo.one()

    if reporters >= @auto_hide_after do
      target |> Ecto.Changeset.change(status: :pending) |> Repo.update!()
    end

    :ok
  end

  defp maybe_auto_hide(:profile, _target), do: :ok

  ## Blocking

  def block(%Scope{user: user}, blocked_id) when blocked_id != user.id do
    %Block{blocker_id: user.id, blocked_id: blocked_id}
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:blocker_id, :blocked_id])
  end

  def block(_scope, _blocked_id), do: {:error, :self}

  def unblock(%Scope{user: user}, blocked_id) do
    Block |> where(blocker_id: ^user.id, blocked_id: ^blocked_id) |> Repo.delete_all()
    :ok
  end

  def blocked?(nil, _user_id), do: false

  def blocked?(%Scope{user: user}, user_id) do
    Repo.exists?(where(Block, blocker_id: ^user.id, blocked_id: ^user_id))
  end

  @doc "User ids whose content the scope shouldn't see. `[]` when logged out."
  def hidden_user_ids(nil), do: []

  def hidden_user_ids(%Scope{user: user}) do
    Block |> where(blocker_id: ^user.id) |> select([b], b.blocked_id) |> Repo.all()
  end

  @doc "Blocked members with their rider profile (if any), for the settings list."
  def list_blocked(%Scope{user: user}) do
    from(b in Block,
      where: b.blocker_id == ^user.id,
      left_join: p in RiderProfile,
      on: p.user_id == b.blocked_id,
      order_by: [desc: b.inserted_at],
      select: %{user_id: b.blocked_id, alias: p.alias}
    )
    |> Repo.all()
  end

  ## Staff

  @doc """
  Open reports grouped per item, oldest first:
  `[%{type, id, target, reports: [...], reasons: %{reason => count}}]`.
  `target` is nil if the item has since been deleted.
  """
  def list_open_reports(%Scope{} = scope) do
    ensure_staff!(scope)

    Report
    |> where(status: :open)
    |> order_by([r], asc: r.inserted_at)
    |> Repo.all()
    |> Enum.group_by(&{&1.target_type, &1.target_id})
    |> Enum.map(fn {{type, id}, reports} ->
      %{
        type: type,
        id: id,
        target: load_any(type, id),
        reports: reports,
        reasons: Enum.frequencies_by(reports, & &1.reason)
      }
    end)
    |> Enum.sort_by(&hd(&1.reports).inserted_at, DateTime)
  end

  def count_open(%Scope{} = scope) do
    ensure_staff!(scope)

    Report
    |> where(status: :open)
    |> select([r], count(fragment("DISTINCT (?, ?)", r.target_type, r.target_id)))
    |> Repo.one()
  end

  defp load_any(:review, id), do: Review |> Repo.get(id) |> Repo.preload(:pev_model)
  defp load_any(:photo, id), do: Photo |> Repo.get(id) |> Repo.preload(:album)
  defp load_any(:profile, id), do: Repo.get(RiderProfile, id)

  @doc "Closes all open reports on an item without action; restores auto-hidden content."
  def dismiss(%Scope{} = scope, type, id) do
    ensure_staff!(scope)

    # Reported items were live when reported, so a pending one was
    # auto-hidden: put it back quietly.
    case load_any(type, id) do
      %struct{status: :pending} = target when struct in [Review, Photo] ->
        target |> Ecto.Changeset.change(status: :published) |> Repo.update!()

      _ ->
        :ok
    end

    close_reports(scope, type, id, :dismissed, "No action needed")
  end

  @doc """
  Removes the reported content: a review is sent back to its author with
  `note`, a photo is deleted, a profile is hidden from the public site.
  """
  def remove_content(%Scope{} = scope, type, id, note, review_edit_url_fun) do
    ensure_staff!(scope)
    note = if note in [nil, ""], do: "Removed after reports from members.", else: note

    case load_any(type, id) do
      nil ->
        :ok

      %Review{} = review ->
        {:ok, _} = Reviews.reject_review(scope, review, note, review_edit_url_fun)

      %Photo{} = photo ->
        {:ok, _} = Gallery.delete_photo(scope, photo)

      %RiderProfile{} = p ->
        p |> Ecto.Changeset.change(is_public: false) |> Repo.update!()
    end

    close_reports(scope, type, id, :resolved, note)
  end

  defp close_reports(scope, type, id, status, resolution) do
    {count, _} =
      Report
      |> where(target_type: ^type, target_id: ^id, status: :open)
      |> Repo.update_all(
        set: [
          status: status,
          resolution: resolution,
          resolved_by_id: scope.user.id,
          resolved_at: DateTime.utc_now(:second),
          updated_at: DateTime.utc_now(:second)
        ]
      )

    {:ok, count}
  end

  defp ensure_staff!(scope) do
    unless Scope.staff?(scope), do: raise(PevSquad.Safety.NotAuthorizedError)
  end
end

defmodule PevSquad.Safety.NotAuthorizedError do
  defexception message: "only moderators and admins can handle reports", plug_status: 403
end
