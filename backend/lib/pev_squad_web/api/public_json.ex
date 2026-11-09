defmodule PevSquadWeb.API.PublicJSON do
  @moduledoc """
  JSON shapes for the public read API (`/api/v1`, DESIGN.md §7.3).

  One module so every endpoint renders an event, post, listing, rider,
  partner or album the same way. Times are UTC ISO 8601; image and link
  paths are absolute; enums are raw (`"night_ride"`), the app labels them.
  """
  use PevSquadWeb, :verified_routes

  alias PevSquad.{Events, Listings, Posts}
  alias PevSquadWeb.API.Urls

  ## Events

  def event(event) do
    %{
      id: event.id,
      slug: event.slug,
      title: event.title,
      kind: event.kind,
      category: event.category,
      role: event.role,
      status: event.status,
      timezone: event.timezone,
      starts_at: event.starts_at,
      ends_at: event.ends_at,
      local: %{
        starts_at: local(event.starts_at, event.timezone),
        ends_at: local(event.ends_at, event.timezone)
      },
      location_name: event.location_name,
      capacity: event.capacity,
      going_count: event.going_count,
      waitlist_count: event.waitlist_count,
      seats_left: Events.seats_left(event),
      host: host(event),
      url: url(~p"/events/#{event.slug}")
    }
  end

  def event_detail(event, partners, recaps) do
    event
    |> event()
    |> Map.merge(%{
      meeting_point: event.meeting_point,
      description: event.description,
      rsvp_deadline: event.rsvp_deadline,
      local:
        Map.put(
          %{
            starts_at: local(event.starts_at, event.timezone),
            ends_at: local(event.ends_at, event.timezone)
          },
          :rsvp_deadline,
          local(event.rsvp_deadline, event.timezone)
        ),
      partners_text: event.partners,
      partners: Enum.map(partners, &partner/1),
      recaps: Enum.map(recaps, &post(&1, Gettext.get_locale(PevSquadWeb.Gettext)))
    })
  end

  defp host(%{category: :group_ride, host_alias: alias} = event) when is_binary(alias),
    do: %{alias: alias, slug: event.host_slug}

  defp host(_event), do: nil

  defp local(nil, _tz), do: nil
  defp local(dt, tz), do: dt |> DateTime.shift_zone!(tz) |> DateTime.to_iso8601()

  ## Posts

  @doc "A post in `locale`, falling back like the web (`Posts.translation_for/2`)."
  def post(post, locale) do
    t = Posts.translation_for(post, locale)

    %{
      id: post.id,
      kind: post.kind,
      slug: post.slug,
      topic: post.topic,
      published_at: post.published_at,
      cover_url: Urls.absolute(post.cover_path),
      source_name: post.source_name,
      source_url: post.source_url,
      event_id: post.event_id,
      locale: t && t.locale,
      available_locales: Posts.locales(post),
      machine_translated: (t && t.machine_translated) || false,
      title: t && t.title,
      excerpt: t && Posts.excerpt(t),
      reading_minutes: Posts.reading_minutes(t),
      url: post_url(post)
    }
  end

  def post_detail(post, locale) do
    t = Posts.translation_for(post, locale)

    post
    |> post(locale)
    |> Map.merge(%{
      body: t && Urls.absolutize_markdown(t.body),
      event:
        case post.event do
          %Events.Event{} = e -> %{id: e.id, slug: e.slug, title: e.title}
          _ -> nil
        end
    })
  end

  defp post_url(%{kind: :news, slug: slug}), do: url(~p"/news/#{slug}")
  defp post_url(%{kind: :article, slug: slug}), do: url(~p"/articles/#{slug}")

  ## Listings

  def listing(listing) do
    state = Listings.state(listing)

    %{
      id: listing.id,
      title: listing.title,
      category: listing.category,
      condition: listing.condition,
      price_idr: listing.price_idr,
      negotiable: listing.negotiable,
      quantity: listing.quantity,
      city: listing.city,
      km: listing.km,
      state: if(state in [:sold, :sold_archived], do: :sold, else: state),
      sold_at: listing.sold_at,
      last_checked_at: listing.last_checked_at,
      photo: listing.photos |> List.first() |> photo(),
      seller: seller(listing),
      url: url(~p"/for-sale/#{listing.id}")
    }
  end

  @doc """
  `signed_in?`: seller contacts are only for logged-in members, and never
  on a sold listing (same rule as the web page).
  """
  def listing_detail(listing, signed_in?) do
    sold? = Listings.state(listing) in [:sold, :sold_archived]

    listing
    |> listing()
    |> Map.merge(%{
      description: listing.description,
      photos: Enum.map(listing.photos, &photo/1),
      contact:
        if(signed_in? and not sold?,
          do: %{
            whatsapp: listing.whatsapp,
            whatsapp_url: listing.whatsapp && "https://wa.me/#{listing.whatsapp}",
            instagram: listing.instagram,
            instagram_url: listing.instagram && "https://instagram.com/#{listing.instagram}"
          }
        ),
      contact_requires_login: not signed_in? and not sold?
    })
  end

  defp seller(%{seller_profile: %{} = p}) do
    %{
      alias: p.alias,
      # Only link profiles the rider chose to show.
      slug: if(p.is_public and not p.hidden_by_staff, do: p.slug),
      avatar_url: Urls.absolute(p.avatar_path)
    }
  end

  defp seller(_listing), do: nil

  ## Photos (listings and gallery share the large/thumb shape)

  def photo(nil), do: nil

  def photo(photo) do
    %{
      url: Urls.absolute(photo.large_path),
      thumb_url: Urls.absolute(photo.thumb_path),
      width: photo.width,
      height: photo.height
    }
  end

  def gallery_photo(photo) do
    photo
    |> photo()
    |> Map.merge(%{
      id: photo.id,
      title: photo.title,
      caption: photo.caption,
      alt: photo.alt,
      tile: photo.tile,
      uploader: photo_uploader(photo)
    })
  end

  defp photo_uploader(%{uploader_profile: %{alias: alias}}), do: %{alias: alias}
  defp photo_uploader(_photo), do: nil

  ## Riders

  def rider(r) do
    %{
      alias: r.alias,
      slug: r.slug,
      city: r.city,
      primary_pev_type: r.primary_pev_type,
      main_ride: r.main_ride,
      status: r.status,
      avatar_url: Urls.absolute(r.avatar_path),
      communities: Enum.map(r.communities, &%{name: &1.name, slug: &1.slug}),
      url: url(~p"/community/#{r.slug}")
    }
  end

  def rider_detail(r, blocked? \\ false) do
    r
    |> rider()
    |> Map.merge(%{
      id: r.id,
      bio: r.bio,
      instagram: r.instagram,
      has_account: r.user_id != nil,
      blocked: blocked?
    })
  end

  ## Partners

  def partner(p) do
    %{
      id: p.id,
      slug: p.slug,
      kind: p.kind,
      name: p.name,
      tagline: p.tagline,
      region: p.region,
      vehicle_focus: p.vehicle_focus,
      collaboration_types: p.collaboration_types || [],
      partner_since: p.partner_since,
      logo_url: Urls.absolute(p.logo_path),
      event_count: p.event_count
    }
  end

  def partner_detail(p, events) do
    p
    |> partner()
    |> Map.merge(%{
      description: p.description,
      collaboration_note: p.collaboration_note,
      links: %{website: p.website, instagram: p.instagram, tiktok: p.tiktok, youtube: p.youtube},
      events: Enum.map(events, &event/1),
      event_count: length(events)
    })
  end

  ## Albums

  def album(a) do
    %{
      slug: a.slug,
      title: a.title,
      subtitle: a.subtitle,
      taken_on: a.taken_on,
      photo_count: a.photo_count,
      open_for_uploads: a.open_for_uploads,
      preview: Enum.map(a.photos, &photo/1),
      url: url(~p"/gallery/#{a.slug}")
    }
  end

  def album_detail(a) do
    %{
      slug: a.slug,
      title: a.title,
      subtitle: a.subtitle,
      description: a.description,
      taken_on: a.taken_on,
      open_for_uploads: a.open_for_uploads,
      photo_count: length(a.photos),
      photos: Enum.map(a.photos, &gallery_photo/1),
      url: url(~p"/gallery/#{a.slug}")
    }
  end
end
