defmodule PhoenixEctoOpenApiDemo.SubscriptionContext.Subscription do
  @moduledoc """
  Top-level parent schema (level 0) for event subscriptions with a
  polymorphic `:destination`. Demonstrates the GH-34 nested polymorphic
  support — one of the destination variants (`WebhookDestination`) is
  itself a polymorphic parent with a nested `:auth` field, which in turn
  has a variant (`OAuthAuth`) that's itself a polymorphic parent with a
  `:grant` field. Three stacked `open_api_polymorphic_property` macros.

  Before 0.15.0 this shape failed during `Mapper.to_map` on the
  `:from_open_api` direction: `:__type__` was stamped on the outer
  destination submap but not on the nested auth / grant submaps, so
  `cast_polymorphic_embed/3` at the nested levels raised
  `PolymorphicEmbed.raise_cannot_infer_type_from_data/1`. The fix (Option 3
  self-stamping parent-contextual siblings) makes each parent-contextual
  sibling's Mapper impl stamp its own discriminator atom on its own result
  map from compile-time constants, so nested chains work at arbitrary depth.
  """
  use ExOpenApiUtils

  alias PhoenixEctoOpenApiDemo.SubscriptionContext.EmailDestination
  alias PhoenixEctoOpenApiDemo.SubscriptionContext.WebhookDestination

  import PolymorphicEmbed

  open_api_property(
    key: :id,
    schema: %Schema{
      type: :string,
      format: :uuid,
      example: "b7f4c2a0-1e3d-4a7e-9c6b-8f2d1e5c3a9b",
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
  schema "subscriptions" do
    field :name, :string

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
    description: "Event subscription with a polymorphic delivery destination",
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
