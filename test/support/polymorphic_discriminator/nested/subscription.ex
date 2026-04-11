defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.Subscription do
  @moduledoc false
  use ExOpenApiUtils

  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.EmailDestination
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.WebhookDestination

  import PolymorphicEmbed

  open_api_property(
    key: :id,
    schema: %Schema{
      type: :string,
      format: :uuid,
      example: "3f7d8c7a-3c3b-4c2d-9c5a-3f7d8c7a3c3b",
      readOnly: true
    }
  )

  open_api_property(
    key: :name,
    schema: %Schema{type: :string, example: "Order events subscription"}
  )

  open_api_polymorphic_property(
    key: :destination,
    type_field_name: :__type__,
    open_api_discriminator_property: "destination_type",
    variants: [
      webhook: WebhookDestination,
      email: EmailDestination
    ]
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "nested_subscriptions" do
    field(:name, :string)

    polymorphic_embeds_one(:destination,
      types: [
        webhook: WebhookDestination,
        email: EmailDestination
      ],
      type_field_name: :__type__,
      on_type_not_found: :raise,
      on_replace: :update
    )

    timestamps()
  end

  open_api_schema(
    title: "Subscription",
    description: "Event subscription with a polymorphic destination (level 0 top-level parent).",
    required: [:name, :destination],
    properties: [:id, :name, :destination],
    tags: ["Subscription"]
  )

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> cast_polymorphic_embed(:destination, required: true)
  end
end
