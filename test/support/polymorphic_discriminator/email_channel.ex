defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel do
  @moduledoc false
  use ExOpenApiUtils

  open_api_property(
    key: :to,
    schema: %Schema{type: :string, format: :email, example: "to@example.com"}
  )

  open_api_property(
    key: :from,
    schema: %Schema{type: :string, format: :email, example: "from@example.com"}
  )

  open_api_property(
    key: :body,
    schema: %Schema{type: :string, example: "Hello"}
  )

  embedded_schema do
    field(:to, :string)
    field(:from, :string)
    field(:body, :string)
  end

  open_api_schema(
    title: "EmailChannel",
    description: "Email delivery variant",
    required: [:to, :from, :body],
    properties: [:to, :from, :body]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:to, :from, :body])
    |> validate_required([:to, :from, :body])
  end
end
