defmodule PhoenixEctoOpenApiDemo.AuditContext.DataExportEvent do
  @moduledoc """
  Data-export variant for `PhoenixEctoOpenApiDemo.AuditContext.AuditEvent`.
  """
  use ExOpenApiUtils

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The resource that was exported",
      example: "users"
    },
    key: :resource
  )

  open_api_property(
    schema: %Schema{
      type: :integer,
      description: "Number of rows exported",
      example: 42
    },
    key: :row_count
  )

  embedded_schema do
    field :resource, :string
    field :row_count, :integer
  end

  open_api_schema(
    title: "DataExportEvent",
    description: "An audit record emitted when data is exported",
    required: [:resource, :row_count],
    properties: [:resource, :row_count]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:resource, :row_count])
    |> validate_required([:resource, :row_count])
  end
end
