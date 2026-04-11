defmodule PhoenixEctoOpenApiDemo.SubscriptionContext.BasicAuth do
  @moduledoc """
  HTTP Basic authentication leaf (level 2) in the nested polymorphic
  subscription tree. Flat — terminates at level 2, alongside `OAuthAuth`
  which has its own level-3 polymorphic children.
  """
  use ExOpenApiUtils

  open_api_property(
    key: :username,
    schema: %Schema{type: :string, example: "alice"}
  )

  open_api_property(
    key: :password,
    schema: %Schema{type: :string, writeOnly: true, example: "s3cret"}
  )

  embedded_schema do
    field :username, :string
    field :password, :string
  end

  open_api_schema(
    title: "BasicAuth",
    description: "HTTP Basic authentication",
    required: [:username, :password],
    properties: [:username, :password]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:username, :password])
    |> validate_required([:username, :password])
  end
end
