defmodule PevSquad.Posts.Post do
  @moduledoc """
  A news item or an article. The text is stored per language in
  `PevSquad.Posts.Translation`; a post needs at least one.

  News is dated and short-lived (recaps, announcements, outside news with a
  source). Articles are evergreen (guides, safety, maintenance, stories).
  """
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: PevSquadWeb.Gettext

  alias PevSquad.Accounts.User
  alias PevSquad.Events.Event
  alias PevSquad.Posts.Translation

  @kinds [:news, :article]
  @statuses [:draft, :published]
  @topics [:community, :industry, :regulation, :safety, :maintenance, :guide, :gear, :story]

  schema "posts" do
    field :kind, Ecto.Enum, values: @kinds, default: :news
    field :slug, :string
    field :status, Ecto.Enum, values: @statuses, default: :draft
    field :published_at, :utc_datetime
    field :topic, Ecto.Enum, values: @topics
    field :cover_path, :string
    field :source_name, :string
    field :source_url, :string

    belongs_to :event, Event
    belongs_to :album, PevSquad.Gallery.Album
    belongs_to :author, User
    has_many :translations, Translation, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def kinds, do: @kinds
  def statuses, do: @statuses
  def topics, do: @topics

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :kind,
      :slug,
      :status,
      :published_at,
      :topic,
      :source_name,
      :source_url,
      :event_id,
      :album_id
    ])
    |> validate_required([:kind, :status])
    |> cast_assoc(:translations, with: &Translation.changeset/2)
    |> validate_has_translation()
    |> validate_length(:source_name, max: 80)
    |> validate_url(:source_url)
    |> put_slug()
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/,
      message: dgettext_noop("errors", "use lowercase letters, numbers and dashes")
    )
    |> put_published_at()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:event_id)
    |> foreign_key_constraint(:album_id)
  end

  defp validate_has_translation(changeset) do
    kept =
      changeset
      |> get_assoc(:translations)
      |> Enum.reject(&(&1.action in [:ignore, :delete, :replace]))

    if kept == [] do
      add_error(
        changeset,
        :translations,
        dgettext_noop("errors", "write a title and text in at least one language")
      )
    else
      changeset
    end
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      case URI.parse(value) do
        %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
          []

        _ ->
          [{field, dgettext_noop("errors", "must be a link starting with https://")}]
      end
    end)
  end

  # Generated once from the first title (Indonesian first) and then left
  # alone, so shared links keep working when the title is edited.
  defp put_slug(changeset) do
    with blank when blank in [nil, ""] <- get_field(changeset, :slug),
         title when is_binary(title) <- first_title(changeset),
         slug when slug != "" <- PevSquad.Events.Event.slugify(title, nil) do
      put_change(changeset, :slug, String.slice(slug, 0, 80) |> String.trim_trailing("-"))
    else
      _ -> changeset
    end
  end

  defp first_title(changeset) do
    changeset
    |> get_assoc(:translations, :struct)
    |> Enum.sort_by(&if(&1.locale == "id", do: 0, else: 1))
    |> Enum.find_value(fn t -> if is_binary(t.title) and t.title != "", do: t.title end)
  end

  # Publishing without a date means "now".
  defp put_published_at(changeset) do
    if get_field(changeset, :status) == :published and is_nil(get_field(changeset, :published_at)) do
      put_change(changeset, :published_at, DateTime.utc_now(:second))
    else
      changeset
    end
  end
end
