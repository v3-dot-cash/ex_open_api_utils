defmodule PhoenixEctoOpenApiDemo.TenantContext.Tenant do
  use ExOpenApiUtils
  use Ecto.Schema
  import Ecto.Changeset
  alias PhoenixEctoOpenApiDemo.UserContext.User
  alias PhoenixEctoOpenApiDemo.BusinessContext.Business

  @primary_key {:id, :binary_id, autogenerate: true}
  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The id of the tenant",
      format: :uuid,
      example: "851b18d7-0c88-4095-9969-cbe385926420",
      readOnly: true
    },
    key: :id
  )

  @foreign_key_type :binary_id
  schema "tenants" do
    open_api_property(
      schema: %Schema{
        type: :string,
        description: "The name of the tenant",
        minLength: 4,
        example: "organiztion"
      },
      key: :name
    )

    field :name, :string

    open_api_property(
      schema: %Schema{
        type: :array,
        description: "Users belonging to the tenant",
        items: PhoenixEctoOpenApiDemo.OpenApiSchema.UserResponse,
        example: [OpenApiSpex.Schema.example(PhoenixEctoOpenApiDemo.OpenApiSchema.UserResponse)],
        readOnly: true
      },
      key: :users
    )

    open_api_property(
      schema: %Schema{
        type: :array,
        description: "Users belonging to the tenant",
        items: PhoenixEctoOpenApiDemo.OpenApiSchema.UserRequest,
        example: [OpenApiSpex.Schema.example(PhoenixEctoOpenApiDemo.OpenApiSchema.UserRequest)],
        writeOnly: true
      },
      key: :users
    )

    has_many(:users, User, foreign_key: :tenant_id)

    has_many(:businesses, Business, foreign_key: :tenant_id)

    timestamps()
  end

  open_api_schema(
    required: [:name],
    title: "Tenant",
    description: "The Tenant",
    properties: [:name, :users],
    tags: ["Tenant"]
  )

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
