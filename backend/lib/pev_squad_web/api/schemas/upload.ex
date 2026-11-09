defmodule PevSquadWeb.API.Schemas.Upload do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Upload",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          path: %Schema{type: :string, description: "Site path, use this in Markdown"},
          url: %Schema{type: :string, format: :uri},
          markdown: %Schema{type: :string, example: "![](/uploads/posts/inline-abc.webp)"}
        }
      }
    }
  })
end
