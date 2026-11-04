defmodule PevSquadWeb.PartnerComponents do
  @moduledoc "Partner community and brand partner cards, logos and labels."
  use PevSquadWeb, :html

  alias PevSquad.Partners.Partner

  @doc "Up to two initials for a logo placeholder; blank while a new partner has no name."
  def initials(name) when name in [nil, ""], do: "—"

  def initials(name) do
    case String.split(name) do
      [] -> "—"
      words -> PevSquadWeb.RiderComponents.initials(Enum.join(words, " "))
    end
  end

  @focus_labels %{
    euc: "EUC",
    escooter: "E-Scooter",
    esk8: "Esk8",
    ebike: "E-Bike",
    mixed: "All PEVs"
  }

  def focus_label(nil), do: nil
  def focus_label(focus), do: Map.fetch!(@focus_labels, focus)

  def focus_options, do: Enum.map(Partner.vehicle_focuses(), &{focus_label(&1), &1})

  def kind_label(:community), do: "Partner Community"
  def kind_label(:brand), do: "Brand Partner"

  @doc "\"Surabaya & Malang · EUC\" for communities, \"Sponsor · Venue\" for brands."
  def partner_meta(%Partner{kind: :community} = p),
    do: [p.region, focus_label(p.vehicle_focus)] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")

  def partner_meta(%Partner{kind: :brand} = p),
    do: Enum.map_join(p.collaboration_types, " · ", &Partner.collaboration_label/1)

  def together_label(0), do: nil
  def together_label(1), do: "1 event together"
  def together_label(n), do: "#{n} events together"

  def social_links(%Partner{} = p) do
    [
      p.website && {"Website", p.website},
      p.instagram && {"Instagram", "https://instagram.com/#{p.instagram}"},
      p.tiktok && {"TikTok", "https://www.tiktok.com/@#{p.tiktok}"},
      p.youtube && {"YouTube", p.youtube}
    ]
    |> Enum.reject(&(&1 in [nil, false]))
  end

  @doc "The logo on a white plate, or the partner's initials when there's none."
  attr :partner, Partner, required: true
  attr :class, :string, default: nil

  def partner_logo(assigns) do
    ~H"""
    <div class={["partner-logo", @class]}>
      <img
        :if={@partner.logo_path}
        src={@partner.logo_path}
        alt={"#{@partner.name} logo"}
        loading="lazy"
      />
      <span :if={!@partner.logo_path} class="partner-logo-initials">{initials(@partner.name)}</span>
    </div>
    """
  end

  attr :partner, Partner, required: true

  def partner_card(assigns) do
    ~H"""
    <.link navigate={~p"/partners/#{@partner.slug}"} class="card" style="text-decoration:none;">
      <div class="card-head">
        <span class="card-initials">{initials(@partner.name)}</span>
        <span :if={@partner.kind == :community && @partner.vehicle_focus} class="badge">
          {focus_label(@partner.vehicle_focus)}
        </span>
        <span :if={@partner.kind == :brand} class="badge">Brand</span>
      </div>
      <.partner_logo partner={@partner} />
      <div class="card-body">
        <h3 class="card-title">{@partner.name}</h3>
        <p :if={partner_meta(@partner) != ""} class="card-meta">{partner_meta(@partner)}</p>
        <p :if={@partner.tagline} class="card-desc">{@partner.tagline}</p>
      </div>
      <div :if={@partner.event_count > 0 or @partner.partner_since} class="card-foot">
        <span>{together_label(@partner.event_count)}</span>
        <span :if={@partner.partner_since}>Since {@partner.partner_since.year}</span>
      </div>
    </.link>
    """
  end
end
