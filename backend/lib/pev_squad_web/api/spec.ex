defmodule PevSquadWeb.API.Spec do
  @moduledoc """
  The OpenAPI document for `/api/v1`, served at `GET /api/v1/openapi`.

  Operations are declared next to each action with `operation/2` (see
  `OpenApiSpex.ControllerSpecs`) and collected from the router here. The
  mobile app generates its TypeScript client from this document.
  """
  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "PEV Squad API",
        version: "1",
        description: """
        JSON API for the PEV Squad mobile app and staff tools.

        Send `Authorization: Bearer <token>`. Pick the language with
        `?locale=id|en` or `Accept-Language` (default Indonesian).
        Errors always look like `{"error": {"code", "message", "fields"?}}`.
        """
      },
      servers: [%Server{url: PevSquadWeb.Endpoint.url()}],
      paths: Paths.from_router(PevSquadWeb.Router),
      components: %Components{
        schemas: PevSquadWeb.API.PublicSchemas.components(),
        securitySchemes: %{
          "bearer" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            description: "Personal API token (`pevsq_…`) from /admin/api-tokens."
          }
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
