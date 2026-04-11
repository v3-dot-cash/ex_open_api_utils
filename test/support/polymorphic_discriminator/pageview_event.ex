defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.PageViewEvent do
  @moduledoc false
  use ExOpenApiUtils

  open_api_property(
    key: :url,
    schema: %Schema{type: :string, format: :uri, example: "https://example.com/"}
  )

  embedded_schema do
    field(:url, :string)
  end

  open_api_schema(
    title: "PageViewEvent",
    description: "A page view event",
    required: [:url],
    properties: [:url]
  )

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:url])
    |> validate_required([:url])
  end
end
