defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.ClientCredentialsGrant do
  @moduledoc false
  use ExOpenApiUtils

  open_api_property(
    key: :client_secret,
    schema: %Schema{type: :string, writeOnly: true, example: "sk-example-secret"}
  )

  open_api_property(
    key: :scope,
    schema: %Schema{type: :string, example: "read:events write:webhooks"}
  )

  embedded_schema do
    field(:client_secret, :string)
    field(:scope, :string)
  end

  open_api_schema(
    title: "ClientCredentialsGrant",
    description: "OAuth 2.0 client-credentials grant (level 3 leaf).",
    required: [:client_secret],
    properties: [:client_secret, :scope]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:client_secret, :scope])
    |> validate_required([:client_secret])
  end
end
