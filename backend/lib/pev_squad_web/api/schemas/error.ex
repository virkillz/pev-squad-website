defmodule PevSquadWeb.API.Schemas.Error do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Error",
    type: :object,
    required: [:error],
    properties: %{
      error: %Schema{
        type: :object,
        required: [:code, :message],
        properties: %{
          code: %Schema{
            type: :string,
            enum:
              ~w(unauthorized forbidden reauth_required not_found conflict validation_failed rate_limited bad_request server_error)
          },
          message: %Schema{type: :string, description: "In the request language"},
          fields: %Schema{
            type: :object,
            description: "Only for validation_failed: field name => list of messages",
            additionalProperties: true
          }
        }
      }
    },
    example: %{
      "error" => %{
        "code" => "validation_failed",
        "message" => "Some fields need fixing.",
        "fields" => %{"title" => ["can't be blank"]}
      }
    }
  })
end
