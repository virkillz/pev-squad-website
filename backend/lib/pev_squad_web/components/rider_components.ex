defmodule PevSquadWeb.RiderComponents do
  @moduledoc "Rider cards and labels, matching the prototype's community roster."
  use PevSquadWeb, :html

  alias PevSquad.Riders.RiderProfile

  def type_label(:euc), do: "EUC"
  def type_label(:escooter), do: gettext("Scooter")
  def type_label(:esk8), do: "Esk8"
  def type_label(:ebike), do: "E-Bike"
  def type_label(:other), do: gettext("Other")

  def type_options, do: Enum.map(RiderProfile.pev_types(), &{type_label(&1), &1})

  @doc "\"WY\" for Wynn, \"SG\" for Si Ganteng."
  def initials(alias_name) do
    case String.split(alias_name) do
      [one] -> one |> String.slice(0, 2) |> String.upcase()
      [first, second | _] -> String.upcase(String.first(first) <> String.first(second))
    end
  end

  def card_meta(%RiderProfile{} = rider) do
    [rider.city, rider.main_ride]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
    |> String.upcase()
  end

  @doc """
  The home page's rider of the day: a big photo, the alias, what they ride,
  a bit of their bio and a link to the profile, plus a WhatsApp share.
  """
  attr :rider, RiderProfile, required: true
  attr :date, Date, required: true
  attr :share_url, :string, required: true

  def rider_spotlight(assigns) do
    ~H"""
    <section class="band band-orange spotlight" id="rider-of-the-day">
      <div class="spotlight-grid">
        <.link navigate={~p"/community/#{@rider.slug}"} class="spotlight-photo">
          <img
            :if={@rider.avatar_path}
            src={@rider.avatar_path}
            alt={
              gettext("%{rider} with their %{ride}",
                rider: @rider.alias,
                ride: @rider.main_ride || type_label(@rider.primary_pev_type)
              )
            }
            loading="lazy"
          />
          <span :if={!@rider.avatar_path} class="spotlight-initials">{initials(@rider.alias)}</span>
        </.link>
        <div class="spotlight-copy">
          <div class="meta-row">
            <span class="eyebrow">{gettext("Rider of the day")}</span>
            <span class="meta-text">
              {@date |> PevSquadWeb.Locale.strftime("%d %b %Y") |> String.upcase()}
            </span>
          </div>
          <h2 class="spotlight-name">{@rider.alias}</h2>
          <p class="spotlight-meta">
            <span class="badge">{type_label(@rider.primary_pev_type)}</span>
            <span :if={card_meta(@rider) != ""}>{card_meta(@rider)}</span>
          </p>
          <p :if={@rider.bio} class="spotlight-bio">{excerpt(@rider.bio, 320)}</p>
          <div class="hero-actions">
            <.link navigate={~p"/community/#{@rider.slug}"} class="btn btn-solid">
              {gettext("Meet %{rider}", rider: @rider.alias)}
            </.link>
            <a
              href={
                "https://wa.me/?text=" <>
                  URI.encode_www_form(
                    gettext("Rider of the day: %{rider}", rider: @rider.alias) <> " " <> @share_url
                  )
              }
              target="_blank"
              rel="noopener"
              class="btn btn-outline"
              id="share-rider-of-the-day"
            >
              {gettext("Share")}
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp excerpt(text, max) do
    text = text |> String.replace(~r/\s+/, " ") |> String.trim()

    if String.length(text) <= max,
      do: text,
      else: (text |> String.slice(0, max) |> String.replace(~r/\s+\S*$/, "")) <> "…"
  end

  attr :rider, RiderProfile, required: true

  def rider_card(assigns) do
    ~H"""
    <.link navigate={~p"/community/#{@rider.slug}"} class="card" style="text-decoration:none;">
      <div class="card-head">
        <span class="card-initials">{initials(@rider.alias)}</span>
        <span class="flex gap-1">
          <span :if={@rider.status == :inactive} class="badge badge-grey">
            {gettext("Inactive")}
          </span>
          <span class="badge">{type_label(@rider.primary_pev_type)}</span>
        </span>
      </div>
      <img
        :if={@rider.avatar_path}
        class="card-photo"
        src={@rider.avatar_path}
        alt={
          gettext("%{rider} with their %{ride}",
            rider: @rider.alias,
            ride: @rider.main_ride || type_label(@rider.primary_pev_type)
          )
        }
        loading="lazy"
      />
      <div class="card-body">
        <h3 class="card-title">
          {@rider.alias}
        </h3>
        <p class="card-meta">{card_meta(@rider)}</p>
        <%!-- The Squad mark first on every card, then the partner communities they also ride with. --%>
        <div class="rider-communities">
          <span class="rider-community" title="PEV Squad">
            <img src={~p"/images/logo.jpg"} alt={gettext("PEV Squad logo")} loading="lazy" />
          </span>
          <span
            :for={p <- @rider.communities}
            class="rider-community"
            title={p.name}
          >
            <img
              :if={p.logo_path}
              src={p.logo_path}
              alt={gettext("%{name} logo", name: p.name)}
              loading="lazy"
            />
            <span :if={!p.logo_path}>{PevSquadWeb.PartnerComponents.initials(p.name)}</span>
          </span>
        </div>
        <p :if={@rider.bio} class="card-desc">{@rider.bio}</p>
      </div>
    </.link>
    """
  end
end
