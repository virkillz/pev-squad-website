defmodule PevSquad.Reviews.PevModel do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: PevSquadWeb.Gettext

  alias PevSquad.Riders.RiderProfile

  schema "pev_models" do
    field :pev_type, Ecto.Enum, values: RiderProfile.pev_types()
    field :brand, :string
    field :name, :string
    field :slug, :string
    field :approved, :boolean, default: false

    belongs_to :created_by, PevSquad.Accounts.User
    has_many :reviews, PevSquad.Reviews.Review

    timestamps(type: :utc_datetime)
  end

  def changeset(model, attrs) do
    model
    |> cast(attrs, [:pev_type, :brand, :name])
    |> validate_required([:pev_type, :brand, :name])
    |> update_change(:brand, &String.trim/1)
    |> update_change(:name, &String.trim/1)
    |> validate_length(:brand, max: 40)
    |> validate_length(:name, max: 60)
    |> put_slug()
    |> unique_constraint(:slug,
      error_key: :name,
      message: dgettext_noop("errors", "is already in the catalog")
    )
    |> unique_constraint([:brand, :name],
      name: :pev_models_brand_name_index,
      error_key: :name,
      message: dgettext_noop("errors", "is already in the catalog")
    )
  end

  def staff_changeset(model, attrs) do
    model |> changeset(attrs) |> cast(attrs, [:approved])
  end

  def full_name(%__MODULE__{brand: brand, name: name}), do: "#{brand} #{name}"

  defp put_slug(changeset) do
    brand = get_field(changeset, :brand)
    name = get_field(changeset, :name)

    if brand && name && (changed?(changeset, :brand) or changed?(changeset, :name)) do
      put_change(changeset, :slug, RiderProfile.slugify("#{brand} #{name}"))
    else
      changeset
    end
  end
end
