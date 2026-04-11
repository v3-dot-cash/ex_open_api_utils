defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.AuthorizationCodeGrant do
  @moduledoc false
  use ExOpenApiUtils

  open_api_property(
    key: :authorization_code,
    schema: %Schema{type: :string, writeOnly: true, example: "ac_example_code"}
  )

  open_api_property(
    key: :redirect_uri,
    schema: %Schema{
      type: :string,
      format: :uri,
      example: "https://app.example.com/oauth/callback"
    }
  )

  embedded_schema do
    field(:authorization_code, :string)
    field(:redirect_uri, :string)
  end

  open_api_schema(
    title: "AuthorizationCodeGrant",
    description: "OAuth 2.0 authorization-code grant (level 3 leaf).",
    required: [:authorization_code, :redirect_uri],
    properties: [:authorization_code, :redirect_uri]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:authorization_code, :redirect_uri])
    |> validate_required([:authorization_code, :redirect_uri])
  end
end
