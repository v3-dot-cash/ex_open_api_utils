defmodule PhoenixEctoOpenApiDemo.NotificationContext.Notification do
  @moduledoc """
  Parent schema for an outbound notification with a polymorphic `:channel`.

  The polymorphism is declared in two halves:

    * Two `open_api_property` calls with the same `:channel` key — one
      `writeOnly` pointing at `*Request` submodules, one `readOnly` pointing
      at `*Response` submodules.
    * A single `polymorphic_embed_discriminator` call that tells the library
      to bridge `polymorphic_embeds_one`'s `type_field_name:` (Ecto, atom)
      with the `%OpenApiSpex.Discriminator{propertyName: ...}` (wire, string)
      carried inside each of the two schemas above.

  Variants (`EmailChannel`, `SmsChannel`, `WebhookChannel`) are plain
  `use ExOpenApiUtils` embedded schemas — they know nothing about being
  part of a discriminated union.
  """
  use ExOpenApiUtils
  alias OpenApiSpex.Discriminator

  alias PhoenixEctoOpenApiDemo.NotificationContext.Email
  alias PhoenixEctoOpenApiDemo.NotificationContext.Sms
  alias PhoenixEctoOpenApiDemo.NotificationContext.Webhook

  alias PhoenixEctoOpenApiDemo.OpenApiSchema.EmailRequest
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.EmailResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.SmsRequest
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.SmsResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.WebhookRequest
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.WebhookResponse

  import PolymorphicEmbed

  Code.ensure_compiled!(Email)
  Code.ensure_compiled!(Sms)
  Code.ensure_compiled!(Webhook)

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

  open_api_property(
    key: :channel,
    schema: %Schema{
      type: :object,
      writeOnly: true,
      oneOf: [EmailRequest, SmsRequest, WebhookRequest],
      discriminator: %Discriminator{
        propertyName: "object_type",
        mapping: %{
          "email" => EmailRequest,
          "sms" => SmsRequest,
          "webhook" => WebhookRequest
        }
      }
    }
  )

  open_api_property(
    key: :channel,
    schema: %Schema{
      type: :object,
      readOnly: true,
      oneOf: [EmailResponse, SmsResponse, WebhookResponse],
      discriminator: %Discriminator{
        propertyName: "object_type",
        mapping: %{
          "email" => EmailResponse,
          "sms" => SmsResponse,
          "webhook" => WebhookResponse
        }
      }
    }
  )

  polymorphic_embed_discriminator(key: :channel, type_field_name: :__type__)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notifications" do
    field :subject, :string

    polymorphic_embeds_one :channel,
      types: [
        email: Email,
        sms: Sms,
        webhook: Webhook
      ],
      type_field_name: :__type__,
      on_type_not_found: :raise,
      on_replace: :update

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
