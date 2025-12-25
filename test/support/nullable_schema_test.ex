defmodule ExOpenApiUtilsTest.NullableSchemaTest do
  use ExOpenApiUtils
  alias OpenApiSpex.Schema

  open_api_property(
    key: :name,
    schema: %Schema{
      type: :string,
      description: "Name field"
    }
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "nullable_schemas" do
    field(:name, :string)
    timestamps()
  end

  open_api_schema(
    required: [:name],
    title: "NullableSchema",
    description: "A schema that can be null",
    properties: [:name],
    nullable: true
  )
end
