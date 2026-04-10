defmodule ExOpenApiUtilsTest.Polymorphic.CustomEvent.Click do
  @moduledoc false
  use ExOpenApiUtils
  alias OpenApiSpex.Schema

  open_api_property(
    schema: %Schema{type: :string, description: "Selector of clicked element"},
    key: :selector
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
    |> Ecto.Changeset.cast(attrs, [:selector])
    |> Ecto.Changeset.validate_required([:selector])
  end
end
