defmodule PevSquadWeb.API.PublicSchemas do
  @moduledoc """
  OpenAPI schemas for the public read API, registered as named components
  (`#/components/schemas/Event` …) so the app's generated TypeScript types
  get real names. Shapes match `PevSquadWeb.API.PublicJSON`.

  `ref/1` points at a component; `page/1` and `one/1` wrap it in the list
  (`{data, next}`) and single (`{data}`) envelopes.
  """
  alias OpenApiSpex.{Reference, Schema}

  def ref(name), do: %Reference{"$ref": "#/components/schemas/#{name}"}

  def page(name) do
    %Schema{
      type: :object,
      required: [:data, :next],
      properties: %{
        data: %Schema{type: :array, items: ref(name)},
        next: %Schema{
          type: :string,
          nullable: true,
          description: "Pass as ?after= for the next page"
        }
      }
    }
  end

  def one(name),
    do: %Schema{type: :object, required: [:data], properties: %{data: ref(name)}}

  defp str, do: %Schema{type: :string}
  defp str_n, do: %Schema{type: :string, nullable: true}
  defp int, do: %Schema{type: :integer}
  defp int_n, do: %Schema{type: :integer, nullable: true}
  defp bool, do: %Schema{type: :boolean}
  defp time, do: %Schema{type: :string, format: :"date-time"}
  defp time_n, do: %Schema{type: :string, format: :"date-time", nullable: true}
  defp date_n, do: %Schema{type: :string, format: :date, nullable: true}
  defp url_n, do: %Schema{type: :string, format: :uri, nullable: true}
  defp enum(values), do: %Schema{type: :string, enum: Enum.map(values, &to_string/1)}

  defp enum_n(values),
    do: %Schema{type: :string, enum: Enum.map(values, &to_string/1), nullable: true}

  defp list(item), do: %Schema{type: :array, items: item}

  defp obj(props, opts \\ []) do
    %Schema{
      type: :object,
      properties: props,
      required: Keyword.get(opts, :required, Map.keys(props)),
      nullable: Keyword.get(opts, :nullable, false)
    }
  end

  defp merge(%Schema{properties: a, required: ra}, props),
    do: %Schema{
      type: :object,
      properties: Map.merge(a, props),
      required: Enum.uniq(ra ++ Map.keys(props))
    }

  @doc "Every component, for `PevSquadWeb.API.Spec`."
  def components do
    event_kinds = PevSquad.Events.Event.kinds()
    topics = PevSquad.Posts.Post.topics()
    pev_types = [:euc, :escooter, :esk8, :ebike, :other]

    event =
      obj(%{
        id: int(),
        slug: str(),
        title: str(),
        kind: enum(event_kinds),
        category: enum([:official, :group_ride]),
        role: enum([:organizer, :collaborator]),
        status: enum([:published, :cancelled]),
        timezone: str(),
        starts_at: time(),
        ends_at: time_n(),
        local: obj(%{starts_at: str(), ends_at: str_n()}),
        location_name: str_n(),
        capacity: int_n(),
        going_count: int(),
        waitlist_count: int(),
        seats_left: %Schema{type: :integer, nullable: true, description: "null = unlimited"},
        host: obj(%{alias: str(), slug: str_n()}, nullable: true),
        url: str()
      })

    post =
      obj(%{
        id: int(),
        kind: enum([:news, :article]),
        slug: str(),
        topic: enum_n(topics),
        published_at: time(),
        cover_url: url_n(),
        source_name: str_n(),
        source_url: str_n(),
        event_id: int_n(),
        locale: %Schema{
          type: :string,
          description: "Language of title/body: the requested one, else id, else any"
        },
        available_locales: list(str()),
        machine_translated: bool(),
        title: str(),
        excerpt: str(),
        reading_minutes: int(),
        url: str()
      })

    photo =
      obj(%{url: str(), thumb_url: str(), width: int_n(), height: int_n()})

    listing =
      obj(%{
        id: int(),
        title: str(),
        category: enum(PevSquad.Listings.Listing.categories()),
        condition: enum(PevSquad.Listings.Listing.conditions()),
        price_idr: int(),
        negotiable: bool(),
        quantity: int(),
        city: str_n(),
        km: int_n(),
        state: enum([:live, :sold, :expired, :pending, :rejected, :hidden]),
        sold_at: time_n(),
        last_checked_at: time_n(),
        photo: %Schema{allOf: [ref("Photo")], nullable: true},
        seller: obj(%{alias: str(), slug: str_n(), avatar_url: url_n()}, nullable: true),
        url: str()
      })

    partner =
      obj(%{
        id: int(),
        slug: str(),
        kind: enum([:community, :brand]),
        name: str(),
        tagline: str_n(),
        region: str_n(),
        vehicle_focus: str_n(),
        collaboration_types: list(str()),
        partner_since: date_n(),
        logo_url: url_n(),
        event_count: int()
      })

    rider =
      obj(%{
        alias: str(),
        slug: str(),
        city: str_n(),
        primary_pev_type: enum(pev_types),
        main_ride: str_n(),
        status: enum([:active, :inactive, :banned]),
        avatar_url: url_n(),
        communities: list(obj(%{name: str(), slug: str()})),
        url: str()
      })

    album =
      obj(%{
        slug: str(),
        title: str(),
        subtitle: str_n(),
        taken_on: date_n(),
        photo_count: int(),
        open_for_uploads: bool(),
        preview: list(ref("Photo")),
        url: str()
      })

    gallery_photo =
      merge(photo, %{
        id: int(),
        title: str_n(),
        caption: str_n(),
        alt: str_n(),
        tile: enum([:normal, :big, :wide]),
        uploader: obj(%{alias: str()}, nullable: true)
      })

    %{
      "Event" => event,
      "EventDetail" =>
        merge(event, %{
          local: obj(%{starts_at: str(), ends_at: str_n(), rsvp_deadline: str_n()}),
          meeting_point: str_n(),
          description: str_n(),
          rsvp_deadline: time_n(),
          partners_text: str_n(),
          partners: list(ref("Partner")),
          recaps: list(ref("Post"))
        }),
      "Post" => post,
      "PostDetail" =>
        merge(post, %{
          body: %Schema{type: :string, description: "Markdown; links and images are absolute"},
          event: obj(%{id: int(), slug: str(), title: str()}, nullable: true)
        }),
      "Photo" => photo,
      "GalleryPhoto" => gallery_photo,
      "Listing" => listing,
      "ListingDetail" =>
        merge(listing, %{
          description: str_n(),
          photos: list(ref("Photo")),
          contact:
            obj(
              %{
                whatsapp: str_n(),
                whatsapp_url: url_n(),
                instagram: str_n(),
                instagram_url: url_n()
              },
              nullable: true
            ),
          contact_requires_login: bool()
        }),
      "Partner" => partner,
      "PartnerDetail" =>
        merge(partner, %{
          description: str_n(),
          collaboration_note: str_n(),
          links: obj(%{website: str_n(), instagram: str_n(), tiktok: str_n(), youtube: str_n()}),
          events: list(ref("Event"))
        }),
      "Rider" => rider,
      "RiderDetail" => merge(rider, %{bio: str_n(), instagram: str_n()}),
      "Album" => album,
      "AlbumDetail" =>
        obj(%{
          slug: str(),
          title: str(),
          subtitle: str_n(),
          description: str_n(),
          taken_on: date_n(),
          open_for_uploads: bool(),
          photo_count: int(),
          photos: list(ref("GalleryPhoto")),
          url: str()
        }),
      "Community" =>
        obj(%{
          stats: obj(%{riders: int(), cities: int(), meetups_held: int(), rides_upcoming: int()}),
          communities: list(ref("Partner")),
          brands: list(ref("Partner"))
        }),
      "Home" =>
        obj(%{
          next_event: %Schema{allOf: [ref("Event")], nullable: true},
          upcoming: list(ref("Event")),
          posts: list(ref("Post")),
          albums: list(ref("Album")),
          listings: list(ref("Listing"))
        })
    }
  end
end
