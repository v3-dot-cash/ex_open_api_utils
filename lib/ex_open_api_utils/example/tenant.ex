defmodule ExOpenApiUtils.Example.Tenant do
  use ExOpenApiUtils
  use Ecto.Schema
  alias OpenApiSpex.Schema
  alias ExOpenApiUtils.Example.User

  schema("tenants") do
    open_api_property(
      schema: %Schema{
        type: :string,
        description: "The name of the tenant",
        minLength: 10,
        example: "organiztion"
      },
      key: :name
    )

    field(:name, :string)

    open_api_property(
      schema: %Schema{
        type: :array,
        description: "Users belonging to the tenant",
        items: ExOpenApiUtils.OpenApiSchema.UserResponse,
        example: [OpenApiSpex.Schema.example(ExOpenApiUtils.OpenApiSchema.UserResponse)],
      },
      key: :users
    )

    has_many(:users, User, foreign_key: :owner_id)
  end

  open_api_schema(required: [:name], title: "Tenant", description: "The Tenant", tags: ["Tenant"])
end
