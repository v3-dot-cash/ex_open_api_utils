defmodule PhoenixEctoOpenApiDemo.BusinessContext.Business do
  use Ecto.Schema
  use ExOpenApiUtils

  import Ecto.Changeset

  alias PhoenixEctoOpenApiDemo.TenantContext.Business

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
  schema "businesses" do
    open_api_property(
      schema: %Schema{
        type: :string,
        description: "The name of the business",
        example: "ACME Corp"
      },
      key: :name
    )

    field :name, :string
    field :tenant_id, :binary_id

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

    timestamps()
  end

  open_api_schema(
    required: [:name],
    title: "Business",
    description: "The Business",
    properties: [:id, :name, :tenant_name],
    tags: ["business"]
  )

  @doc false
  def changeset(business, attrs) do
    business
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
