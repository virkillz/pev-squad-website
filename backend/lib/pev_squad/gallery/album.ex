defmodule PevSquad.Gallery.Album do
  use Ecto.Schema
  import Ecto.Changeset

  alias PevSquad.Riders.RiderProfile

  schema "albums" do
    field :title, :string
    field :slug, :string
    field :subtitle, :string
    field :description, :string
    field :taken_on, :date
    field :published, :boolean, default: false
    field :open_for_uploads, :boolean, default: true

    # Filled by Gallery queries.
    field :photo_count, :integer, virtual: true, default: 0

    belongs_to :event, PevSquad.Events.Event
    belongs_to :created_by, PevSquad.Accounts.User
    has_many :photos, PevSquad.Gallery.Photo

    timestamps(type: :utc_datetime)
  end

  def changeset(album, attrs) do
    album
    |> cast(attrs, [
      :title,
      :slug,
      :subtitle,
      :description,
      :taken_on,
      :event_id,
      :published,
      :open_for_uploads
    ])
    |> validate_required([:title])
    |> validate_length(:title, max: 60)
    |> validate_length(:subtitle, max: 80)
    |> put_slug()
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/,
      message: "use lowercase letters, numbers and dashes"
    )
    |> unique_constraint(:slug)
  end

  defp put_slug(changeset) do
    case get_field(changeset, :slug) do
      blank when blank in [nil, ""] ->
        if title = get_field(changeset, :title),
          do: put_change(changeset, :slug, RiderProfile.slugify(title)),
          else: changeset

      _ ->
        changeset
    end
  end
end
