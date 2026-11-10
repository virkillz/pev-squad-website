defmodule PevSquadWeb.API.Schemas.EventInput do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "EventInput",
    type: :object,
    properties: %{
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
      starts_at: %Schema{
        type: :string,
        description:
          "ISO 8601. With an offset (…+07:00, …Z) it's exact; without, it's local to timezone"
      },
      ends_at: %Schema{type: :string, nullable: true},
      rsvp_deadline: %Schema{type: :string, nullable: true},
      partner_ids: %Schema{
        type: :array,
        items: %Schema{type: :integer},
        description: "Replaces linked partners"
      },
      album_ids: %Schema{
        type: :array,
        items: %Schema{type: :integer},
        description:
          "Replaces linked gallery albums (GET /admin/albums). An album belongs to one event, so this moves it"
      }
    },
    example: %{
      "title" => "Night Ride Sudirman",
      "kind" => "night_ride",
      "starts_at" => "2026-11-28T20:00",
      "timezone" => "Asia/Jakarta",
      "location_name" => "FX Sudirman",
      "capacity" => 40
    }
  })
end
