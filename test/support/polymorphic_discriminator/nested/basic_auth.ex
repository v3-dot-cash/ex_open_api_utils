defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.BasicAuth do
  @moduledoc false
  use ExOpenApiUtils

  open_api_property(
    key: :username,
    schema: %Schema{type: :string, example: "alice"}
  )

  open_api_property(
    key: :password,
    schema: %Schema{type: :string, writeOnly: true, example: "s3cret"}
  )

  embedded_schema do
    field(:username, :string)
    field(:password, :string)
  end

  open_api_schema(
    title: "BasicAuth",
    description: "HTTP Basic authentication leaf (level 2, flat contrast).",
    required: [:username, :password],
    properties: [:username, :password]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:username, :password])
    |> validate_required([:username, :password])
  end
end
