defmodule PevSquadWeb.API.Schemas.PostInput do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  alias PevSquadWeb.API.Schemas.Translation

  OpenApiSpex.schema(%{
    title: "PostInput",
    type: :object,
    properties: %{
      kind: %Schema{type: :string, enum: ~w(news article), default: "news"},
      slug: %Schema{type: :string, description: "Generated from the Indonesian title if left out"},
      topic: %Schema{
        type: :string,
        enum: ~w(community industry regulation safety maintenance guide gear story),
        nullable: true
      },
      source_name: %Schema{type: :string, nullable: true, description: "For outside news"},
      source_url: %Schema{type: :string, nullable: true},
      event_id: %Schema{
        type: :integer,
        nullable: true,
        description: "Makes it a recap of that event"
      },
      translations: %Schema{
        type: :object,
        description: "Keyed by language (id, en). null deletes a language.",
        additionalProperties: %Schema{oneOf: [Translation], nullable: true}
      }
    },
    example: %{
      "kind" => "news",
      "topic" => "community",
      "translations" => %{
        "id" => %{
          "title" => "Recap Night Ride",
          "body" => "Teks dalam **Markdown**.",
          "machine_translated" => false
        },
        "en" => %{"title" => "Night Ride Recap", "body" => "Text in **Markdown**."}
      }
    }
  })
end
