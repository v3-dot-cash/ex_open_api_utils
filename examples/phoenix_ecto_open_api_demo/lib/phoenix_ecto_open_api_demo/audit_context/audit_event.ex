defmodule PhoenixEctoOpenApiDemo.AuditContext.AuditEvent do
  @moduledoc """
  Parent schema for an audit event with a polymorphic `:payload`.

  This fixture exists to cover two scenarios the notification example does
  not:

    1. **Context-only surface.** There is no controller wired for audit
       events — the library consumer interacts only with the Ecto context.
       Proves `open_api_polymorphic_property/1` does not require a Phoenix
       controller boundary to function.
    2. **Unique discriminator propertyName.** The wire discriminator is
       `"audit_kind"`, which is deliberately chosen so that `:audit_kind`
       does not appear as an atom literal anywhere else in the project.
       Under the GH-27 bug, the atom would not exist in the runtime atom
       table and `OpenApiSpex.Cast.Discriminator` would crash. The fix
       stores the atom as a bytecode literal inside the derived Mapper
       impl so it survives into a freshly-started BEAM.

  Also exercises the cross-name bridge: the Ecto-side `type_field_name`
  is `:__audit_type__`, distinct from the wire-side `"audit_kind"`.
  """
  use ExOpenApiUtils

  alias PhoenixEctoOpenApiDemo.AuditContext.DataExportEvent
  alias PhoenixEctoOpenApiDemo.AuditContext.UserLoginEvent

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
    key: :actor,
    schema: %Schema{type: :string, example: "api-token-42"}
  )

  open_api_polymorphic_property(
    key: :payload,
    type_field_name: :__audit_type__,
    open_api_discriminator_property: "audit_kind",
    variants: [
      user_login: UserLoginEvent,
      data_export: DataExportEvent
    ]
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "audit_events" do
    field :actor, :string

    polymorphic_embeds_one(:payload,
      types: [
        user_login: UserLoginEvent,
        data_export: DataExportEvent
      ],
      type_field_name: :__audit_type__,
      on_type_not_found: :raise,
      on_replace: :update
    )

    timestamps()
  end

  open_api_schema(
    title: "AuditEvent",
    description: "An audit event with a polymorphic payload",
    required: [:actor, :payload],
    properties: [:id, :actor, :payload],
    tags: ["Audit"]
  )

  def changeset(audit_event, attrs) do
    audit_event
    |> cast(attrs, [:actor])
    |> validate_required([:actor])
    |> cast_polymorphic_embed(:payload, required: true)
  end
end
