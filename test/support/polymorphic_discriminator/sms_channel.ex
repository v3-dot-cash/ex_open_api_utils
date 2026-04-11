defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.SmsChannel do
  @moduledoc false
  use ExOpenApiUtils

  open_api_property(
    key: :phone_number,
    schema: %Schema{type: :string, example: "+15551234567"}
  )

  open_api_property(
    key: :body,
    schema: %Schema{type: :string, example: "Your code is 4242"}
  )

  embedded_schema do
    field(:phone_number, :string)
    field(:body, :string)
  end

  open_api_schema(
    title: "SmsChannel",
    description: "SMS delivery variant",
    required: [:phone_number, :body],
    properties: [:phone_number, :body]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:phone_number, :body])
    |> validate_required([:phone_number, :body])
  end
end
