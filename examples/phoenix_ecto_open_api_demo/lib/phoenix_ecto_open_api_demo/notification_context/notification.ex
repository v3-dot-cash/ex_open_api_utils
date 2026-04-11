defmodule PhoenixEctoOpenApiDemo.NotificationContext.Notification do
  @moduledoc """
  Parent schema for an outbound notification with a polymorphic `:channel`.

  The polymorphism is declared in one call to `open_api_polymorphic_property/1`:
  the macro bridges `polymorphic_embeds_one`'s `type_field_name:` (Ecto atom)
  with the OpenAPI wire discriminator (string), and the library auto-generates
  one parent-contextual variant submodule per `(parent, variant, direction)`
  triple at compile time via `allOf` composition. The generated siblings
  (e.g. `NotificationEmailRequest` / `NotificationEmailResponse`) carry the
  discriminator as a real `defstruct` field so `Kernel.struct/2` preserves it
  through the cast pipeline.

  Variants (`Email`, `Sms`, `Webhook`) are plain `use ExOpenApiUtils` embedded
  schemas — they know nothing about being part of a discriminated union.
  """
  use ExOpenApiUtils

  alias PhoenixEctoOpenApiDemo.NotificationContext.Email
  alias PhoenixEctoOpenApiDemo.NotificationContext.Sms
  alias PhoenixEctoOpenApiDemo.NotificationContext.Webhook

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
      email: Email,
      sms: Sms,
      webhook: Webhook
    ]
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notifications" do
    field :subject, :string

    polymorphic_embeds_one(:channel,
      types: [
        email: Email,
        sms: Sms,
        webhook: Webhook
      ],
      type_field_name: :__type__,
      on_type_not_found: :raise,
      on_replace: :update
    )

    timestamps()
  end

  open_api_schema(
    title: "Notification",
    description: "An outbound notification with a polymorphic channel",
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
