defmodule PevSquad.Riders.RiderProfile do
  use Ecto.Schema
  import Ecto.Changeset

  alias PevSquad.Accounts.User

  @pev_types [:euc, :escooter, :esk8, :ebike, :other]
  @statuses [:pending, :active, :inactive, :banned]

  schema "rider_profiles" do
    field :alias, :string
    field :slug, :string
    field :full_name, :string
    field :city, :string
    field :bio, :string
    field :primary_pev_type, Ecto.Enum, values: @pev_types, default: :euc
    field :main_ride, :string
    field :instagram, :string
    field :avatar_path, :string
    field :is_public, :boolean, default: false
    field :featured_since, :utc_datetime
    field :source, Ecto.Enum, values: [:member, :import, :staff], default: :member
    # Staff-only. Profiles members create start pending (hidden, can't post)
    # until staff approve them. Inactive riders stay listed with a badge;
    # banned riders leave the roster but their page shows `ban_reason`.
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :ban_reason, :string
    field :banned_at, :utc_datetime
    # Staff override of the member's own `is_public`.
    field :hidden_by_staff, :boolean, default: false
    # Published partner communities the rider belongs to, in display order.
    # Filled by the Riders context; set by staff via Riders.set_communities/3.
    field :communities, {:array, :any}, virtual: true, default: []

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def pev_types, do: @pev_types
  def statuses, do: @statuses

  @doc "Fields a member edits on their own profile."
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :alias,
      :full_name,
      :city,
      :bio,
      :primary_pev_type,
      :main_ride,
      :instagram,
      :is_public
    ])
    |> validate_required([:alias, :primary_pev_type])
    |> update_change(:alias, &String.trim/1)
    |> validate_length(:alias, min: 2, max: 30)
    |> validate_format(:alias, ~r/^[\p{L}\p{N} ._-]+$/u,
      message: "letters, numbers, spaces, dots, dashes and underscores only"
    )
    |> validate_length(:city, max: 60)
    |> validate_length(:main_ride, max: 80)
    |> validate_length(:bio, max: 500)
    |> update_change(:instagram, &normalize_instagram/1)
    |> validate_format(:instagram, ~r/^[A-Za-z0-9._]{1,30}$/,
      message: "just the handle, e.g. pevsquad"
    )
    |> put_slug()
    |> validate_change(:slug, fn :slug, slug ->
      if slug == "", do: [alias: "needs at least one letter or number"], else: []
    end)
    |> unique_constraint(:alias, message: "is already taken by another rider")
    |> unique_constraint(:slug, message: "is already taken by another rider", error_key: :alias)
    |> unique_constraint(:user_id)
  end

  @doc "Staff-only fields on top of the member ones."
  def staff_changeset(profile, attrs) do
    profile
    |> changeset(attrs)
    |> cast(attrs, [:featured_since, :status, :ban_reason, :hidden_by_staff])
    |> validate_required([:status])
    |> put_ban()
  end

  # A ban needs a public statement and is dated; lifting it clears both.
  defp put_ban(changeset) do
    case get_field(changeset, :status) do
      :banned ->
        changeset
        |> validate_required([:ban_reason], message: "write the public statement for the ban")
        |> validate_length(:ban_reason, max: 1000)
        |> then(fn cs ->
          if get_field(cs, :banned_at),
            do: cs,
            else: put_change(cs, :banned_at, DateTime.utc_now(:second))
        end)

      _ ->
        change(changeset, ban_reason: nil, banned_at: nil)
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
      handle -> handle
    end
  end

  defp put_slug(changeset) do
    case get_change(changeset, :alias) do
      nil -> changeset
      alias_name -> put_change(changeset, :slug, slugify(alias_name))
    end
  end

  def slugify(text) do
    text
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[^a-z0-9\s_.-]/u, "")
    |> String.split(~r/[\s_.-]+/, trim: true)
    |> Enum.join("-")
  end
end
