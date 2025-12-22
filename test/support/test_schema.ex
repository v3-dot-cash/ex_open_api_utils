defmodule ExOpenApiUtilsTest.TestSchema do
  use ExOpenApiUtils
  alias OpenApiSpex.Schema

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The id",
      format: :uuid,
      example: "851b18d7-0c88-4095-9969-cbe385926420",
      readOnly: true
    },
    key: :id
  )

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The name",
      example: "Test Name"
    },
    key: :name
  )

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The email",
      example: "test@example.com"
    },
    key: :email
  )

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The tenant id",
      format: :uuid,
      example: "951b18d7-0c88-4095-9969-cbe385926420"
    },
    key: :tenant_id
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "test_schemas" do
    field(:name, :string)
    field(:email, :string)
    field(:tenant_id, :binary_id)
    timestamps()
  end

  open_api_schema(
    required: [:name, :email],
    title: "TestSchema",
    description: "Test Schema for x-order verification",
    tags: ["Test"],
    properties: [:id, :name, :email, :tenant_id]
  )

  def changeset(schema, attrs) do
    schema
    |> Ecto.Changeset.cast(attrs, [:name, :email, :tenant_id])
    |> Ecto.Changeset.validate_required([:name, :email])
  end
end
