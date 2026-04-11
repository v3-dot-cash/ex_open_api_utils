defmodule ExOpenApiUtilsTest.PolymorphicDiscriminator.Notification do
  @moduledoc false
  use ExOpenApiUtils
  alias OpenApiSpex.Discriminator

  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.SmsChannel
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.WebhookChannel

  alias ExOpenApiUtilsTest.OpenApiSchema.EmailChannelRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.SmsChannelRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.SmsChannelResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.WebhookChannelRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.WebhookChannelResponse

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

  open_api_property(
    key: :channel,
    schema: %Schema{
      type: :object,
      writeOnly: true,
      oneOf: [EmailChannelRequest, SmsChannelRequest, WebhookChannelRequest],
      discriminator: %Discriminator{
        propertyName: "object_type",
        mapping: %{
          "email" => EmailChannelRequest,
          "sms" => SmsChannelRequest,
          "webhook" => WebhookChannelRequest
        }
      }
    }
  )

  open_api_property(
    key: :channel,
    schema: %Schema{
      type: :object,
      readOnly: true,
      oneOf: [EmailChannelResponse, SmsChannelResponse, WebhookChannelResponse],
      discriminator: %Discriminator{
        propertyName: "object_type",
        mapping: %{
          "email" => EmailChannelResponse,
          "sms" => SmsChannelResponse,
          "webhook" => WebhookChannelResponse
        }
      }
    }
  )

  polymorphic_embed_discriminator(key: :channel, type_field_name: :__type__)

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
