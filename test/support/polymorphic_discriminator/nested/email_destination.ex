defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.EmailDestination do
  @moduledoc false
  use ExOpenApiUtils

  open_api_property(
    key: :recipient,
    schema: %Schema{type: :string, format: :email, example: "ops@example.com"}
  )

  embedded_schema do
    field(:recipient, :string)
  end

  open_api_schema(
    title: "EmailDestination",
    description: "Email delivery destination leaf (level 1, flat contrast).",
    required: [:recipient],
    properties: [:recipient]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:recipient])
    |> validate_required([:recipient])
  end
end
