defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.WebhookDestination do
  @moduledoc false
  use ExOpenApiUtils

  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.BasicAuth
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.OAuthAuth

  import PolymorphicEmbed

  open_api_property(
    key: :url,
    schema: %Schema{
      type: :string,
      format: :uri,
      example: "https://hooks.example.com/deliveries"
    }
  )

  open_api_property(
    key: :method,
    schema: %Schema{
      type: :string,
      enum: ["POST", "PUT", "PATCH"],
      example: "POST"
    }
  )

  # GH-38 — full required × nullable matrix for nil-stripping coverage.
  #
  # ┌──────────┬────────────────────────────┬────────────────────────────┐
  # │          │ nullable: false (default)   │ nullable: true             │
  # ├──────────┼────────────────────────────┼────────────────────────────┤
  # │ required │ :url, :method (above)       │ :retry_after               │
  # ├──────────┼────────────────────────────┼────────────────────────────┤
  # │ optional │ :timeout_ms                │ :description               │
  # └──────────┴────────────────────────────┴────────────────────────────┘

  # required, nullable — must be present in payload, can be null
  open_api_property(
    key: :retry_after,
    schema: %Schema{type: :string, nullable: true, description: "Retry-After header value"}
  )

  # optional, non-nullable — nil → omit key (the GH-38 fix case)
  open_api_property(
    key: :timeout_ms,
    schema: %Schema{type: :integer, description: "Request timeout in milliseconds"}
  )

  # optional, nullable — nil → emit key with null
  open_api_property(
    key: :description,
    schema: %Schema{type: :string, nullable: true, description: "Optional webhook description"}
  )

  open_api_polymorphic_property(
    key: :auth,
    type_field_name: :__type__,
    open_api_discriminator_property: "auth_type",
    variants: [
      oauth: OAuthAuth,
      basic: BasicAuth
    ]
  )

  embedded_schema do
    field(:url, :string)
    field(:method, :string)
    field(:retry_after, :string)
    field(:timeout_ms, :integer)
    field(:description, :string)

    polymorphic_embeds_one(:auth,
      types: [
        oauth: OAuthAuth,
        basic: BasicAuth
      ],
      type_field_name: :__type__,
      on_type_not_found: :raise,
      on_replace: :update
    )
  end

  open_api_schema(
    title: "WebhookDestination",
    description: "HTTP webhook delivery destination (level 1 intermediate polymorphic parent).",
    required: [:url, :method, :retry_after, :auth],
    properties: [:url, :method, :retry_after, :timeout_ms, :description, :auth]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:url, :method, :retry_after, :timeout_ms, :description])
    |> validate_required([:url, :method])
    |> cast_polymorphic_embed(:auth, required: true)
  end
end
