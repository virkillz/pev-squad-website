defmodule PevSquad.Reviews do
  @moduledoc """
  PEV reviews written by members, and the model catalog they hang off.

  * One review per member per model. Reviews need a rider profile, because
    they are shown under the rider's alias.
  * Moderation: reviews from new members wait in a queue. Staff, and members
    with at least 2 published reviews ("trusted"), publish straight away.
    A review of a model that isn't approved yet always waits, since the
    moderator approves the model along with it.
  * Every published review counts equally in model averages. (The
    `featured` column is left over from the Featured Rider badge, which is
    switched off for now — see DESIGN.md decision 14.)
  """

  import Ecto.Query, warn: false
  use Gettext, backend: PevSquadWeb.Gettext

  alias Ecto.Multi
  alias PevSquad.Accounts.Scope
  alias PevSquad.Repo
  alias PevSquad.Reviews.{Notifier, PevModel, Review}
  alias PevSquad.Riders.RiderProfile

  @trusted_after 2

  ## Public

  @doc "Published reviews, newest first. Options: `:type`, `:limit`, `:exclude_users`."
  def list_published_reviews(opts \\ []) do
    published()
    |> join(:inner, [r], m in assoc(r, :pev_model), as: :model)
    |> filter_type(opts[:type])
    |> exclude_authors(opts[:exclude_users])
    |> order_by([r], desc: r.published_at, desc: r.id)
    |> maybe_limit(opts[:limit])
    |> preload([model: m], pev_model: m)
    |> Repo.all()
    |> attach_profiles()
  end

  defp published, do: where(Review, status: :published)

  defp filter_type(query, nil), do: query
  defp filter_type(query, type), do: where(query, [model: m], m.pev_type == ^type)

  defp exclude_authors(query, ids) when ids in [nil, []], do: query
  defp exclude_authors(query, ids), do: where(query, [r], r.author_id not in ^ids)

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, n), do: limit(query, ^n)

  @doc """
  "The Sheet": approved models with at least one published review, ranked by
  average overall score. Each row has `:model`, `:reviews` and `:overall`.
  """
  def sheet(opts \\ []) do
    published()
    |> join(:inner, [r], m in assoc(r, :pev_model), as: :model)
    |> where([model: m], m.approved)
    |> filter_type(opts[:type])
    |> group_by([model: m], m.id)
    |> select([r, model: m], %{
      model: m,
      reviews: count(r.id),
      overall: type(avg(r.overall), :decimal)
    })
    |> Repo.all()
    |> Enum.map(&%{&1 | overall: tenths(&1.overall)})
    |> Enum.sort_by(&{-&1.overall, -&1.reviews, PevModel.full_name(&1.model)})
  end

  # SQL averages over integer tenths -> a one-decimal 0–10 score.
  defp tenths(%Decimal{} = d), do: d |> Decimal.to_float() |> Kernel./(10) |> Float.round(1)

  @doc "An approved model with its sheet row (nil if no reviews yet)."
  def get_model!(slug) do
    model = Repo.get_by!(PevModel, slug: slug, approved: true)
    row = Enum.find(sheet(), &(&1.model.id == model.id))
    {model, row}
  end

  def list_model_reviews(%PevModel{id: id}, opts \\ []) do
    published()
    |> where(pev_model_id: ^id)
    |> exclude_authors(opts[:exclude_users])
    |> order_by([r], desc: r.published_at)
    |> preload(:pev_model)
    |> Repo.all()
    |> attach_profiles()
  end

  @doc """
  A review page. Published reviews are public; authors and staff can also
  see pending and rejected ones.
  """
  def get_review!(scope, id) do
    review = Review |> preload(:pev_model) |> Repo.get!(id) |> attach_profile()

    if review.status == :published or Scope.staff?(scope) or own?(scope, review) do
      review
    else
      raise Ecto.NoResultsError, queryable: Review
    end
  end

  def own?(%Scope{user: user}, %Review{author_id: author_id}), do: user.id == author_id
  def own?(_scope, _review), do: false

  defp attach_profile(review), do: review |> List.wrap() |> attach_profiles() |> hd()

  defp attach_profiles(reviews) do
    ids = reviews |> Enum.map(& &1.author_id) |> Enum.uniq()

    profiles =
      RiderProfile
      |> where([p], p.user_id in ^ids)
      |> Repo.all()
      |> Map.new(&{&1.user_id, &1})

    Enum.map(reviews, &%{&1 | author_profile: Map.get(profiles, &1.author_id)})
  end

  ## Catalog

  @doc "Models a member can pick: approved ones plus their own pending suggestions."
  def list_selectable_models(%Scope{user: user}) do
    PevModel
    |> where([m], m.approved or m.created_by_id == ^user.id)
    |> order_by([m], asc: fragment("lower(?)", m.brand), asc: fragment("lower(?)", m.name))
    |> Repo.all()
  end

  def change_model(%PevModel{} = model, attrs \\ %{}), do: PevModel.changeset(model, attrs)

  ## Writing reviews

  def get_my_review!(%Scope{user: user}, id) do
    Review |> where(author_id: ^user.id) |> preload(:pev_model) |> Repo.get!(id)
  end

  def list_my_reviews(%Scope{user: user}) do
    Review
    |> where(author_id: ^user.id)
    |> order_by([r], desc: r.updated_at)
    |> preload(:pev_model)
    |> Repo.all()
  end

  def change_review(%Review{} = review, attrs \\ %{}), do: Review.changeset(review, attrs)

  @doc """
  Submits a review. When `new_model` attrs are given, the model is added to
  the catalog (pending) and the review attached to it.

  Returns `{:ok, review}`, `{:error, :no_profile}`, `{:error, :pending}`, or
  `{:error, %Ecto.Changeset{}}` for either the review or the new model.
  """
  def create_review(%Scope{user: user} = scope, attrs, new_model \\ nil) do
    case PevSquad.Riders.can_post?(scope) do
      {:error, _} = blocked -> blocked
      :ok -> do_create_review(scope, user, attrs, new_model)
    end
  end

  defp do_create_review(scope, user, attrs, new_model) do
    Multi.new()
    |> maybe_insert_model(user, new_model)
    |> Multi.insert(:review, fn changes ->
      attrs =
        if model = changes[:model], do: Map.put(attrs, "pev_model_id", model.id), else: attrs

      %Review{author_id: user.id}
      |> Review.changeset(attrs)
      |> put_publication(scope)
    end)
    |> Repo.transact()
    |> case do
      {:ok, %{review: review}} -> {:ok, Repo.preload(review, :pev_model)}
      {:error, _step, changeset, _} -> {:error, changeset}
    end
  end

  defp maybe_insert_model(multi, _user, nil), do: multi

  defp maybe_insert_model(multi, user, attrs) do
    Multi.insert(multi, :model, PevModel.changeset(%PevModel{created_by_id: user.id}, attrs))
  end

  @doc """
  Updates the member's own review. Edits from untrusted members (or to a
  rejected review) go back into the moderation queue.
  """
  def update_review(%Scope{user: user} = scope, %Review{author_id: author_id} = review, attrs)
      when author_id == user.id do
    review
    |> Review.changeset(attrs)
    |> put_publication(scope)
    |> Repo.update()
  end

  def delete_review(%Scope{} = scope, %Review{} = review) do
    if own?(scope, review) or Scope.staff?(scope) do
      Repo.delete(review)
    else
      {:error, :not_allowed}
    end
  end

  # Decides :published vs :pending for a member submission.
  defp put_publication(%Ecto.Changeset{valid?: false} = changeset, _scope), do: changeset

  defp put_publication(changeset, scope) do
    model_id = Ecto.Changeset.get_field(changeset, :pev_model_id)
    model_approved? = model_id && Repo.exists?(where(PevModel, id: ^model_id, approved: true))

    if model_approved? and trusted?(scope) do
      publish(changeset, nil)
    else
      Ecto.Changeset.change(changeset, status: :pending, published_at: nil, rejection_reason: nil)
    end
  end

  defp publish(changeset, moderator_id) do
    Ecto.Changeset.change(changeset,
      status: :published,
      published_at:
        Ecto.Changeset.get_field(changeset, :published_at) || DateTime.utc_now(:second),
      rejection_reason: nil,
      moderated_by_id: moderator_id
    )
  end

  @doc "Staff, or members with #{@trusted_after}+ published reviews."
  def trusted?(%Scope{user: user} = scope) do
    Scope.staff?(scope) or
      published() |> where(author_id: ^user.id) |> Repo.aggregate(:count) >= @trusted_after
  end

  ## Moderation (staff)

  def list_pending_reviews(%Scope{} = scope) do
    ensure_staff!(scope)

    Review
    |> where(status: :pending)
    |> order_by([r], asc: r.updated_at)
    |> preload(:pev_model)
    |> Repo.all()
    |> attach_profiles()
  end

  def count_pending(%Scope{} = scope) do
    ensure_staff!(scope)
    Repo.aggregate(where(Review, status: :pending), :count)
  end

  @doc "Publishes a review (approving its model too) and emails the author."
  def approve_review(%Scope{} = scope, %Review{} = review, review_url_fun) do
    ensure_staff!(scope)

    result =
      Repo.transact(fn ->
        PevModel |> where(id: ^review.pev_model_id) |> Repo.update_all(set: [approved: true])

        review
        |> Ecto.Changeset.change()
        |> publish(scope.user.id)
        |> Repo.update()
      end)

    with {:ok, review} <- result do
      review = Repo.preload(review, [:author, :pev_model], force: true)
      Notifier.deliver_review_approved(review, review_url_fun.(review))
      {:ok, review}
    end
  end

  def reject_review(%Scope{} = scope, %Review{} = review, reason, edit_url_fun) do
    ensure_staff!(scope)

    result =
      review
      |> Ecto.Changeset.change(
        status: :rejected,
        rejection_reason: reason |> to_string() |> String.trim() |> String.slice(0, 255),
        published_at: nil,
        moderated_by_id: scope.user.id
      )
      |> Ecto.Changeset.validate_required(:rejection_reason,
        message: dgettext_noop("errors", "tell the rider why")
      )
      |> Repo.update()

    with {:ok, review} <- result do
      review = Repo.preload(review, [:author, :pev_model], force: true)
      Notifier.deliver_review_rejected(review, edit_url_fun.(review))
      {:ok, review}
    end
  end

  def list_models_for_staff(%Scope{} = scope) do
    ensure_staff!(scope)

    PevModel
    |> order_by([m], asc: m.approved, asc: fragment("lower(?)", m.brand), asc: m.name)
    |> Repo.all()
  end

  def get_model_for_staff!(%Scope{} = scope, id) do
    ensure_staff!(scope)
    Repo.get!(PevModel, id)
  end

  def create_model(%Scope{} = scope, attrs) do
    ensure_staff!(scope)

    %PevModel{created_by_id: scope.user.id, approved: true}
    |> PevModel.staff_changeset(attrs)
    |> Repo.insert()
  end

  def update_model(%Scope{} = scope, %PevModel{} = model, attrs) do
    ensure_staff!(scope)
    model |> PevModel.staff_changeset(attrs) |> Repo.update()
  end

  def change_model_for_staff(%PevModel{} = model, attrs \\ %{}),
    do: PevModel.staff_changeset(model, attrs)

  defp ensure_staff!(scope) do
    unless Scope.staff?(scope), do: raise(PevSquad.Reviews.NotAuthorizedError)
  end
end

defmodule PevSquad.Reviews.NotAuthorizedError do
  defexception message: "only moderators and admins can moderate reviews", plug_status: 403
end
