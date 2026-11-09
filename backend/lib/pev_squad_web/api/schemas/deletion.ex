defmodule PevSquadWeb.API.Schemas.Deletion do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Deletion",
    type: :object,
    required: [:data],
    properties: %{
      data: %Schema{
        type: :object,
        required: [:profile_alias, :reviews, :photos, :listings, :hosted_rides, :upcoming_rsvps],
        properties: %{
          profile_alias: %Schema{type: :string, nullable: true},
          reviews: %Schema{type: :integer},
          photos: %Schema{type: :integer},
          listings: %Schema{type: :integer},
          hosted_rides: %Schema{type: :integer},
          upcoming_rsvps: %Schema{type: :integer}
        }
      }
    }
  })
end
