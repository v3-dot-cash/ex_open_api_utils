defmodule ExOpenApiUtils.Polymorphic do
  @moduledoc """
  Pure helper for building `oneOf + discriminator` schemas for polymorphic
  payloads (e.g. fields declared via `polymorphic_embeds_one`).

  This module does **not** touch `__before_compile__`, reflect on Ecto
  schemas, or generate modules. It is a single pure function you call inside
  your own `open_api_property/1` declaration.

  ## Why a helper instead of hand-writing the schema

  Hand-writing a polymorphic schema has two easy-to-miss footguns:

    1. **The `type: :object` dispatch gate.** `OpenApiSpex.Cast.cast/1` only
       routes through `Cast.Discriminator.cast/1` when the composition schema
       has **both** `type: :object` and `discriminator: %Discriminator{}`
       set. A `oneOf + discriminator` schema that omits `type: :object`
       silently falls through to `OneOf.cast/1` and the discriminator is
       never applied — you get an unreadable `:one_of` wall of errors
       across every variant instead of a surgical `:missing_field` on the
       selected branch.
    2. **Per-variant discriminator locking.** Each variant in the `oneOf`
       must carry the discriminator field with `enum: [variant_type]` in
       its properties and list the field in `required`, otherwise
       discriminator mapping resolution misfires.

  `one_of/1` handles both correctly.

  ## Usage

      defmodule MyApp.Notification do
        use ExOpenApiUtils
        alias ExOpenApiUtils.Polymorphic

        schema "notifications" do
          field :subject, :string

          polymorphic_embeds_one :channel,
            types: [
              email:   MyApp.Notification.Email,
              sms:     MyApp.Notification.Sms,
              webhook: MyApp.Notification.Webhook
            ],
            on_type_not_found: :raise,
            on_replace: :update
        end

        open_api_property(
          key: :channel,
          schema: Polymorphic.one_of(
            discriminator: "__type__",
            variants: [
              {"email",   MyApp.Notification.Email.OpenApiSchema.EmailRequest},
              {"sms",     MyApp.Notification.Sms.OpenApiSchema.SmsRequest},
              {"webhook", MyApp.Notification.Webhook.OpenApiSchema.WebhookRequest}
            ]
          )
        )

        open_api_schema(
          title: "Notification",
          description: "An outbound notification",
          properties: [:subject, :channel]
        )
      end

  Variants can be either an `%OpenApiSpex.Schema{}` struct or a module that
  exports `schema/0` (e.g. any module declared via `OpenApiSpex.schema/1` or
  via `use ExOpenApiUtils`). No other forms are accepted — this is an
  intentionally narrow surface.

  ## Supported vs. not supported

  `polymorphic_embed` supports two discriminator locations. Only one of them
  is representable with OpenAPI 3 discriminators:

  | Discriminator location            | `polymorphic_embed` config             | `one_of/1` fits?               |
  |-----------------------------------|----------------------------------------|--------------------------------|
  | Inside the embed object (default) | `use_parent_field_for_type: nil`       | Yes — this is what it is for   |
  | On the parent as a sibling column | `use_parent_field_for_type: :some_col` | No — not spec-representable    |

  OpenAPI 3 discriminators are intra-object only: the discriminator property
  must live inside the schema being discriminated.
  `OpenApiSpex.Cast.Discriminator` reads `value[discriminator_property]` where
  `value` is the object currently being cast — it cannot reach a sibling
  field on the parent.

  **Calling `one_of/1` for an external-type field will produce a schema that
  compiles cleanly but describes the wrong wire format**: the generated schema
  expects the discriminator inside the embed payload, while your actual
  payload carries it at the parent level. Clients generated from the spec
  will misplace the discriminator and server validation will reject every
  request with `:no_value_for_discriminator`. The helper does not raise in
  this case because it is a pure builder — it trusts your inputs.

  If you need external-type semantics on the wire, see `one_of/1` for the
  three alternatives (restructure the payload, hand-roll a discriminator-less
  `oneOf`, or use OpenApiSpex's `"x-validate"` escape hatch).

  ## Other limitations

    * Request and response use the same helper call. If you need direction-
      specific variant shapes (e.g. filter `readOnly` fields in requests),
      call `one_of/1` twice and declare two properties with `readOnly:` /
      `writeOnly:` at the wrapper level.
  """

  alias OpenApiSpex.Discriminator
  alias OpenApiSpex.Schema

  @type variant :: {String.t(), Schema.t() | module()}

  @doc """
  Builds an `%OpenApiSpex.Schema{}` with `type: :object`, `oneOf: [...]`, and
  `discriminator: %Discriminator{}` from a list of variants.

  ## Options

    * `:discriminator` — **required**. The discriminator property name as a
      string (e.g. `"__type__"`). Must match the `type_field_name` used by
      your `polymorphic_embeds_one` declaration.
    * `:variants` — **required**. A non-empty list of
      `{type_string, schema_or_module}` tuples. Each entry declares one
      variant of the union. The `type_string` is the value of the
      discriminator property for that variant (e.g. `"email"`).

  ## Behavior

  For each variant:

    * If `schema_or_module` is a module, `schema/0` is called to obtain its
      `%Schema{}`.
    * The discriminator property is merged into the variant's `properties`
      with `enum: [type_string]` (locking it to the variant's value).
    * The discriminator property is prepended to `required` (deduplicated).

  The returned top-level schema has:

    * `type: :object` — the dispatch gate.
    * `oneOf: [merged_variants...]` — merged variant schemas, in the order
      given.
    * `discriminator.propertyName = discriminator`.
    * `discriminator.mapping = %{type_string => variant_title}` for every
      variant whose schema has a `title`. Variants without a title are
      omitted from the mapping (OpenApiSpex will fall back to matching by
      schema identity at cast time).
    * `required: [discriminator_atom]` — the discriminator is always
      required at the wrapper level.

  Raises `ArgumentError` if `:discriminator` or `:variants` is missing, if
  `:variants` is empty, or if a variant entry is malformed.

  ## Not supported: external-type polymorphic embeds

  If your `polymorphic_embeds_one` declaration uses
  `:use_parent_field_for_type` (i.e. the discriminator column lives on the
  parent Ecto schema as a sibling of the embed, not inside the embedded
  object), **do not use this helper for that field**. OpenAPI 3
  discriminators are intra-object only — the discriminator property must
  live inside the schema being discriminated. `OpenApiSpex.Cast.Discriminator`
  reads `value[discriminator_property]` where `value` is the object
  currently being cast, so it cannot reach a sibling field on the parent.

  Calling `one_of/1` for an external-type field will produce a spec that
  compiles cleanly but describes the wrong wire format: the generated schema
  expects the discriminator **inside** the embed payload, while your actual
  payload carries it at the parent level. Clients generated from the spec
  will misplace the discriminator and server validation will reject every
  request with `:no_value_for_discriminator`.

  If you need external-type semantics on the wire, your options are:

    1. Restructure the API so the discriminator lives inside the embed
       (drop `:use_parent_field_for_type` in `polymorphic_embeds_one` too).
    2. Declare the discriminator column and the `oneOf` body as two separate
       `open_api_property/1` entries, and hand-write a plain `oneOf` on the
       body **without** a discriminator. You lose focused cast errors but
       the spec matches the wire format.
    3. Use OpenApiSpex's `"x-validate"` escape hatch to supply a custom
       validator that reads the parent's sibling field.

  See the moduledoc for more on the limitation.
  """
  @spec one_of(keyword()) :: Schema.t()
  def one_of(opts) do
    discriminator = fetch_discriminator!(opts)
    variants = fetch_variants!(opts)
    discriminator_atom = String.to_atom(discriminator)

    {one_of_schemas, mapping} =
      Enum.map_reduce(variants, %{}, fn variant, acc ->
        merge_variant(variant, discriminator_atom, acc)
      end)

    %Schema{
      type: :object,
      oneOf: one_of_schemas,
      discriminator: %Discriminator{
        propertyName: discriminator,
        mapping: mapping
      },
      required: [discriminator_atom]
    }
  end

  defp fetch_discriminator!(opts) do
    case Keyword.fetch(opts, :discriminator) do
      {:ok, d} when is_binary(d) and d != "" ->
        d

      {:ok, other} ->
        raise ArgumentError,
              "Polymorphic.one_of/1 :discriminator must be a non-empty string, got: " <>
                inspect(other)

      :error ->
        raise ArgumentError, "Polymorphic.one_of/1 requires :discriminator"
    end
  end

  defp fetch_variants!(opts) do
    case Keyword.fetch(opts, :variants) do
      {:ok, [_ | _] = v} ->
        v

      {:ok, []} ->
        raise ArgumentError, "Polymorphic.one_of/1 :variants must not be empty"

      {:ok, other} ->
        raise ArgumentError,
              "Polymorphic.one_of/1 :variants must be a non-empty list of " <>
                "{type_string, schema_or_module} tuples, got: " <> inspect(other)

      :error ->
        raise ArgumentError, "Polymorphic.one_of/1 requires :variants"
    end
  end

  defp merge_variant(variant, discriminator_atom, mapping_acc) do
    {type_string, base_schema} = resolve_variant!(variant)

    discriminator_property = %Schema{
      type: :string,
      enum: [type_string],
      description: "Polymorphic discriminator"
    }

    properties =
      (base_schema.properties || %{})
      |> Map.put(discriminator_atom, discriminator_property)

    required =
      [discriminator_atom | base_schema.required || []]
      |> Enum.uniq()

    merged = %Schema{base_schema | properties: properties, required: required}

    mapping_acc =
      case base_schema.title do
        nil -> mapping_acc
        title when is_binary(title) -> Map.put(mapping_acc, type_string, title)
      end

    {merged, mapping_acc}
  end

  defp resolve_variant!({type_string, %Schema{} = schema})
       when is_binary(type_string) and type_string != "" do
    {type_string, schema}
  end

  defp resolve_variant!({type_string, module})
       when is_binary(type_string) and type_string != "" and is_atom(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        if function_exported?(module, :schema, 0) do
          case module.schema() do
            %Schema{} = schema ->
              {type_string, schema}

            other ->
              raise ArgumentError,
                    "Polymorphic.one_of/1 variant #{inspect(module)}.schema/0 " <>
                      "must return an %OpenApiSpex.Schema{}, got: " <> inspect(other)
          end
        else
          raise ArgumentError,
                "Polymorphic.one_of/1 variant #{inspect(module)} must export schema/0 " <>
                  "(e.g. via OpenApiSpex.schema/1 or `use ExOpenApiUtils`)"
        end

      {:error, reason} ->
        raise ArgumentError,
              "Polymorphic.one_of/1 could not load variant module #{inspect(module)}: " <>
                inspect(reason)
    end
  end

  defp resolve_variant!(other) do
    raise ArgumentError,
          "Polymorphic.one_of/1 variant must be a {type_string, %Schema{} | module} " <>
            "tuple, got: " <> inspect(other)
  end
end
