defmodule PevSquad.Listings.Listing do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: PevSquadWeb.Gettext

  alias PevSquad.Accounts.User
  alias PevSquad.Listings.ListingPhoto

  @categories [:euc, :escooter, :esk8, :ebike, :parts, :gear, :other]
  @conditions [:new, :like_new, :used, :for_parts]
  @max_photos 5

  # Changing any of these on an approved listing sends it back to the queue.
  # Price, quantity, city and contact details can change freely.
  @reviewed_fields [:title, :category, :condition, :description, :photos]

  schema "listings" do
    field :kind, Ecto.Enum, values: [:member, :official], default: :member
    field :title, :string
    field :category, Ecto.Enum, values: @categories
    field :condition, Ecto.Enum, values: @conditions
    field :price_idr, :integer
    field :negotiable, :boolean, default: false
    field :quantity, :integer, default: 1
    field :city, :string
    field :km, :integer
    field :description, :string
    field :whatsapp, :string
    field :instagram, :string
    embeds_many :photos, ListingPhoto, on_replace: :delete

    field :status, Ecto.Enum, values: [:pending, :approved, :rejected], default: :pending
    field :rejection_reason, :string
    field :approved_at, :utc_datetime
    field :last_checked_at, :utc_datetime
    field :reminded_at, :utc_datetime
    field :sold_at, :utc_datetime
    field :hidden_at, :utc_datetime
    field :deleted_at, :utc_datetime

    # Filled by the Listings context.
    field :seller_profile, :any, virtual: true

    belongs_to :seller, User
    belongs_to :moderated_by, User

    timestamps(type: :utc_datetime)
  end

  def categories, do: @categories
  def conditions, do: @conditions
  def max_photos, do: @max_photos
  def reviewed_fields, do: @reviewed_fields

  def category_label(:euc), do: gettext("EUC")
  def category_label(:escooter), do: gettext("E-scooter")
  def category_label(:esk8), do: gettext("E-skateboard")
  def category_label(:ebike), do: gettext("E-bike")
  def category_label(:parts), do: gettext("Parts")
  def category_label(:gear), do: gettext("Safety gear")
  def category_label(:other), do: gettext("Other")

  def condition_label(:new), do: gettext("New")
  def condition_label(:like_new), do: gettext("Like new")
  def condition_label(:used), do: gettext("Used")
  def condition_label(:for_parts), do: gettext("For parts")

  @doc "Fields the seller fills in. Photos are set by the context."
  def changeset(listing, attrs) do
    listing
    |> cast(normalize_numbers(attrs), [
      :title,
      :category,
      :condition,
      :price_idr,
      :negotiable,
      :quantity,
      :city,
      :km,
      :description,
      :whatsapp,
      :instagram
    ])
    |> update_change(:title, &String.trim/1)
    |> update_change(:city, &String.trim/1)
    |> update_change(:whatsapp, &normalize_whatsapp/1)
    |> update_change(:instagram, &normalize_instagram/1)
    |> validate_required([:title, :category, :condition, :price_idr, :quantity, :city])
    |> validate_required(:description, message: dgettext_noop("errors", "tell buyers about it"))
    |> validate_length(:title, min: 3, max: 80)
    |> validate_length(:city, max: 60)
    |> validate_length(:description, max: 4000)
    |> validate_number(:price_idr, greater_than_or_equal_to: 0, less_than: 10_000_000_000)
    |> validate_number(:quantity, greater_than: 0, less_than_or_equal_to: 999)
    |> validate_number(:km, greater_than_or_equal_to: 0, less_than: 1_000_000)
    |> validate_format(:whatsapp, ~r/^62\d{8,13}$/,
      message: dgettext_noop("errors", "use an Indonesian number, e.g. 0812 3456 7890")
    )
    |> validate_format(:instagram, ~r/^[A-Za-z0-9._]{1,30}$/,
      message: dgettext_noop("errors", "use your handle, e.g. pevsquad")
    )
    |> validate_contact()
  end

  @doc """
  Sets the photo list (already processed files). Leaves it alone when it's
  the same list, so an unchanged edit doesn't count as a photo change.
  """
  def photos_changeset(changeset, photos) do
    changeset =
      if photos == changeset.data.photos,
        do: changeset,
        else: put_embed(changeset, :photos, photos)

    if length(photos) in 1..@max_photos//1 do
      changeset
    else
      add_error(changeset, :photos, dgettext_noop("errors", "add 1 to 5 photos"))
    end
  end

  defp validate_contact(changeset) do
    if get_field(changeset, :whatsapp) || get_field(changeset, :instagram) do
      changeset
    else
      add_error(
        changeset,
        :whatsapp,
        dgettext_noop("errors", "add a WhatsApp number or an Instagram handle")
      )
    end
  end

  # Sellers type "12.500.000" or "Rp 12.500.000"; keep the digits.
  defp normalize_numbers(attrs) when is_map(attrs) do
    Enum.reduce(["price_idr", "km"], attrs, fn key, acc ->
      case acc do
        %{^key => value} when is_binary(value) ->
          Map.put(acc, key, String.replace(value, ~r/[^\d]/, ""))

        _ ->
          acc
      end
    end)
  end

  # "0812-3456 7890", "+62 812…", "62812…" all become "62812…".
  defp normalize_whatsapp(nil), do: nil

  defp normalize_whatsapp(number) do
    case String.replace(number, ~r/[^\d]/, "") do
      "" -> nil
      "0" <> rest -> "62" <> rest
      "8" <> _ = local -> "62" <> local
      digits -> digits
    end
  end

  defp normalize_instagram(nil), do: nil

  defp normalize_instagram(handle) do
    handle
    |> String.trim()
    |> String.replace(~r{^(https?://)?(www\.)?instagram\.com/}, "")
    |> String.trim_leading("@")
    |> String.trim_trailing("/")
    |> case do
      "" -> nil
      h -> h
    end
  end
end
