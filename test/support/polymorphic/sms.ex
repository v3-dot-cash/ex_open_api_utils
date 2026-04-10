defmodule ExOpenApiUtilsTest.Polymorphic.Sms do
  @moduledoc false
  use ExOpenApiUtils
  alias OpenApiSpex.Schema

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "Phone number in E.164 format",
      example: "+15551234567"
    },
    key: :phone_number
  )

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The sms body",
      example: "Your code is 1234"
    },
    key: :body
  )

  embedded_schema do
    field(:phone_number, :string)
    field(:body, :string)
  end

  open_api_schema(
    title: "Sms",
    description: "An sms channel",
    required: [:phone_number, :body],
    properties: [:phone_number, :body]
  )

  def changeset(schema, attrs) do
    schema
    |> Ecto.Changeset.cast(attrs, [:phone_number, :body])
    |> Ecto.Changeset.validate_required([:phone_number, :body])
  end
end
