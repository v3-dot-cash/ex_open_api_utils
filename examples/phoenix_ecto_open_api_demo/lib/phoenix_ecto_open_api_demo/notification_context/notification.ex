defmodule PhoenixEctoOpenApiDemo.NotificationContext.Notification do
  @moduledoc """
  Parent schema for an outbound notification with a polymorphic `:channel`.

  The Ecto side uses `PolymorphicEmbed.polymorphic_embeds_one/2` so that the
  `:channel` field hydrates into the correct variant struct (Email / Sms /
  Webhook) based on the `__type__` discriminator in the payload.

  The OpenAPI side uses `ExOpenApiUtils.Polymorphic.one_of/1` to produce a
  `oneOf + discriminator` schema with `type: :object` set. This is the full
  feature — no `__before_compile__` reflection, no auto-generated variants.
  Users declare the property explicitly and the helper does the tedious
  parts: merging `__type__` into each variant with `enum: [...]` locked to
  the variant type, building the discriminator mapping from variant titles,
  and guaranteeing the `type: :object` dispatch gate (without which
  `OpenApiSpex.Cast` silently falls through to a generic `oneOf` path and
  cast errors degrade into an unreadable wall).
  """
  use ExOpenApiUtils
  alias ExOpenApiUtils.Polymorphic

  alias PhoenixEctoOpenApiDemo.NotificationContext.Email
  alias PhoenixEctoOpenApiDemo.NotificationContext.Sms
  alias PhoenixEctoOpenApiDemo.NotificationContext.Webhook

  alias PhoenixEctoOpenApiDemo.OpenApiSchema.EmailRequest
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.SmsRequest
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.WebhookRequest

  import PolymorphicEmbed

  # Force the variant modules to compile BEFORE this module's macro
  # expansion reaches `Polymorphic.one_of/1`. Without this, Elixir's parallel
  # compiler may process `Notification` concurrently with the variants, and
  # `Polymorphic.one_of/1` fails with `:nofile` when trying to resolve
  # `EmailRequest.schema()` because Email hasn't finished compiling yet (and
  # so `EmailRequest` — created inside Email's `__before_compile__` — does
  # not exist). `Code.ensure_compiled!/1` declares the compile-time
  # dependency explicitly and serializes the ordering.
  Code.ensure_compiled!(Email)
  Code.ensure_compiled!(Sms)
  Code.ensure_compiled!(Webhook)

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

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notifications" do
    field :subject, :string

    # `polymorphic_embeds_one/2` internally calls `Code.ensure_compiled!/1`
    # on each variant module, so after this line the Email/Sms/Webhook
    # modules (and their auto-generated `OpenApiSchema.*Request` sub-modules
    # produced by `use ExOpenApiUtils`) are guaranteed to exist. This is why
    # the polymorphic `open_api_property(:channel, ...)` below MUST come
    # after the `schema do` block — otherwise `Polymorphic.one_of/1` would
    # try to resolve `EmailRequest.schema()` before the variants were
    # compiled and fail with `:nofile`.
    polymorphic_embeds_one :channel,
      types: [
        email: Email,
        sms: Sms,
        webhook: Webhook
      ],
      on_type_not_found: :raise,
      on_replace: :update

    timestamps()
  end

  # The polymorphic declaration. `Polymorphic.one_of/1` returns a plain
  # `%OpenApiSpex.Schema{type: :object, oneOf: [...], discriminator: ...}`
  # struct — the rest of the `ExOpenApiUtils` machinery treats it as any
  # other schema.
  open_api_property(
    key: :channel,
    schema:
      Polymorphic.one_of(
        discriminator: "__type__",
        variants: [
          {"email", EmailRequest},
          {"sms", SmsRequest},
          {"webhook", WebhookRequest}
        ]
      )
  )

  open_api_schema(
    title: "Notification",
    description: "An outbound notification with a polymorphic channel",
    required: [:subject, :channel],
    properties: [:id, :subject, :channel],
    tags: ["Notification"]
  )

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:subject])
    |> validate_required([:subject])
    |> PolymorphicEmbed.cast_polymorphic_embed(:channel, required: true)
  end
end
