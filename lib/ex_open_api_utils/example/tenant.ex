defmodule ExOpenApiUtils.Example.Tenant do
  use ExOpenApiUtils, [dependencies: [ExOpenApiUtils.Example.User]]
  use Ecto.Schema
  alias ExOpenApiUtils.Property
  alias OpenApiSpex.Schema
  alias ExOpenApiUtils.Example.User
  import Ecto.Changeset



  schema("tenant") do
    @open_api_property %Property{
      schema: %Schema{
        type: :string,
        description: "The name of the tenant",
        minLength: 10,
        example: "organiztion"
      },
      key: :name
    }
    field(:name, :string)

    @open_api_property %Property{
      schema: %Schema{
        type: :array,
        description: "Users belonging to the tenant",
        items: [ExOpenApiUtils.Example.User],
        example: [OpenApiSpex.Schema.example(ExOpenApiUtils.Example.User.OpenApiSchema)]
      },
      key: :users
    }
    has_many(:users, User, foreign_key: :owner_id)
  end

  open_api_schema(required: [:name], title: "Tenant", description: "The tenant")

  def changeset(tenant \\ %__MODULE__{}, attrs) do
    cast(tenant, attrs, [:name])
    |> validate_length(:name, min: @open_api_property[:name][:minLength])
  end
end
