defmodule PevSquadWeb.API.Schemas.Translation do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Translation",
    type: :object,
    properties: %{
      title: %Schema{type: :string, maxLength: 160},
      excerpt: %Schema{type: :string, maxLength: 300, nullable: true},
      body: %Schema{type: :string, description: "Markdown"},
      machine_translated: %Schema{
        type: :boolean,
        description:
          "Shown as a note on the page. Defaults to true for text sent through the API."
      }
    }
  })
end
