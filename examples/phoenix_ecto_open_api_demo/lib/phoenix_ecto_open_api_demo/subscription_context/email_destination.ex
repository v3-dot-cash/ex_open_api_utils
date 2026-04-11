defmodule PhoenixEctoOpenApiDemo.SubscriptionContext.EmailDestination do
  @moduledoc """
  Email delivery destination leaf (level 1) in the nested polymorphic
  subscription tree. Flat — provides contrast against `WebhookDestination`
  which has its own nested polymorphic children.
  """
  use ExOpenApiUtils

  open_api_property(
    key: :recipient,
    schema: %Schema{type: :string, format: :email, example: "ops@example.com"}
  )

  embedded_schema do
    field :recipient, :string
  end

  open_api_schema(
    title: "EmailDestination",
    description: "Email delivery destination",
    required: [:recipient],
    properties: [:recipient]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:recipient])
    |> validate_required([:recipient])
  end
end
