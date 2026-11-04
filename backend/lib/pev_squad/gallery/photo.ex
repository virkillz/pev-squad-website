defmodule PevSquad.Gallery.Photo do
  use Ecto.Schema
  import Ecto.Changeset

  schema "photos" do
    field :large_path, :string
    field :thumb_path, :string
    field :width, :integer
    field :height, :integer
    field :title, :string
    field :caption, :string
    field :meta, :string
    field :alt, :string
    field :tile, Ecto.Enum, values: [:normal, :big, :wide], default: :normal
    field :position, :integer, default: 0
    field :status, Ecto.Enum, values: [:pending, :published, :rejected], default: :pending
    # In the home page carousel; featured_at (set automatically) orders it.
    field :featured, :boolean, default: false
    field :featured_at, :utc_datetime

    # Uploader's rider profile, loaded by Gallery queries for credits.
    field :uploader_profile, :any, virtual: true

    belongs_to :album, PevSquad.Gallery.Album
    belongs_to :uploader, PevSquad.Accounts.User
    belongs_to :moderated_by, PevSquad.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc "Text fields anyone uploading can set."
  def details_changeset(photo, attrs) do
    photo
    |> cast(attrs, [:title, :caption, :alt])
    |> validate_length(:title, max: 60)
    |> validate_length(:caption, max: 300)
    |> validate_length(:alt, max: 200)
  end

  @doc "Staff can also set the tile line, size, order and whether it's featured."
  def staff_changeset(photo, attrs) do
    photo
    |> details_changeset(attrs)
    |> cast(attrs, [:meta, :tile, :position, :album_id, :featured])
    |> validate_length(:meta, max: 80)
    |> put_featured_at()
  end

  defp put_featured_at(changeset) do
    case fetch_change(changeset, :featured) do
      {:ok, true} -> put_change(changeset, :featured_at, DateTime.utc_now(:second))
      {:ok, false} -> put_change(changeset, :featured_at, nil)
      :error -> changeset
    end
  end
end
