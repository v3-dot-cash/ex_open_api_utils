defmodule PhoenixEctoOpenApiDemo.AuditContext.UserLoginEvent do
  @moduledoc """
  User-login variant for `PhoenixEctoOpenApiDemo.AuditContext.AuditEvent`.
  """
  use ExOpenApiUtils

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The authenticated user's identifier",
      example: "u_123"
    },
    key: :user_id
  )

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "Source IP address of the login",
      example: "10.0.0.1"
    },
    key: :ip_address
  )

  embedded_schema do
    field :user_id, :string
    field :ip_address, :string
  end

  open_api_schema(
    title: "UserLoginEvent",
    description: "An audit record emitted on user login",
    required: [:user_id, :ip_address],
    properties: [:user_id, :ip_address]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:user_id, :ip_address])
    |> validate_required([:user_id, :ip_address])
  end
end
