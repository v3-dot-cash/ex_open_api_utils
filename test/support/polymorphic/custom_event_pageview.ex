defmodule ExOpenApiUtilsTest.Polymorphic.CustomEvent.PageView do
  @moduledoc false
  use ExOpenApiUtils
  alias OpenApiSpex.Schema

  open_api_property(
    schema: %Schema{type: :string, description: "The viewed page URL", format: :uri},
    key: :url
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
    |> Ecto.Changeset.cast(attrs, [:url])
    |> Ecto.Changeset.validate_required([:url])
  end
end
