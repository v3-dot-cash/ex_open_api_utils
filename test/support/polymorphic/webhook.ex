defmodule ExOpenApiUtilsTest.Polymorphic.Webhook do
  @moduledoc false
  use ExOpenApiUtils
  alias OpenApiSpex.Schema

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "Webhook target URL",
      format: :uri,
      example: "https://example.com/hooks/123"
    },
    key: :url
  )

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "HTTP method",
      enum: ["GET", "POST", "PUT", "PATCH", "DELETE"],
      example: "POST"
    },
    key: :method
  )

  embedded_schema do
    field(:url, :string)
    field(:method, :string)
  end

  open_api_schema(
    title: "Webhook",
    description: "A webhook channel",
    required: [:url, :method],
    properties: [:url, :method]
  )

  def changeset(schema, attrs) do
    schema
    |> Ecto.Changeset.cast(attrs, [:url, :method])
    |> Ecto.Changeset.validate_required([:url, :method])
  end
end
