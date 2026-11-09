defmodule PevSquad.Partners.Partner do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: PevSquadWeb.Gettext

  @kinds [:community, :brand]
  @vehicle_focuses [:euc, :escooter, :esk8, :ebike, :mixed]
  @collaboration_types [
    sponsor: gettext_noop("Sponsor"),
    dealer: gettext_noop("Dealer"),
    gear: gettext_noop("Gear & parts"),
    venue: gettext_noop("Venue"),
    food_drink: gettext_noop("Food & drink"),
    media: gettext_noop("Media"),
    event_partner: gettext_noop("Event partner")
  ]

  schema "partners" do
    field :kind, Ecto.Enum, values: @kinds
    field :name, :string
    field :slug, :string
    field :tagline, :string
    field :description, :string
    field :logo_path, :string
    field :region, :string
    field :vehicle_focus, Ecto.Enum, values: @vehicle_focuses

    field :collaboration_types, {:array, Ecto.Enum},
      values: Keyword.keys(@collaboration_types),
      default: []

    field :collaboration_note, :string
    field :partner_since, :date
    field :website, :string
    field :instagram, :string
    field :tiktok, :string
    field :youtube, :string
    field :published, :boolean, default: true
    field :position, :integer, default: 0
    # Filled by Partners.list_partners/1.
    field :event_count, :integer, virtual: true, default: 0

    many_to_many :events, PevSquad.Events.Event, join_through: "event_partners"

    timestamps(type: :utc_datetime)
  end

  def kinds, do: @kinds
  def vehicle_focuses, do: @vehicle_focuses

  def collaboration_types,
    do: Enum.map(@collaboration_types, fn {k, label} -> {k, translate(label)} end)

  def collaboration_label(type), do: @collaboration_types |> Keyword.fetch!(type) |> translate()

  defp translate(label), do: Gettext.gettext(PevSquadWeb.Gettext, label)

  def changeset(partner, attrs) do
    partner
    |> cast(attrs, [
      :kind,
      :name,
      :slug,
      :tagline,
      :description,
      :region,
      :vehicle_focus,
      :collaboration_types,
      :collaboration_note,
      :partner_since,
      :website,
      :instagram,
      :tiktok,
      :youtube,
      :published,
      :position
    ])
    |> validate_required([:kind, :name])
    |> validate_length(:name, max: 80)
    |> validate_length(:tagline, max: 160)
    |> update_change(:instagram, &handle/1)
    |> update_change(:tiktok, &handle/1)
    |> validate_format(:website, ~r{^https?://\S+$},
      message: dgettext_noop("errors", "must start with http:// or https://")
    )
    |> validate_format(:youtube, ~r{^https?://\S+$},
      message: dgettext_noop("errors", "paste the full channel link (https://youtube.com/@…)")
    )
    |> put_slug()
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/,
      message: dgettext_noop("errors", "use lowercase letters, numbers and dashes")
    )
    |> unique_constraint(:slug)
  end

  # Members paste "@rejs.id", "rejs.id" or the full profile link.
  defp handle(nil), do: nil

  defp handle(value) do
    value
    |> String.trim()
    |> String.replace(~r{^https?://(www\.)?(instagram|tiktok)\.com/}, "")
    |> String.trim_leading("@")
    |> String.trim_trailing("/")
    |> case do
      "" -> nil
      handle -> handle
    end
  end

  defp put_slug(changeset) do
    case {get_field(changeset, :slug), get_field(changeset, :name)} do
      {blank, name} when blank in [nil, ""] and is_binary(name) ->
        put_change(changeset, :slug, PevSquad.Events.Event.slugify(name, nil))

      _ ->
        changeset
    end
  end
end
