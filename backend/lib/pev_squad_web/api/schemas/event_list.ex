defmodule PevSquadWeb.API.Schemas.EventList do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "EventList",
    type: :object,
    description: "Like Event, without partner_ids.",
    properties: %{data: %Schema{type: :array, items: %Schema{type: :object}}}
  })
end
