defmodule PevSquadWeb.API.Schemas.Event do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Event",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          id: %Schema{type: :integer},
          title: %Schema{type: :string, maxLength: 120},
          slug: %Schema{type: :string},
          kind: %Schema{
            type: :string,
            enum: Enum.map(PevSquad.Events.Event.kinds(), &Atom.to_string/1)
          },
          role: %Schema{type: :string, enum: ~w(organizer collaborator)},
          timezone: %Schema{type: :string, enum: PevSquad.Events.Event.timezones()},
          location_name: %Schema{type: :string, nullable: true},
          meeting_point: %Schema{type: :string, nullable: true},
          description: %Schema{type: :string, nullable: true},
          capacity: %Schema{type: :integer, nullable: true, description: "null = unlimited"},
          partners: %Schema{
            type: :string,
            nullable: true,
            description: "Free-text names without a partner page"
          },
          category: %Schema{type: :string, enum: ~w(official group_ride)},
          status: %Schema{type: :string, enum: ~w(draft published cancelled hidden)},
          starts_at: %Schema{type: :string, format: :"date-time", description: "UTC"},
          ends_at: %Schema{type: :string, format: :"date-time", nullable: true},
          rsvp_deadline: %Schema{type: :string, format: :"date-time", nullable: true},
          local: %Schema{type: :object, description: "The same times with the event's offset"},
          going_count: %Schema{type: :integer},
          waitlist_count: %Schema{type: :integer},
          host_alias: %Schema{type: :string, nullable: true},
          partner_ids: %Schema{type: :array, items: %Schema{type: :integer}},
          url: %Schema{type: :string, format: :uri},
          admin_url: %Schema{type: :string, format: :uri}
        }
      }
    }
  })
end
