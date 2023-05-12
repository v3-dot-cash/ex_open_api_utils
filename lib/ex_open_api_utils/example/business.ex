defmodule ExOpenApiUtils.Example.Business do
  use ExOpenApiUtils
  use Ecto.Schema
  alias OpenApiSpex.Schema
  alias ExOpenApiUtils.Example.Tenant

  schema("businesses") do
    open_api_property(
      schema: %Schema{
        type: :string,
        description: "The name of the business",
        example: "ACME Corp"
      },
      key: :name
    )

    field(:name, :string)
    field(:tenant_id, :binary_id)

    open_api_property(
      schema: ExOpenApiUtils.OpenApiSchema.TenantResponse,
      key: :tenant
    )

    open_api_property(
      schema: %Schema{
        type: :string,
        description: "The name of the business",
        example: "ACME Corp"
      },
      key: :tenant_name,
      source: [:tenant, :name]
    )

    belongs_to(:tenant, Tenant, foreign_key: :tenant_id, define_field: false)
  end

  open_api_schema(
    required: [:name],
    title: "Business",
    description: "The Business",
    tags: ["business"]
  )
end
