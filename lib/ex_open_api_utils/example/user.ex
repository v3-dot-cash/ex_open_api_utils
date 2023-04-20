defmodule ExOpenApiUtils.Example.User do
  use ExOpenApiUtils
  use Ecto.Schema
  alias OpenApiSpex.Schema

  schema("users") do
    open_api_property(
      schema: %Schema{type: :string, description: "The name of the user", example: "himangshuj"},
      key: :name
    )

    field(:name, :string)
    field(:owner_id, :binary_id)
  end

  open_api_schema(required: [:name], title: "User", description: "The User", tags: ["User"])
end
