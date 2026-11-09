defmodule PevSquadWeb.API.Schemas.PartnerList do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "PartnerList",
    type: :object,
    properties: %{
      data: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :integer},
            slug: %Schema{type: :string},
            name: %Schema{type: :string},
            kind: %Schema{type: :string, enum: ~w(community brand)},
            published: %Schema{type: :boolean}
          }
        }
      }
    }
  })
end
