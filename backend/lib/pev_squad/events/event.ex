defmodule PevSquad.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  alias PevSquad.Accounts.User
  alias PevSquad.Events.Rsvp

  @kinds [
    :ride,
    :night_ride,
    :trail_ride,
    :tour,
    :getaway,
    :expedition,
    :race,
    :meetup,
    :clinic,
    :collab,
    :collab_ride,
    :brand_invite,
    :brand_activation,
    :media,
    :exhibition,
    :marshal
  ]
  @roles [:organizer, :collaborator]
  @statuses [:draft, :published, :cancelled]

  schema "events" do
    field :title, :string
    field :slug, :string
    field :kind, Ecto.Enum, values: @kinds, default: :ride
    field :role, Ecto.Enum, values: @roles, default: :organizer
    field :partners, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :timezone, :string, default: "Asia/Jakarta"
    field :location_name, :string
    field :meeting_point, :string
    field :description, :string
    # nil = unlimited. When set, RSVPs past this number go to the waitlist.
    field :capacity, :integer
    field :rsvp_deadline, :utc_datetime
    field :status, Ecto.Enum, values: @statuses, default: :draft

    # Filled by Events queries, not stored.
    field :going_count, :integer, virtual: true, default: 0
    field :waitlist_count, :integer, virtual: true, default: 0

    belongs_to :created_by, User
    has_many :rsvps, Rsvp

    timestamps(type: :utc_datetime)
  end

  def kinds, do: @kinds
  def roles, do: @roles
  def statuses, do: @statuses

  # Indonesia spans three zones; events outside Java/Sumatra need the others.
  def timezones, do: ["Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura"]

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :title,
      :slug,
      :kind,
      :role,
      :partners,
      :starts_at,
      :ends_at,
      :timezone,
      :location_name,
      :meeting_point,
      :description,
      :capacity,
      :rsvp_deadline,
      :status
    ])
    |> validate_required([:title, :kind, :role, :starts_at, :timezone, :status])
    |> validate_length(:title, max: 120)
    |> validate_inclusion(:timezone, timezones())
    |> validate_number(:capacity, greater_than: 0)
    |> put_slug()
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/,
      message: "use lowercase letters, numbers and dashes"
    )
    |> validate_ends_after_start()
    |> unique_constraint(:slug)
    |> check_constraint(:capacity, name: :capacity_positive)
  end

  defp put_slug(changeset) do
    case get_field(changeset, :slug) do
      blank when blank in [nil, ""] ->
        case get_field(changeset, :title) do
          nil -> changeset
          title -> put_change(changeset, :slug, slugify(title, get_field(changeset, :starts_at)))
        end

      _slug ->
        changeset
    end
  end

  @doc """
  Builds a URL slug from the title, suffixed with the year so recurring rides
  ("Tacobell Ride") don't collide.
  """
  def slugify(title, starts_at) do
    base =
      title
      |> String.downcase()
      |> String.replace(~r/[–—→\/]/u, " ")
      |> String.normalize(:nfd)
      |> String.replace(~r/[^a-z0-9\s-]/u, "")
      |> String.split(~r/[\s-]+/, trim: true)
      |> Enum.join("-")

    case starts_at do
      %DateTime{year: year} -> "#{base}-#{year}"
      _ -> base
    end
  end

  defp validate_ends_after_start(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if starts_at && ends_at && DateTime.compare(ends_at, starts_at) == :lt do
      add_error(changeset, :ends_at, "must be after the start")
    else
      changeset
    end
  end
end
