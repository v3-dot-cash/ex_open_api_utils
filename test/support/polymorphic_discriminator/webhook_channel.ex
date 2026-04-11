defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.WebhookChannel do
  @moduledoc false
  use ExOpenApiUtils

  open_api_property(
    key: :url,
    schema: %Schema{type: :string, format: :uri, example: "https://hooks.example.com/abc"}
  )

  open_api_property(
    key: :method,
    schema: %Schema{
      type: :string,
      enum: ["GET", "POST", "PUT", "PATCH", "DELETE"],
      example: "POST"
    }
  )

  embedded_schema do
    field(:url, :string)
    field(:method, :string)
  end

  open_api_schema(
    title: "WebhookChannel",
    description: "Webhook delivery variant",
    required: [:url, :method],
    properties: [:url, :method]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:url, :method])
    |> validate_required([:url, :method])
  end
end
