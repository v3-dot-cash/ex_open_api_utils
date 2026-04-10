defmodule ExOpenApiUtilsTest.Polymorphic.Notification do
  @moduledoc false
  use ExOpenApiUtils
  alias ExOpenApiUtils.Polymorphic
  alias OpenApiSpex.Schema
  import PolymorphicEmbed

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The notification id",
      format: :uuid,
      example: "851b18d7-0c88-4095-9969-cbe385926420",
      readOnly: true
    },
    key: :id
  )

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "Subject line",
      example: "Your order has shipped"
    },
    key: :subject
  )

  # THIS is the feature under test: an explicit open_api_property declaration
  # whose schema is built by `Polymorphic.one_of/1`. No __before_compile__
  # magic, no Ecto reflection, no fallbacks — just a helper that guarantees
  # `type: :object` is set (the OpenApiSpex discriminator dispatch gate) and
  # merges `__type__` into each variant locked by enum.
  open_api_property(
    key: :channel,
    schema:
      Polymorphic.one_of(
        discriminator: "__type__",
        variants: [
          {"email", ExOpenApiUtilsTest.OpenApiSchema.EmailRequest},
          {"sms", ExOpenApiUtilsTest.OpenApiSchema.SmsRequest},
          {"webhook", ExOpenApiUtilsTest.OpenApiSchema.WebhookRequest}
        ]
      )
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notifications" do
    field(:subject, :string)

    polymorphic_embeds_one(:channel,
      types: [
        email: ExOpenApiUtilsTest.Polymorphic.Email,
        sms: ExOpenApiUtilsTest.Polymorphic.Sms,
        webhook: ExOpenApiUtilsTest.Polymorphic.Webhook
      ],
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
    tags: ["Polymorphic"]
  )

  def changeset(schema, attrs) do
    schema
    |> Ecto.Changeset.cast(attrs, [:subject])
    |> Ecto.Changeset.validate_required([:subject])
    |> PolymorphicEmbed.cast_polymorphic_embed(:channel, required: true)
  end
end
