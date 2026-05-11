defmodule PhoenixEctoOpenApiDemo.NotificationContext.DualChannelNotification do
  @moduledoc """
  GH-47 example. A parent schema with **two** `open_api_polymorphic_property/1`
  declarations that share the same variant pool (`Email` / `Sms` / `Webhook`).

  Before the GH-47 fix, this pattern blocked compilation under
  `--warnings-as-errors` because both decls derived identically-named
  parent-contextual sibling modules (`DualChannelNotificationEmailRequest`,
  etc.) — `Module.create/3` and `Protocol.derive/3` were called twice for
  each target, emitting "redefining module" warnings. The library now
  dedupes these calls when the generated bodies are structurally identical
  (and raises a `CompileError` when they would disagree).

  Use case: a notification that delivers via a `primary_channel` and falls
  back to a `fallback_channel` if the primary fails — both legitimately
  draw from the same provider set.
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
    key: :primary_channel,
    type_field_name: :__type__,
    open_api_discriminator_property: "channel_type",
    variants: [
      email: Email,
      sms: Sms,
      webhook: Webhook
    ]
  )

  open_api_polymorphic_property(
    key: :fallback_channel,
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
  schema "dual_channel_notifications" do
    field :subject, :string

    polymorphic_embeds_one(:primary_channel,
      types: [email: Email, sms: Sms, webhook: Webhook],
      type_field_name: :__type__,
      on_type_not_found: :raise,
      on_replace: :update
    )

    polymorphic_embeds_one(:fallback_channel,
      types: [email: Email, sms: Sms, webhook: Webhook],
      type_field_name: :__type__,
      on_type_not_found: :raise,
      on_replace: :update
    )

    timestamps()
  end

  open_api_schema(
    title: "DualChannelNotification",
    description: "Notification delivered with a primary channel and an optional fallback",
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
