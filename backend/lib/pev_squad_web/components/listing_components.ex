defmodule PevSquadWeb.ListingComponents do
  @moduledoc "For Sale cards, prices and labels."
  use PevSquadWeb, :html

  alias PevSquad.Listings
  alias PevSquad.Listings.Listing

  @doc "Rp 12.500.000"
  def price(%Listing{price_idr: 0}), do: gettext("Free")
  def price(%Listing{price_idr: idr}), do: rupiah(idr)

  def rupiah(nil), do: ""

  def rupiah(idr) when is_integer(idr) do
    digits =
      idr
      |> Integer.to_string()
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(".", &Enum.join/1)
      |> String.reverse()

    "Rp " <> digits
  end

  @doc "Path segment for a listing: \"12-inmotion-v11\"."
  def listing_param(%Listing{id: id, title: title}) do
    slug =
      title
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")
      |> String.slice(0, 50)

    if slug == "", do: "#{id}", else: "#{id}-#{slug}"
  end

  def listing_path(listing), do: ~p"/for-sale/#{listing_param(listing)}"

  def category_options, do: Enum.map(Listing.categories(), &{Listing.category_label(&1), &1})
  def condition_options, do: Enum.map(Listing.conditions(), &{Listing.condition_label(&1), &1})

  def seller_name(%Listing{seller_profile: %{alias: alias_name}}), do: alias_name
  def seller_name(_listing), do: "PEV Squad"

  def state_label(:pending), do: gettext("Waiting for review")
  def state_label(:rejected), do: gettext("Needs changes")
  def state_label(:live), do: gettext("Live")
  def state_label(:expired), do: gettext("Expired")
  def state_label(:sold), do: gettext("Sold")
  def state_label(:sold_archived), do: gettext("Sold")
  def state_label(:hidden), do: gettext("Hidden")
  def state_label(:deleted), do: gettext("Deleted")

  @doc "\"today\", \"yesterday\", \"3 days ago\"."
  def days_ago(nil, _now), do: ""

  def days_ago(at, now) do
    case Date.diff(DateTime.to_date(now), DateTime.to_date(at)) do
      d when d <= 0 -> gettext("today")
      1 -> gettext("yesterday")
      d -> ngettext("1 day ago", "%{count} days ago", d)
    end
  end

  @doc "\"in 3 days\", \"tomorrow\", \"today\"."
  def days_left(at, now) do
    case Date.diff(DateTime.to_date(at), DateTime.to_date(now)) do
      d when d <= 0 -> gettext("today")
      1 -> gettext("tomorrow")
      d -> ngettext("in 1 day", "in %{count} days", d)
    end
  end

  attr :listing, Listing, required: true
  attr :now, DateTime, required: true
  attr :sold, :boolean, default: false

  def listing_card(assigns) do
    ~H"""
    <.link
      navigate={listing_path(@listing)}
      class={["card listing-card", @sold && "is-sold"]}
      id={"listing-#{@listing.id}"}
      style="text-decoration:none;"
    >
      <div class="card-head">
        <span class="card-initials">{Listing.category_label(@listing.category)}</span>
        <span class="flex gap-1">
          <span :if={@sold} class="badge">{gettext("Sold")}</span>
          <span :if={!@sold} class="badge badge-grey">
            {Listing.condition_label(@listing.condition)}
          </span>
        </span>
      </div>
      <div class="listing-photo">
        <img
          :if={@listing.photos != []}
          src={hd(@listing.photos).thumb_path}
          alt={@listing.title}
          loading="lazy"
          decoding="async"
        />
        <span :if={length(@listing.photos) > 1} class="photo-num">
          1 / {length(@listing.photos)}
        </span>
      </div>
      <div class="card-body">
        <h3 class="card-title">{@listing.title}</h3>
        <p class="listing-price">
          {price(@listing)}
          <span :if={@listing.negotiable} class="listing-nego">{gettext("nego")}</span>
        </p>
        <p class="card-meta">
          {String.upcase(@listing.city)}{if @listing.quantity > 1,
            do: " · " <> gettext("%{count} units", count: @listing.quantity)}
        </p>
      </div>
      <div class="card-foot">
        <span>{seller_name(@listing)}</span>
        <span :if={@sold}>{gettext("Sold %{when}", when: days_ago(@listing.sold_at, @now))}</span>
        <span :if={!@sold}>
          {gettext("Checked %{when}", when: days_ago(@listing.last_checked_at, @now))}
        </span>
      </div>
    </.link>
    """
  end

  @doc "Why a member can't post yet, with a way forward."
  attr :reason, :atom, required: true

  def sell_blocked(assigns) do
    ~H"""
    <div :if={@reason == :no_profile} class="notice space-y-3" id="needs-profile">
      <p>
        {gettext(
          "Selling is for active PEV Squad members. Set up your rider profile first so buyers know who they're dealing with."
        )}
      </p>
      <.link navigate={~p"/users/profile"} class="btn btn-primary">
        {gettext("Set up my profile")}
      </.link>
    </div>
    <div :if={@reason == :pending} class="notice" id="needs-approval">
      {gettext(
        "Your rider profile is waiting for a moderator to approve it. You can sell once it's approved."
      )}
    </div>
    <div :if={@reason == :inactive} class="notice" id="not-active">
      {gettext("Only active members can sell. Ask a moderator if you think this is a mistake.")}
    </div>
    """
  end

  def fresh_days, do: Listings.fresh_days()
end
