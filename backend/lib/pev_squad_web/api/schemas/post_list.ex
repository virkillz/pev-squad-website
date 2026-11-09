defmodule PevSquadWeb.API.Schemas.PostList do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "PostList",
    type: :object,
    description: "Like Post, but translations only carry title and machine_translated.",
    properties: %{data: %Schema{type: :array, items: %Schema{type: :object}}}
  })
end
