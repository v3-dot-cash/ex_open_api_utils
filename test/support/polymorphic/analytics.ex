defmodule ExOpenApiUtilsTest.Polymorphic.Analytics do
  @moduledoc false
  use ExOpenApiUtils
  alias ExOpenApiUtils.Polymorphic
  alias OpenApiSpex.Schema
  import PolymorphicEmbed

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "User id",
      format: :uuid,
      example: "851b18d7-0c88-4095-9969-cbe385926420"
    },
    key: :user_id
  )

  # Custom discriminator field name: :kind instead of :__type__. This exercises
  # the `type_field_name:` option in polymorphic_embeds_one and ensures
  # Polymorphic.one_of/1's discriminator argument flows through correctly.
  open_api_property(
    key: :event,
    schema:
      Polymorphic.one_of(
        discriminator: "kind",
        variants: [
          {"click", ExOpenApiUtilsTest.OpenApiSchema.ClickEventRequest},
          {"pageview", ExOpenApiUtilsTest.OpenApiSchema.PageViewEventRequest}
        ]
      )
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_events" do
    field(:user_id, :binary_id)

    polymorphic_embeds_one(:event,
      types: [
        click: ExOpenApiUtilsTest.Polymorphic.CustomEvent.Click,
        pageview: ExOpenApiUtilsTest.Polymorphic.CustomEvent.PageView
      ],
      type_field_name: :kind,
      on_type_not_found: :raise,
      on_replace: :update
    )
  end

  open_api_schema(
    title: "Analytics",
    description: "An analytics event",
    required: [:user_id, :event],
    properties: [:user_id, :event]
  )

  def changeset(schema, attrs) do
    schema
    |> Ecto.Changeset.cast(attrs, [:user_id])
    |> Ecto.Changeset.validate_required([:user_id])
    |> PolymorphicEmbed.cast_polymorphic_embed(:event, required: true)
  end
end
