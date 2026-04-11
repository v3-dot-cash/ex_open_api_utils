defmodule PhoenixEctoOpenApiDemo.SubscriptionContext.OAuthAuth do
  @moduledoc """
  OAuth 2.0 authentication (level 2) with a polymorphic `:grant` field
  in the nested subscription tree. This is the intermediate level-2
  polymorphic parent — the thing that failed before GH-34 because its
  nested `:grant` discriminator was dropped during `Mapper.to_map` on
  the `:from_open_api` direction.
  """
  use ExOpenApiUtils

  alias PhoenixEctoOpenApiDemo.SubscriptionContext.AuthorizationCodeGrant
  alias PhoenixEctoOpenApiDemo.SubscriptionContext.ClientCredentialsGrant

  import PolymorphicEmbed

  open_api_property(
    key: :token_url,
    schema: %Schema{
      type: :string,
      format: :uri,
      example: "https://auth.example.com/oauth/token"
    }
  )

  open_api_property(
    key: :client_id,
    schema: %Schema{type: :string, example: "client-abc-123"}
  )

  open_api_polymorphic_property(
    key: :grant,
    type_field_name: :__type__,
    open_api_discriminator_property: "grant_type",
    variants: [
      client_credentials: ClientCredentialsGrant,
      authorization_code: AuthorizationCodeGrant
    ]
  )

  embedded_schema do
    field :token_url, :string
    field :client_id, :string

    polymorphic_embeds_one(:grant,
      types: [
        client_credentials: ClientCredentialsGrant,
        authorization_code: AuthorizationCodeGrant
      ],
      type_field_name: :__type__,
      on_type_not_found: :raise,
      on_replace: :update
    )
  end

  open_api_schema(
    title: "OAuth",
    description: "OAuth 2.0 authentication with a polymorphic grant type",
    required: [:token_url, :client_id, :grant],
    properties: [:token_url, :client_id, :grant]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:token_url, :client_id])
    |> validate_required([:token_url, :client_id])
    |> cast_polymorphic_embed(:grant, required: true)
  end
end
