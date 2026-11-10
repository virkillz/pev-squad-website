defmodule PevSquadWeb.API.Schemas.Post do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  alias PevSquadWeb.API.Schemas.Translation

  OpenApiSpex.schema(%{
    title: "Post",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          id: %Schema{type: :integer},
          kind: %Schema{type: :string, enum: ~w(news article)},
          slug: %Schema{type: :string},
          status: %Schema{type: :string, enum: ~w(draft published)},
          published_at: %Schema{type: :string, format: :"date-time", nullable: true},
          topic: %Schema{type: :string, nullable: true},
          cover_url: %Schema{type: :string, format: :uri, nullable: true},
          source_name: %Schema{type: :string, nullable: true},
          source_url: %Schema{type: :string, nullable: true},
          event_id: %Schema{type: :integer, nullable: true},
          album_id: %Schema{type: :integer, nullable: true},
          translations: %Schema{
            type: :object,
            description: "Keyed by language (id, en)",
            additionalProperties: Translation
          },
          url: %Schema{type: :string, format: :uri},
          admin_url: %Schema{type: :string, format: :uri},
          inserted_at: %Schema{type: :string, format: :"date-time"},
          updated_at: %Schema{type: :string, format: :"date-time"}
        }
      }
    }
  })
end
