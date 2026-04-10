defmodule PhoenixEctoOpenApiDemo.NotificationContext.Webhook do
  @moduledoc """
  Webhook channel variant for `PhoenixEctoOpenApiDemo.NotificationContext.Notification`.
  """
  use ExOpenApiUtils

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "Webhook target URL",
      format: :uri,
      example: "https://hooks.example.com/123"
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
    field :url, :string
    field :method, :string
  end

  open_api_schema(
    title: "Webhook",
    description: "A webhook channel",
    required: [:url, :method],
    properties: [:url, :method]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:url, :method])
    |> validate_required([:url, :method])
  end
end
