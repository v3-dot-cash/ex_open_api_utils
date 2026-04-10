defmodule ExOpenApiUtilsTest.Polymorphic.Email do
  @moduledoc false
  use ExOpenApiUtils
  alias OpenApiSpex.Schema

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The email recipient",
      format: :email,
      example: "to@example.com"
    },
    key: :to
  )

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The email sender",
      format: :email,
      example: "from@example.com"
    },
    key: :from
  )

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The email body",
      example: "Hello world"
    },
    key: :body
  )

  embedded_schema do
    field(:to, :string)
    field(:from, :string)
    field(:body, :string)
  end

  open_api_schema(
    title: "Email",
    description: "An email channel",
    required: [:to, :from, :body],
    properties: [:to, :from, :body]
  )

  def changeset(schema, attrs) do
    schema
    |> Ecto.Changeset.cast(attrs, [:to, :from, :body])
    |> Ecto.Changeset.validate_required([:to, :from, :body])
  end
end
