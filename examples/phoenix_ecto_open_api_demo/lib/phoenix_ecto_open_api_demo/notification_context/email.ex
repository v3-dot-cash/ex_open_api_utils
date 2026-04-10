defmodule PhoenixEctoOpenApiDemo.NotificationContext.Email do
  @moduledoc """
  Email channel variant for `PhoenixEctoOpenApiDemo.NotificationContext.Notification`.

  `use ExOpenApiUtils` generates `PhoenixEctoOpenApiDemo.OpenApiSchema.EmailRequest`
  and `...EmailResponse` sub-modules, which are referenced from the parent
  `Notification`'s `Polymorphic.one_of/1` call.
  """
  use ExOpenApiUtils

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The email recipient",
      format: :email,
      example: "buyer@example.com"
    },
    key: :to
  )

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The email sender",
      format: :email,
      example: "store@example.com"
    },
    key: :from
  )

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The email body",
      example: "Your order has shipped"
    },
    key: :body
  )

  embedded_schema do
    field :to, :string
    field :from, :string
    field :body, :string
  end

  open_api_schema(
    title: "Email",
    description: "An email channel",
    required: [:to, :from, :body],
    properties: [:to, :from, :body]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:to, :from, :body])
    |> validate_required([:to, :from, :body])
  end
end
