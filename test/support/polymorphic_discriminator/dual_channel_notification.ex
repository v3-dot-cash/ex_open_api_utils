defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.DualChannelNotification do
  @moduledoc """
  GH-47 fixture. Two `open_api_polymorphic_property/1` declarations on the
  same parent, both backed by the same variant pool. Before the GH-47 fix
  this fails compilation under `--warnings-as-errors` with
  `warning: redefining module ExOpenApiUtilsTest.OpenApiSchema.DualChannelNotification<Variant><Direction>`
  because the two decls derived identically-named parent-contextual
  siblings. The fix dedupes generation: each unique target module is
  built once, since the two decls would produce structurally identical
  bodies.
  """
  use ExOpenApiUtils

  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.SmsChannel
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.WebhookChannel

  import PolymorphicEmbed

  open_api_property(
    key: :subject,
    schema: %Schema{type: :string, example: "Order shipped"}
  )

  open_api_polymorphic_property(
    key: :primary_channel,
    type_field_name: :__type__,
    open_api_discriminator_property: "channel_type",
    variants: [
      email: EmailChannel,
      sms: SmsChannel,
      webhook: WebhookChannel
    ]
  )

  open_api_polymorphic_property(
    key: :fallback_channel,
    type_field_name: :__type__,
    open_api_discriminator_property: "channel_type",
    variants: [
      email: EmailChannel,
      sms: SmsChannel,
      webhook: WebhookChannel
    ]
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "dual_channel_notifications" do
    field(:subject, :string)

    polymorphic_embeds_one(:primary_channel,
      types: [email: EmailChannel, sms: SmsChannel, webhook: WebhookChannel],
      type_field_name: :__type__,
      on_type_not_found: :raise,
      on_replace: :update
    )

    polymorphic_embeds_one(:fallback_channel,
      types: [email: EmailChannel, sms: SmsChannel, webhook: WebhookChannel],
      type_field_name: :__type__,
      on_type_not_found: :raise,
      on_replace: :update
    )

    timestamps()
  end

  open_api_schema(
    title: "DualChannelNotification",
    description: "A notification with primary and fallback delivery channels",
    required: [:subject, :primary_channel],
    properties: [:id, :subject, :primary_channel, :fallback_channel],
    tags: ["Notification"]
  )

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:subject])
    |> validate_required([:subject])
    |> cast_polymorphic_embed(:primary_channel, required: true)
    |> cast_polymorphic_embed(:fallback_channel, required: false)
  end
end
