defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.ClickEvent do
  @moduledoc false
  use ExOpenApiUtils

  open_api_property(
    key: :selector,
    schema: %Schema{type: :string, example: "#submit-btn"}
  )

  embedded_schema do
    field(:selector, :string)
  end

  open_api_schema(
    title: "ClickEvent",
    description: "A click event",
    required: [:selector],
    properties: [:selector]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:selector])
    |> validate_required([:selector])
  end
end
