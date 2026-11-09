defmodule PevSquadWeb.API.Schemas.Me do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Me",
    type: :object,
    required: [:data],
    properties: %{
      data: %Schema{
        type: :object,
        required: [:id, :email, :role, :locale, :rider_profile],
        properties: %{
          id: %Schema{type: :integer},
          email: %Schema{type: :string, format: :email},
          role: %Schema{type: :string, enum: ~w(member moderator admin)},
          locale: %Schema{
            type: :string,
            enum: ~w(id en),
            nullable: true,
            description: "Saved language for emails; null until the member picks one"
          },
          rider_profile: %Schema{
            type: :object,
            nullable: true,
            required: [:alias, :slug, :status, :avatar_url],
            properties: %{
              alias: %Schema{type: :string},
              slug: %Schema{type: :string},
              status: %Schema{type: :string, enum: ~w(pending active inactive banned)},
              avatar_url: %Schema{type: :string, format: :uri, nullable: true}
            }
          }
        }
      }
    }
  })
end
