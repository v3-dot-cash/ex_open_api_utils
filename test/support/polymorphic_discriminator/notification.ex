defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.Notification do
  @moduledoc false
  use ExOpenApiUtils

  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.SmsChannel
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.WebhookChannel

  import PolymorphicEmbed

  open_api_property(
    key: :id,
    schema: %Schema{
      type: :string,
      format: :uuid,
      example: "851b18d7-0c88-4095-9969-cbe385926420",
      readOnly: true
    }
  )

  open_api_property(
    key: :subject,
    schema: %Schema{type: :string, example: "Your order has shipped"}
  )

  open_api_polymorphic_property(
    key: :channel,
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
  schema "notifications" do
    field(:subject, :string)

    polymorphic_embeds_one(:channel,
      types: [
        email: EmailChannel,
        sms: SmsChannel,
        webhook: WebhookChannel
      ],
      type_field_name: :__type__,
      on_type_not_found: :raise,
      on_replace: :update
    )

    timestamps()
  end

  open_api_schema(
    title: "Notification",
    description: "An outbound notification",
    required: [:subject, :channel],
    properties: [:id, :subject, :channel],
    tags: ["Notification"]
  )

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:subject])
    |> validate_required([:subject])
    |> cast_polymorphic_embed(:channel, required: true)
  end
end
