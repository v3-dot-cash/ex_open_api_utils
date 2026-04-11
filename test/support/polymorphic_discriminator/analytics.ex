defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.Analytics do
  @moduledoc false
  use ExOpenApiUtils

  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.ClickEvent
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.PageViewEvent

  import PolymorphicEmbed

  open_api_property(
    key: :user_id,
    schema: %Schema{type: :string, format: :uuid}
  )

  # Wire-side discriminator name differs from Ecto-side type_field_name.
  # Wire uses "kind"; polymorphic_embed uses :event_type.
  open_api_polymorphic_property(
    key: :event,
    type_field_name: :event_type,
    open_api_discriminator_property: "kind",
    variants: [
      click: ClickEvent,
      pageview: PageViewEvent
    ]
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "analytics_events" do
    field(:user_id, :binary_id)

    polymorphic_embeds_one(:event,
      types: [
        click: ClickEvent,
        pageview: PageViewEvent
      ],
      type_field_name: :event_type,
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
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
    |> cast_polymorphic_embed(:event, required: true)
  end
end
