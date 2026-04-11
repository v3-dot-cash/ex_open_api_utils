defmodule PhoenixEctoOpenApiDemo.SubscriptionContext.WebhookDestination do
  @moduledoc """
  HTTP webhook delivery destination (level 1) with a polymorphic `:auth`
  field in the nested subscription tree. Intermediate polymorphic parent —
  its `:auth` field holds the inner polymorphic child that failed before
  GH-34 because its nested `:__type__` atom was dropped during
  `Mapper.to_map` on the `:from_open_api` direction.
  """
  use ExOpenApiUtils

  alias PhoenixEctoOpenApiDemo.SubscriptionContext.BasicAuth
  alias PhoenixEctoOpenApiDemo.SubscriptionContext.OAuthAuth

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
    field :url, :string
    field :method, :string

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
    description: "HTTP webhook delivery destination with a polymorphic auth mechanism",
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
