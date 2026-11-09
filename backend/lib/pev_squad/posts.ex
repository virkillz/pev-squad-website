defmodule PevSquad.Posts do
  @moduledoc """
  News and articles, written by staff.

  Each post has its text in one or more languages (`Translation`). Readers
  get their own language when it exists, otherwise Indonesian, otherwise
  whatever there is — see `translation_for/2`.

  A post is public once it's `:published` and its `published_at` has passed,
  so a future date schedules it.
  """

  import Ecto.Query, warn: false

  alias PevSquad.Accounts.Scope
  alias PevSquad.Events.Event
  alias PevSquad.Posts.{Images, Post, Translation}
  alias PevSquad.Repo

  @fallback_locale "id"

  ## Translations

  @doc """
  The translation to show for `locale`: that language, else Indonesian,
  else the first one there is. Returns nil only for a post with no text.
  """
  def translation_for(%Post{translations: translations}, locale) when is_list(translations) do
    Enum.find(translations, &(&1.locale == locale)) ||
      Enum.find(translations, &(&1.locale == @fallback_locale)) ||
      List.first(translations)
  end

  @doc "The locales a post has text in."
  def locales(%Post{translations: translations}), do: Enum.map(translations, & &1.locale)

  @doc """
  The card / preview text: the excerpt if there is one, otherwise the
  start of the body with the Markdown stripped.
  """
  def excerpt(%Translation{excerpt: excerpt}) when is_binary(excerpt) and excerpt != "",
    do: excerpt

  def excerpt(%Translation{body: body}) when is_binary(body) do
    body
    |> String.split(~r/\n\s*\n/, trim: true)
    |> Enum.find("", &(not String.starts_with?(String.trim_leading(&1), ["#", "!", "|", "```"])))
    |> plain_text()
    |> truncate(220)
  end

  def excerpt(_translation), do: ""

  defp plain_text(markdown) do
    markdown
    |> String.replace(~r/!\[[^\]]*\]\([^)]*\)/, "")
    |> String.replace(~r/\[([^\]]*)\]\([^)]*\)/, "\\1")
    |> String.replace(~r/[*_`>#~]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp truncate(text, max) do
    if String.length(text) <= max do
      text
    else
      cut = text |> String.slice(0, max) |> String.replace(~r/\s+\S*$/, "")
      cut <> "…"
    end
  end

  @doc "Estimated reading time in whole minutes (200 words a minute, at least 1)."
  def reading_minutes(%Translation{body: body}) when is_binary(body) do
    words = body |> String.split(~r/\s+/, trim: true) |> length()
    max(div(words + 199, 200), 1)
  end

  def reading_minutes(_), do: 1

  ## Public

  @doc """
  Published posts, newest first, with translations.

  Options: `:kind`, `:topic`, `:limit`, `:offset`, `:now`.
  """
  def list_published_posts(opts \\ []) do
    opts
    |> published_query()
    |> order_by([p], desc: p.published_at, desc: p.id)
    |> maybe_limit(opts[:limit])
    |> maybe_offset(opts[:offset])
    |> preload(:translations)
    |> Repo.all()
  end

  @doc "How many posts `list_published_posts/1` would return without a limit."
  def count_published_posts(opts \\ []) do
    opts |> published_query() |> Repo.aggregate(:count)
  end

  @doc "Topics that have at least one published post of this kind, in list order."
  def published_topics(kind, now \\ DateTime.utc_now()) do
    have =
      [kind: kind, now: now]
      |> published_query()
      |> where([p], not is_nil(p.topic))
      |> distinct(true)
      |> select([p], p.topic)
      |> Repo.all()

    Enum.filter(Post.topics(), &(&1 in have))
  end

  @doc "Published posts linked to an event (recaps), newest first."
  def list_event_posts(%Event{id: event_id}, opts \\ []) do
    opts
    |> published_query()
    |> where([p], p.event_id == ^event_id)
    |> order_by([p], desc: p.published_at)
    |> preload(:translations)
    |> Repo.all()
  end

  defp published_query(opts) do
    now = opts[:now] || DateTime.utc_now()

    Post
    |> where([p], p.status == :published and p.published_at <= ^now)
    |> filter(:kind, opts[:kind])
    |> filter(:topic, opts[:topic])
  end

  defp filter(query, _field, nil), do: query
  defp filter(query, field, value), do: where(query, [p], field(p, ^field) == ^value)

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, n), do: limit(query, ^n)

  defp maybe_offset(query, nil), do: query
  defp maybe_offset(query, n), do: offset(query, ^n)

  @doc """
  A post by slug. Drafts and scheduled posts are only visible to staff.
  Preloads translations and the linked event.
  """
  def get_public_post!(scope, slug, now \\ DateTime.utc_now()) do
    post = Post |> where(slug: ^slug) |> preload([:translations, :event]) |> Repo.one!()

    if live?(post, now) or Scope.staff?(scope) do
      post
    else
      raise Ecto.NoResultsError, queryable: Post
    end
  end

  @doc "Whether readers can see the post: published and its date has passed."
  def live?(%Post{status: status, published_at: at}, now \\ DateTime.utc_now()) do
    status == :published and not is_nil(at) and DateTime.compare(at, now) != :gt
  end

  ## Staff

  @doc "Every post for staff, drafts first. Options: `:kind`, `:status`."
  def list_posts_for_staff(%Scope{} = scope, opts \\ []) do
    ensure_staff!(scope)

    Post
    |> filter(:kind, opts[:kind])
    |> filter(:status, opts[:status])
    |> order_by([p], desc_nulls_first: p.published_at, desc: p.inserted_at)
    |> preload(:translations)
    |> Repo.all()
  end

  @doc """
  A post by id (an integer or digit string) or slug, for staff.
  Returns `{:ok, post}` or `{:error, :not_found}`.
  """
  def fetch_post(%Scope{} = scope, id_or_slug) do
    ensure_staff!(scope)

    query =
      case id_or_slug do
        id when is_integer(id) -> where(Post, id: ^id)
        key -> by_id_or_slug(key)
      end

    case query |> preload(:translations) |> Repo.one() do
      nil -> {:error, :not_found}
      post -> {:ok, post}
    end
  end

  defp by_id_or_slug(key) do
    case Integer.parse(key) do
      {id, ""} -> where(Post, id: ^id)
      _ -> where(Post, slug: ^key)
    end
  end

  def get_post!(%Scope{} = scope, id) do
    ensure_staff!(scope)
    Post |> preload(:translations) |> Repo.get!(id)
  end

  @doc """
  A blank post for the admin form, with an empty translation for every
  language so the form shows a tab for each.
  """
  def new_post(kind \\ :news) do
    %Post{kind: kind, translations: []} |> with_all_locales()
  end

  @doc "Adds empty translations for languages the post doesn't have yet."
  def with_all_locales(%Post{translations: translations} = post) do
    have = Enum.map(translations, & &1.locale)

    missing =
      for locale <- Translation.locales(), locale not in have, do: %Translation{locale: locale}

    %{post | translations: Enum.sort_by(translations ++ missing, &locale_order/1)}
  end

  defp locale_order(%{locale: locale}),
    do: Enum.find_index(Translation.locales(), &(&1 == locale)) || 99

  def change_post(%Post{} = post, attrs \\ %{}), do: Post.changeset(post, attrs)

  @doc "`cover_source`, when given, is a path to an uploaded image."
  def create_post(%Scope{} = scope, attrs, cover_source \\ nil) do
    ensure_staff!(scope)

    Repo.transact(fn ->
      %Post{author_id: scope.user.id, translations: []}
      |> Post.changeset(attrs)
      |> unique_generated_slug()
      |> Repo.insert()
      |> attach_cover(cover_source)
    end)
    |> reload()
  end

  def update_post(%Scope{} = scope, %Post{} = post, attrs, cover_source \\ nil) do
    ensure_staff!(scope)

    Repo.transact(fn ->
      post
      |> Post.changeset(attrs)
      |> unique_generated_slug()
      |> Repo.update()
      |> attach_cover(cover_source)
    end)
    |> reload()
  end

  # Recaps share titles ("Ride Recap"), so a generated slug that's taken gets
  # -2, -3… A slug staff typed themselves is left alone and errors instead.
  defp unique_generated_slug(%Ecto.Changeset{} = changeset) do
    typed? = (changeset.params["slug"] || "") != ""

    case Ecto.Changeset.get_change(changeset, :slug) do
      nil -> changeset
      _slug when typed? -> changeset
      slug -> Ecto.Changeset.put_change(changeset, :slug, free_slug(slug, changeset.data.id))
    end
  end

  defp free_slug(base, own_id, n \\ 1) do
    candidate = if n == 1, do: base, else: "#{base}-#{n}"

    taken? =
      Post
      |> where([p], p.slug == ^candidate)
      |> then(fn q -> if own_id, do: where(q, [p], p.id != ^own_id), else: q end)
      |> Repo.exists?()

    if taken?, do: free_slug(base, own_id, n + 1), else: candidate
  end

  # Translations marked :ignore/:delete leave stale structs behind; reload.
  defp reload({:ok, %Post{id: id}}), do: {:ok, Post |> preload(:translations) |> Repo.get!(id)}
  defp reload(error), do: error

  def delete_post(%Scope{} = scope, %Post{} = post) do
    ensure_staff!(scope)

    with {:ok, deleted} <- Repo.delete(post) do
      Images.delete(deleted.cover_path)
      {:ok, deleted}
    end
  end

  def remove_cover(%Scope{} = scope, %Post{} = post) do
    ensure_staff!(scope)
    Images.delete(post.cover_path)
    post |> Ecto.Changeset.change(cover_path: nil) |> Repo.update()
  end

  @doc "Stores an image for use inside a post body. Returns `{:ok, url}`."
  def store_inline_image(%Scope{} = scope, source) do
    ensure_staff!(scope)

    case Images.store(source, "inline") do
      {:ok, url} -> {:ok, url}
      {:error, _} -> {:error, :bad_image}
    end
  end

  defp attach_cover({:ok, post}, nil), do: {:ok, post}

  defp attach_cover({:ok, post}, source) do
    case Images.store(source, post.slug) do
      {:ok, path} ->
        old = post.cover_path

        with {:ok, updated} <- post |> Ecto.Changeset.change(cover_path: path) |> Repo.update() do
          Images.delete(old)
          {:ok, updated}
        end

      {:error, _reason} ->
        Repo.rollback(:bad_image)
    end
  end

  defp attach_cover(error, _source), do: error

  defp ensure_staff!(scope) do
    unless Scope.staff?(scope), do: raise(PevSquad.Posts.NotAuthorizedError)
  end
end

defmodule PevSquad.Posts.NotAuthorizedError do
  defexception message: "only moderators and admins can manage posts", plug_status: 403
end
