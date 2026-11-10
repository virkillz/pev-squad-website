defmodule PevSquadWeb.API.Schemas.AlbumList do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AlbumList",
    type: :object,
    properties: %{
      data: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :integer},
            slug: %Schema{type: :string},
            title: %Schema{type: :string},
            taken_on: %Schema{type: :string, format: :date, nullable: true},
            published: %Schema{type: :boolean},
            photo_count: %Schema{
              type: :integer,
              description: "Every photo, pending ones included"
            },
            event_id: %Schema{type: :integer, nullable: true},
            url: %Schema{
              type: :string,
              format: :uri,
              description: "Public page; 404 until published"
            }
          }
        }
      }
    }
  })
end
