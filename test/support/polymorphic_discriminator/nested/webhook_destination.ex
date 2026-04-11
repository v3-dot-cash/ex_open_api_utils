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
    required: [:url, :method, :auth],
    properties: [:url, :method, :auth]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:url, :method])
    |> validate_required([:url, :method])
    |> cast_polymorphic_embed(:auth, required: true)
  end
end
