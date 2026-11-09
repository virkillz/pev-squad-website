defmodule PevSquadWeb.API.Schemas.FileUpload do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "FileUpload",
    type: :object,
    required: [:file],
    properties: %{file: %Schema{type: :string, format: :binary}}
  })
end
