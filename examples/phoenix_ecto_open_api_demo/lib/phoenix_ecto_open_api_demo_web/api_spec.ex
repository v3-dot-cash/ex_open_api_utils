defmodule PhoenixEctoOpenApiDemoWeb.ApiSpec do
  @moduledoc false
  alias OpenApiSpex.{
    Components,
    Info,
    OpenApi,
    Paths,
    SecurityScheme,
    Server,
    Tag
  }

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        # Populate the Server info from a phoenix endpoint
        Server.from_endpoint(PhoenixEctoOpenApiDemoWeb.Endpoint)
      ],
      info: %Info{
        title: to_string(Application.spec(:phoenix_ecto_open_api_demo, :description)),
        version: to_string(Application.spec(:phoenix_ecto_open_api_demo, :vsn))
      },
      components: %Components{
        securitySchemes: %{"BearerAuth" => %SecurityScheme{type: "http", scheme: "Bearer"}}
      },
      security: [%{"BearerAuth" => []}],
      # populate the paths from a phoenix router
      paths: Paths.from_router(PhoenixEctoOpenApiDemoWeb.Router)
    }
    # discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end
