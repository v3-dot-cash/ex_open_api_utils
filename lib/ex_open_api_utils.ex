defmodule ExOpenApiUtils do
  @moduledoc """
  OpenAPI schema generation from Ecto schemas with OpenAPI 3.2 support.

  ## Migration Guide

  ### From v0.9.x to v0.10.x (OpenAPI 3.2)

  #### 1. Update OpenAPI Version

  In your ApiSpec module, update the version:

      # Before (v0.9.x)
      %OpenApi{
        openapi: "3.0.0",
        ...
      }

      # After (v0.10.x)
      %OpenApi{
        openapi: ExOpenApiUtils.openapi_version(),  # Returns "3.2.0"
        ...
      }

  #### 2. Migrate Tags (Optional - for tag hierarchy)

  If using flat tags, no changes needed. For hierarchical tags:

      # Before (v0.9.x) - flat tags
      %OpenApi{
        tags: [
          %OpenApiSpex.Tag{name: "Users"},
          %OpenApiSpex.Tag{name: "Profile"},
          %OpenApiSpex.Tag{name: "Admin"}
        ]
      }

      # After (v0.10.x) - hierarchical tags with 3.2 fields
      alias ExOpenApiUtils.Tag

      %OpenApi{
        tags: [
          Tag.new("Users", summary: "User Management"),
          Tag.nested("Profile", "Users", summary: "User Profiles"),
          Tag.navigation("Admin", summary: "Admin Panel")
        ] |> Tag.to_open_api_spex_list()
      }

  #### 3. Remove Deprecated Extensions (if using Redoc-specific)

  Replace non-standard extensions with OpenAPI 3.2 native fields:

  | Old (Redoc)       | New (3.2 native)     |
  |-------------------|----------------------|
  | `x-tagGroups`     | Use `Tag.nested/3`   |
  | `x-displayName`   | Use `summary` field  |

  ### Extensions Retained

  These extensions are kept for TypeScript/NestJS codegen compatibility:

  - `x-enum-varnames` - TypeScript enum member names
  - `x-order` - Property ordering in generated code

  ## Basic Usage

  Define schemas with `use ExOpenApiUtils`:

      defmodule MyApp.User do
        use ExOpenApiUtils

        open_api_property(
          key: :name,
          schema: %Schema{type: :string, description: "User name"}
        )

        @primary_key {:id, :binary_id, autogenerate: true}
        schema "users" do
          field :name, :string
        end

        open_api_schema(
          title: "User",
          description: "Application user",
          required: [:name],
          properties: [:name],
          tags: ["Users"]
        )
      end

  ## Polymorphic embeds

  `ex_open_api_utils` bridges `polymorphic_embed`'s Ecto side to OpenApiSpex's
  `oneOf + discriminator` composition. Declare the bridge with a single
  `open_api_polymorphic_property/1` call alongside the matching
  `polymorphic_embeds_one`:

      defmodule MyApp.Notification do
        use ExOpenApiUtils

        open_api_property(key: :subject, schema: %Schema{type: :string})

        open_api_polymorphic_property(
          key: :channel,
          type_field_name: :__type__,
          open_api_discriminator_property: "channel_type",
          variants: [
            email:   EmailChannel,
            sms:     SmsChannel,
            webhook: WebhookChannel
          ]
        )

        schema "notifications" do
          field :subject, :string
          polymorphic_embeds_one :channel,
            types: [email: EmailChannel, sms: SmsChannel, webhook: WebhookChannel],
            type_field_name: :__type__,
            on_type_not_found: :raise,
            on_replace: :update
        end

        open_api_schema(title: "Notification", ...)
      end

  The library generates one parent-contextual variant submodule per
  `(parent, variant, direction)` triple at the parent's `__before_compile__`
  time via `Module.create` with an `allOf` composition body. The generated
  siblings (e.g. `NotificationEmailChannelRequest` /
  `NotificationEmailChannelResponse`) carry the discriminator as a real
  `defstruct` field, so `Kernel.struct/2` preserves it through the full
  cast pipeline — closing GH-30, where the pre-fix variant submodule's
  defstruct was built without the discriminator and silently dropped it
  at `Cast.Object.to_struct/1`.

  See `open_api_polymorphic_property/1` for the full option list.
  """
  alias ExOpenApiUtils.Property
  alias ExOpenApiUtils.SchemaDefinition
  alias ExOpenApiUtils.Tag
  require Protocol

  @doc """
  Returns the OpenAPI version string for 3.2 compliance.
  """
  @spec openapi_version() :: String.t()
  def openapi_version, do: "3.2.0"

  @doc """
  Alias for Tag module for convenience.
  """
  defdelegate tag(name, opts \\ []), to: Tag, as: :new
  defdelegate nested_tag(name, parent, opts \\ []), to: Tag, as: :nested
  defdelegate navigation_tag(name, opts \\ []), to: Tag, as: :navigation

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      require ExOpenApiUtils

      import ExOpenApiUtils,
        only: [
          open_api_schema: 1,
          open_api_property: 1,
          open_api_polymorphic_property: 1
        ]

      alias ExOpenApiUtils.Helpers
      alias ExOpenApiUtils.Tag
      alias OpenApiSpex.Schema
      import Ecto.Changeset, except: [cast: 4, cast: 3]
      import ExOpenApiUtils.Changeset, only: [cast: 4, cast: 3]

      Module.register_attribute(__MODULE__, :open_api_properties, accumulate: true)
      Module.register_attribute(__MODULE__, :open_api_schemas, accumulate: true)

      Module.register_attribute(__MODULE__, :open_api_polymorphic_properties, accumulate: true)

      @before_compile ExOpenApiUtils
    end
  end

  defmacro open_api_schema(opts) do
    title = Keyword.fetch!(opts, :title)
    required = Keyword.get(opts, :required, [])
    description = Keyword.fetch!(opts, :description)
    tags = Keyword.get(opts, :tags, [])
    properties = Keyword.get(opts, :properties)
    type = Keyword.get(opts, :type, :object)
    nullable = Keyword.get(opts, :nullable, nil)

    quote do
      all_properties = @open_api_properties |> Enum.map(& &1.key)
      alias ExOpenApiUtils.SchemaDefinition

      properties = unquote(properties) || all_properties

      schema_definition = %SchemaDefinition{
        tags: unquote(tags),
        properties: properties,
        title: unquote(title),
        required: unquote(required),
        description: unquote(description),
        type: unquote(type),
        nullable: unquote(nullable)
      }

      Module.put_attribute(__MODULE__, :open_api_schemas, schema_definition)
    end
  end

  defmacro open_api_property(opts) do
    schema = Keyword.fetch!(opts, :schema)
    key = Keyword.fetch!(opts, :key)
    source = Keyword.get(opts, :source, key)

    quote do
      alias ExOpenApiUtils.Property
      property = %Property{schema: unquote(schema), key: unquote(key), source: unquote(source)}
      Module.put_attribute(__MODULE__, :open_api_properties, property)
    end
  end

  @doc """
  Declares a polymorphic field whose underlying Ecto schema is a
  `polymorphic_embeds_one` and whose OpenAPI representation is a `oneOf +
  discriminator` composition. A single call replaces the previous
  paired-`open_api_property` + `polymorphic_embed_discriminator` shape.

  The library generates one parent-contextual variant submodule per
  `(parent, variant, direction)` triple at the parent's `__before_compile__`
  time, composing each new sibling via
  `allOf: [<original variant submodule>, <inline discriminator patch>]` so
  the generated `defstruct` includes the discriminator field as a real atom
  key. The parent's own `oneOf + discriminator.mapping` is synthesised to
  point at the new siblings, so the round-trip cast preserves the
  discriminator through `Kernel.struct/2`.

  ## Options

    * `:key` (required) — atom. The field name on the parent that is both a
      `polymorphic_embeds_one` and the name of the synthesised
      writeOnly/readOnly OpenAPI properties.
    * `:type_field_name` (required) — atom. Must match the `type_field_name:`
      option passed to `polymorphic_embeds_one`. This is the atom key that
      `cast_polymorphic_embed/3` reads from the flattened params map; it may
      differ from the wire discriminator name.
    * `:open_api_discriminator_property` (required) — non-empty string. The
      wire discriminator key that will appear in the JSON body and that
      OpenApiSpex's `Cast.Discriminator` will read to route the variant.
    * `:variants` (required) — non-empty keyword list. Each entry is
      `wire_atom: EctoVariantModule`. The wire value written to and read
      from the JSON body is `Atom.to_string(wire_atom)`, and the Ecto
      variant module must be one of the modules listed in the matching
      `polymorphic_embeds_one`'s `:types` option. Each variant module must
      itself `use ExOpenApiUtils` and have at least one `open_api_schema/1`
      declaration so the library can reflect on its auto-generated
      Request/Response submodules.

  ## Example

      open_api_polymorphic_property(
        key: :channel,
        type_field_name: :__type__,
        open_api_discriminator_property: "channel_type",
        variants: [
          email:   EmailChannel,
          sms:     SmsChannel,
          webhook: WebhookChannel
        ]
      )

      schema "notifications" do
        field :subject, :string
        polymorphic_embeds_one :channel,
          types: [
            email:   EmailChannel,
            sms:     SmsChannel,
            webhook: WebhookChannel
          ],
          type_field_name: :__type__,
          on_type_not_found: :raise,
          on_replace: :update
      end
  """
  defmacro open_api_polymorphic_property(opts) do
    key = Keyword.fetch!(opts, :key)
    type_field_name = Keyword.fetch!(opts, :type_field_name)
    discriminator_property = Keyword.fetch!(opts, :open_api_discriminator_property)
    variants_ast = Keyword.fetch!(opts, :variants)

    unless is_atom(key) do
      raise ArgumentError,
            "open_api_polymorphic_property :key must be an atom, got: #{inspect(key)}"
    end

    unless is_atom(type_field_name) do
      raise ArgumentError,
            "open_api_polymorphic_property :type_field_name must be an atom, got: " <>
              inspect(type_field_name)
    end

    unless is_binary(discriminator_property) and discriminator_property != "" do
      raise ArgumentError,
            "open_api_polymorphic_property :open_api_discriminator_property must be a " <>
              "non-empty string, got: #{inspect(discriminator_property)}"
    end

    unless is_list(variants_ast) and variants_ast != [] do
      raise ArgumentError,
            "open_api_polymorphic_property :variants must be a non-empty keyword " <>
              "list, got: #{inspect(variants_ast)}"
    end

    # Resolve each variant module reference through the caller's alias
    # environment so the type check runs against real module atoms. Module
    # refs in source code live as {:__aliases__, meta, segments} AST tuples
    # until this point; Macro.expand/2 is a no-op on already-resolved
    # atoms, so literal atoms pass through unchanged.
    variants =
      Enum.map(variants_ast, fn
        {wire, mod_ast} when is_atom(wire) ->
          expanded = Macro.expand(mod_ast, __CALLER__)

          unless is_atom(expanded) and not is_nil(expanded) do
            raise ArgumentError,
                  "open_api_polymorphic_property :variants entry #{inspect(wire)} " <>
                    "must reference a module, got: #{Macro.to_string(mod_ast)}"
          end

          {wire, expanded}

        bad ->
          raise ArgumentError,
                "open_api_polymorphic_property :variants entry must be a " <>
                  "{atom_wire_value, ModuleRef} pair, got: #{Macro.to_string(bad)}"
      end)

    quote do
      Module.put_attribute(
        __MODULE__,
        :open_api_polymorphic_properties,
        %{
          key: unquote(key),
          type_field_name: unquote(type_field_name),
          discriminator_property: unquote(discriminator_property),
          variants: unquote(variants)
        }
      )
    end
  end

  defmacro __before_compile__(%{module: module}) do
    quote do
      require Protocol
      alias ExOpenApiUtils.SchemaDefinition

      polymorphic_variants =
        ExOpenApiUtils.__build_polymorphic_variants__(
          unquote(module),
          @open_api_polymorphic_properties,
          @ecto_fields
        )

      # Generate one parent-contextual variant submodule per
      # (parent, variant, direction) triple. Each new module's schema body
      # is `allOf: [<original variant submodule>, <inline discriminator
      # patch>]`, so OpenApiSpex.schema/1's macro walks the allOf via
      # Schema.properties/1 and builds a defstruct that includes the
      # discriminator field as a real atom key. Closes GH-30.
      ExOpenApiUtils.__generate_parent_contextual_variants__(
        unquote(module),
        @open_api_polymorphic_properties,
        polymorphic_variants
      )

      # Derive a Mapper impl for each parent-contextual sibling, matching
      # the shape the variant's own regular siblings already get. Without
      # this, Mapper.to_map falls back to the Any fallback on the sibling
      # and leaks the struct unchanged — OpenApiSpex.Cast can't Access.get
      # through it on the re-cast path because structs don't implement the
      # Access behaviour. The property_attrs list is the variant's
      # reflected attrs plus an inline discriminator %Property{} so the
      # sibling's Mapper emits the discriminator as a real wire field.
      for decl <- @open_api_polymorphic_properties do
        entry = Map.fetch!(polymorphic_variants, decl.key)

        for variant <- entry.variant_entries do
          # Two distinct discriminator stamps happen on the sibling's Mapper
          # result map, both derived from the same entry + variant inputs:
          #
          #   1. WIRE discriminator (e.g. `:destination_type => "webhook"`) —
          #      `discriminator_prop` is appended to `property_attrs` below so
          #      the sibling's walker emits it like any other property.
          #
          #   2. ECTO type-field discriminator (e.g. `:__type__ => "webhook"`)
          #      — `self_stamp_atom` / `self_stamp_wire` below are read by
          #      `Any.__deriving__/3` (GH-34) and spliced as a final
          #      `Map.put(result, atom, wire)` at the tail of the generated
          #      walker body, so nested polymorphic cases get their Ecto
          #      atom at every level without relying on the outer walker's
          #      `polymorphic_variants` knowing about nested keys.
          discriminator_prop = %ExOpenApiUtils.Property{
            key: entry.discriminator_atom,
            source: entry.discriminator_atom,
            schema: %OpenApiSpex.Schema{type: :string, enum: [variant.wire]}
          }

          request_attrs = variant.request_property_attrs ++ [discriminator_prop]
          response_attrs = variant.response_property_attrs ++ [discriminator_prop]

          Protocol.derive(
            ExOpenApiUtils.Mapper,
            variant.parent_contextual_request_submodule,
            property_attrs: request_attrs,
            map_direction: :from_open_api,
            polymorphic_variants: polymorphic_variants,
            self_stamp_atom: entry.type_field_atom,
            self_stamp_wire: variant.wire
          )

          Protocol.derive(
            ExOpenApiUtils.Mapper,
            variant.parent_contextual_response_submodule,
            property_attrs: response_attrs,
            map_direction: :from_open_api,
            polymorphic_variants: polymorphic_variants,
            self_stamp_atom: entry.type_field_atom,
            self_stamp_wire: variant.wire
          )
        end
      end

      # Synthesize the two directional %Property{} entries per polymorphic
      # declaration and append them to @open_api_properties via normal
      # put_attribute. The attribute is `accumulate: true`, so each put
      # prepends; the downstream __submodule_spec__/4 loop picks them up
      # alongside the user's scalar declarations. No attribute rewrite.
      for decl <- @open_api_polymorphic_properties do
        {write_prop, read_prop} =
          ExOpenApiUtils.__synthesize_polymorphic_properties__(
            unquote(module),
            decl,
            polymorphic_variants
          )

        Module.put_attribute(__MODULE__, :open_api_properties, write_prop)
        Module.put_attribute(__MODULE__, :open_api_properties, read_prop)
      end

      for %SchemaDefinition{} = schema_definition <- @open_api_schemas do
        {request_module_name, request_body, request_properties} =
          ExOpenApiUtils.__submodule_spec__(
            unquote(module),
            schema_definition,
            @open_api_properties,
            :request
          )

        Module.create(
          request_module_name,
          quote do
            require OpenApiSpex
            OpenApiSpex.schema(unquote(Macro.escape(request_body)), derive?: false)
            unquote(ExOpenApiUtils.JasonEncoder.build_ast(request_properties))
          end,
          Macro.Env.location(__ENV__)
        )

        Protocol.derive(ExOpenApiUtils.Mapper, request_module_name,
          property_attrs: request_properties,
          map_direction: :from_open_api,
          polymorphic_variants: polymorphic_variants
        )

        {response_module_name, response_body, response_properties} =
          ExOpenApiUtils.__submodule_spec__(
            unquote(module),
            schema_definition,
            @open_api_properties,
            :response
          )

        Module.create(
          response_module_name,
          quote do
            require OpenApiSpex
            OpenApiSpex.schema(unquote(Macro.escape(response_body)), derive?: false)
            unquote(ExOpenApiUtils.JasonEncoder.build_ast(response_properties))
          end,
          Macro.Env.location(__ENV__)
        )

        Protocol.derive(ExOpenApiUtils.Mapper, response_module_name,
          property_attrs: response_properties,
          map_direction: :from_open_api,
          polymorphic_variants: polymorphic_variants
        )
      end

      exported_properties =
        Enum.filter(@open_api_properties, fn %Property{} = property ->
          !ExOpenApiUtils.is_writeOnly?(property.schema)
        end)

      Protocol.derive(ExOpenApiUtils.Mapper, __MODULE__,
        property_attrs: exported_properties,
        map_direction: :from_ecto,
        polymorphic_variants: polymorphic_variants
      )

      @__ex_open_api_utils_schemas_index__ ExOpenApiUtils.__schemas_index__(
                                             unquote(module),
                                             @open_api_schemas,
                                             @open_api_properties
                                           )

      @doc false
      def __ex_open_api_utils_schemas__, do: @__ex_open_api_utils_schemas_index__
    end
  end

  @doc false
  # Builds the `{module_name, body_map, filtered_properties}` triple for a
  # direction-specific sub-module (Request or Response). Extracted out of the
  # `__before_compile__` quote block to keep it small — the Module.create and
  # Protocol.derive calls have to stay inside the quote (Protocol.derive is a
  # macro), but all the filtering and body-assembly is plain data work.
  def __submodule_spec__(parent_module, schema_definition, all_properties, direction) do
    [root_module | _] = Module.split(parent_module)
    title = schema_definition.title
    description = schema_definition.description

    {suffix, reject_fn, body_extras} =
      case direction do
        :request ->
          {"Request", &is_readOnly?(&1.schema),
           %{
             description: description <> " Request",
             type: :object,
             writeOnly: true
           }}

        :response ->
          {"Response", &is_writeOnly?(&1.schema),
           %{
             description: description,
             type: schema_definition.type,
             readOnly: true
           }}
      end

    module_name = Module.concat([root_module, "OpenApiSchema", "#{title}#{suffix}"])

    properties =
      Enum.filter(all_properties, fn %Property{} = property ->
        property.key in schema_definition.properties && !reject_fn.(property)
      end)

    properties_map =
      Enum.reduce(properties, %{}, fn %Property{} = property, acc ->
        Map.put(acc, property.key, property.schema)
      end)

    example =
      Enum.reduce(properties, %{}, fn %Property{} = property, acc ->
        Map.put(acc, Atom.to_string(property.key), OpenApiSpex.Schema.example(property.schema))
      end)

    properties_keys = Map.keys(properties_map)

    required =
      Enum.filter(schema_definition.required, &(&1 in properties_keys))

    order =
      Enum.filter(schema_definition.properties, &(&1 in properties_keys))

    body =
      Map.merge(body_extras, %{
        title: Inflex.camelize(title <> suffix),
        required: required,
        properties: properties_map,
        tags: schema_definition.tags,
        nullable: schema_definition.nullable,
        example: example,
        extensions: %{"x-order" => order}
      })
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    {module_name, body, properties}
  end

  @doc false
  # Builds the reflection index stored under @__ex_open_api_utils_schemas_index__
  # and exposed via __ex_open_api_utils_schemas__/0. Each entry carries:
  #
  #   * title — the user-declared schema title
  #   * request_module / response_module — flat-concat module refs
  #   * request_property_attrs / response_property_attrs — filtered %Property{}
  #     lists that match what __submodule_spec__/4 feeds into each direction's
  #     Module.create/Protocol.derive pair. Carrying them here lets the parent's
  #     __before_compile__ pull them back out by reflection when generating
  #     parent-contextual sibling submodules so the siblings can get a real
  #     Protocol.derive(Mapper, ...) with the same property_attrs shape the
  #     underlying variant's regular siblings get.
  def __schemas_index__(module, schemas, all_properties) do
    [root_module | _] = Module.split(module)

    Enum.map(schemas, fn %SchemaDefinition{title: title} = schema_definition ->
      %{
        title: title,
        request_module: Module.concat([root_module, "OpenApiSchema", "#{title}Request"]),
        response_module: Module.concat([root_module, "OpenApiSchema", "#{title}Response"]),
        request_property_attrs:
          filter_schema_properties(all_properties, schema_definition, :request),
        response_property_attrs:
          filter_schema_properties(all_properties, schema_definition, :response)
      }
    end)
  end

  defp filter_schema_properties(all_properties, %SchemaDefinition{} = schema_definition, :request) do
    Enum.filter(all_properties, fn %Property{} = property ->
      property.key in schema_definition.properties and not is_readOnly?(property.schema)
    end)
  end

  defp filter_schema_properties(
         all_properties,
         %SchemaDefinition{} = schema_definition,
         :response
       ) do
    Enum.filter(all_properties, fn %Property{} = property ->
      property.key in schema_definition.properties and not is_writeOnly?(property.schema)
    end)
  end

  @doc false
  # Builds the polymorphic_variants map consumed by the Mapper derive calls.
  #
  # Reads the parent's `@open_api_polymorphic_properties` declarations
  # (one per `open_api_polymorphic_property/1` call), and for each:
  #   1. cross-checks that the declared `:type_field_name` matches the
  #      `type_field_name:` option on the matching `polymorphic_embeds_one`.
  #   2. cross-checks that the `:variants` keyword list agrees with the
  #      `polymorphic_embeds_one` `:types` option (same atom keys and
  #      same module refs).
  #   3. reflects on each variant Ecto module via its auto-generated
  #      `__ex_open_api_utils_schemas__/0` helper to pull its title and
  #      its auto-generated `request_module` / `response_module` refs.
  #   4. pre-computes the flat-concat parent-contextual sibling module
  #      names for both directions.
  #   5. builds the unified `variant_map` keyed by all three struct
  #      flavors (Ecto struct / parent-contextual request sibling /
  #      parent-contextual response sibling) — consumed by
  #      `Mapper.Polymorphic.inject/5` at runtime.
  #
  # Any failure raises a CompileError whose message names the specific
  # item that diverges.
  def __build_polymorphic_variants__(parent_module, polymorphic_decls, ecto_fields) do
    polymorphic_decls
    |> Enum.reverse()
    |> Enum.reduce(%{}, fn decl, acc ->
      entry = build_one_polymorphic_entry!(parent_module, decl, ecto_fields)
      Map.put(acc, decl.key, entry)
    end)
  end

  defp build_one_polymorphic_entry!(parent_module, decl, ecto_fields) do
    %{
      key: key,
      type_field_name: type_field_name,
      discriminator_property: discriminator_property,
      variants: variants
    } = decl

    ecto_opts = fetch_polymorphic_embed_opts!(parent_module, key, ecto_fields)

    unless ecto_opts.type_field_name == type_field_name do
      raise CompileError,
        description:
          "open_api_polymorphic_property(#{inspect(key)}) declares :type_field_name " <>
            "#{inspect(type_field_name)} but polymorphic_embeds_one :#{key} declares " <>
            ":type_field_name #{inspect(ecto_opts.type_field_name)} — they must match"
    end

    declared_variant_map =
      Enum.into(variants, %{}, fn {wire_atom, ecto_mod} ->
        {to_string(wire_atom), ecto_mod}
      end)

    ecto_variant_map =
      Enum.into(ecto_opts.types_metadata, %{}, fn %{type: type, module: mod} ->
        {to_string(type), mod}
      end)

    check_variants_agree_with_ecto!(key, declared_variant_map, ecto_variant_map)

    root_module = parent_module |> Module.split() |> hd()
    parent_title = fetch_parent_title!(parent_module)

    variant_entries =
      Enum.map(variants, fn {wire_atom, ecto_mod} ->
        wire_string = Atom.to_string(wire_atom)
        reflection = fetch_variant_reflection!(ecto_mod)

        %{
          wire: wire_string,
          ecto_mod: ecto_mod,
          variant_title: reflection.title,
          original_request_submodule: reflection.request_module,
          original_response_submodule: reflection.response_module,
          # Property attrs from the variant's own reflection, lifted verbatim
          # from what __submodule_spec__/4 produced when the variant was
          # compiled. Used by the parent's __before_compile__ below to derive
          # a Mapper impl for each parent-contextual sibling, matching the
          # shape that the variant's regular siblings already get.
          request_property_attrs: Map.get(reflection, :request_property_attrs, []),
          response_property_attrs: Map.get(reflection, :response_property_attrs, []),
          parent_contextual_request_submodule:
            parent_contextual_sibling_name(
              root_module,
              parent_title,
              reflection.title,
              "Request"
            ),
          parent_contextual_response_submodule:
            parent_contextual_sibling_name(
              root_module,
              parent_title,
              reflection.title,
              "Response"
            )
        }
      end)

    ecto_mod_by_wire =
      Map.new(variant_entries, &{&1.wire, &1.ecto_mod})

    request_mod_by_wire =
      Map.new(variant_entries, &{&1.wire, &1.parent_contextual_request_submodule})

    response_mod_by_wire =
      Map.new(variant_entries, &{&1.wire, &1.parent_contextual_response_submodule})

    # variant_map keys: all five struct flavors that can represent a given
    # variant at different points in the pipeline:
    #   * Ecto struct (e.g. %EmailChannel{})
    #   * original request sibling (e.g. %EmailChannelRequest{})
    #   * original response sibling (e.g. %EmailChannelResponse{})
    #   * parent-contextual request sibling (e.g. %NotificationEmailChannelRequest{})
    #   * parent-contextual response sibling (e.g. %NotificationEmailChannelResponse{})
    # All five point at the same wire string. Mapper.Polymorphic.inject/5
    # pattern-matches on any of them to look up the wire value to inject
    # on outbound serialization. Including all five keeps backwards
    # compatibility for users who construct the regular (non-parent-
    # contextual) sibling structs manually, while still routing cast
    # output (which uses the parent-contextual siblings) correctly.
    variant_map =
      variant_entries
      |> Enum.flat_map(fn %{
                            wire: wire,
                            ecto_mod: em,
                            original_request_submodule: orq,
                            original_response_submodule: ors,
                            parent_contextual_request_submodule: rq,
                            parent_contextual_response_submodule: rs
                          } ->
        [{em, wire}, {orq, wire}, {ors, wire}, {rq, wire}, {rs, wire}]
      end)
      |> Map.new()

    # Store the atom form of the discriminator propertyName in the
    # returned map. This flows through `Protocol.derive(...,
    # polymorphic_variants: ...)` to `ExOpenApiUtils.Mapper.__deriving__/3`,
    # where `Macro.escape/1` pins the whole map as a literal inside the
    # generated Mapper impl's `to_map/1` body. Elixir's compiler stashes
    # that literal in the module's LitT (literal pool) chunk, and the
    # BEAM loader materialises every atom inside the literal pool at
    # module-load time — so `:channel_type` (or whatever the user
    # declared) is present in the runtime atom table the moment the
    # compiled `.beam` file is loaded, even in a freshly-started BEAM
    # that has never run the library's compile-time `__before_compile__`
    # hook. See GH-27 for the bug this fixes.
    %{
      variant_map: variant_map,
      discriminator_string: discriminator_property,
      discriminator_atom: String.to_atom(discriminator_property),
      type_field_atom: type_field_name,
      ecto_mod_by_wire: ecto_mod_by_wire,
      request_mod_by_wire: request_mod_by_wire,
      response_mod_by_wire: response_mod_by_wire,
      variant_entries: variant_entries
    }
  end

  defp fetch_polymorphic_embed_opts!(parent_module, key, ecto_fields) do
    entry =
      Enum.find(ecto_fields, fn
        {^key, {{:parameterized, {PolymorphicEmbed, _opts}}, _writable}} -> true
        _ -> false
      end)

    case entry do
      {^key, {{:parameterized, {PolymorphicEmbed, opts}}, _writable}} ->
        opts

      nil ->
        raise CompileError,
          description:
            "open_api_polymorphic_property(#{inspect(key)}) declared in " <>
              "#{inspect(parent_module)} but no matching polymorphic_embeds_one :#{key} " <>
              "found in the Ecto schema"
    end
  end

  defp check_variants_agree_with_ecto!(key, declared_variant_map, ecto_variant_map) do
    declared_wires = declared_variant_map |> Map.keys() |> MapSet.new()
    ecto_wires = ecto_variant_map |> Map.keys() |> MapSet.new()

    unless declared_wires == ecto_wires do
      raise CompileError,
        description:
          "open_api_polymorphic_property(#{inspect(key)}) :variants wire values " <>
            "#{inspect(MapSet.to_list(declared_wires))} do not match " <>
            "polymorphic_embeds_one :#{key} types " <>
            "#{inspect(MapSet.to_list(ecto_wires))}"
    end

    Enum.each(declared_variant_map, fn {wire, declared_mod} ->
      ecto_mod = Map.fetch!(ecto_variant_map, wire)

      unless declared_mod == ecto_mod do
        raise CompileError,
          description:
            "open_api_polymorphic_property(#{inspect(key)}) :variants wire value " <>
              "#{inspect(wire)} references #{inspect(declared_mod)} but " <>
              "polymorphic_embeds_one :#{key} maps it to #{inspect(ecto_mod)}"
      end
    end)

    :ok
  end

  defp fetch_parent_title!(parent_module) do
    case Module.get_attribute(parent_module, :open_api_schemas) do
      [%SchemaDefinition{title: title} | _] ->
        title

      _ ->
        raise CompileError,
          description:
            "open_api_polymorphic_property/1 on #{inspect(parent_module)} requires at " <>
              "least one open_api_schema/1 declaration so the library can derive the " <>
              "parent title used to namespace parent-contextual variant siblings"
    end
  end

  defp fetch_variant_reflection!(ecto_variant_mod) do
    Code.ensure_compiled!(ecto_variant_mod)

    unless function_exported?(ecto_variant_mod, :__ex_open_api_utils_schemas__, 0) do
      raise CompileError,
        description:
          "polymorphic variant #{inspect(ecto_variant_mod)} must `use ExOpenApiUtils` — " <>
            "it does not export __ex_open_api_utils_schemas__/0"
    end

    case ecto_variant_mod.__ex_open_api_utils_schemas__() do
      [entry | _] ->
        entry

      _ ->
        raise CompileError,
          description:
            "polymorphic variant #{inspect(ecto_variant_mod)} must have at least one " <>
              "open_api_schema/1 declaration so the library can read its title and " <>
              "submodule refs via __ex_open_api_utils_schemas__/0 reflection"
    end
  end

  defp parent_contextual_sibling_name(root_module, parent_title, variant_title, direction_suffix) do
    Module.concat([
      root_module,
      "OpenApiSchema",
      parent_title <> variant_title <> direction_suffix
    ])
  end

  @doc false
  # Generates one parent-contextual variant submodule per
  # (parent, variant, direction) triple via Module.create. Each new
  # module's schema body is `allOf: [<original variant submodule>,
  # <inline discriminator patch>]`, and `OpenApiSpex.schema/1`'s macro
  # walks that allOf via `Schema.properties/1` and builds a defstruct
  # that includes the discriminator field as a real atom key. No
  # `@open_api_properties` mutation — that's handled separately by
  # `__synthesize_polymorphic_properties__/3`.
  def __generate_parent_contextual_variants__(
        parent_module,
        polymorphic_decls,
        polymorphic_variants
      )
      when is_atom(parent_module) and is_list(polymorphic_decls) and
             is_map(polymorphic_variants) and map_size(polymorphic_variants) > 0 do
    for decl <- polymorphic_decls,
        entry = Map.fetch!(polymorphic_variants, decl.key),
        variant <- entry.variant_entries do
      discriminator_prop = %ExOpenApiUtils.Property{
        key: entry.discriminator_atom,
        source: entry.discriminator_atom,
        schema: %OpenApiSpex.Schema{type: :string, enum: [variant.wire]}
      }

      create_parent_contextual_sibling!(
        variant.original_request_submodule,
        variant.parent_contextual_request_submodule,
        entry.discriminator_atom,
        variant.wire,
        variant.request_property_attrs ++ [discriminator_prop]
      )

      create_parent_contextual_sibling!(
        variant.original_response_submodule,
        variant.parent_contextual_response_submodule,
        entry.discriminator_atom,
        variant.wire,
        variant.response_property_attrs ++ [discriminator_prop]
      )
    end

    :ok
  end

  def __generate_parent_contextual_variants__(
        _parent_module,
        _polymorphic_decls,
        _polymorphic_variants
      ),
      do: :ok

  defp create_parent_contextual_sibling!(
         original_submodule,
         new_sibling,
         discriminator_atom,
         wire_value,
         property_attrs
       ) do
    body = %{
      type: :object,
      allOf: [
        original_submodule,
        %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            discriminator_atom => %OpenApiSpex.Schema{type: :string, enum: [wire_value]}
          },
          required: [discriminator_atom]
        }
      ]
    }

    Module.create(
      new_sibling,
      quote do
        require OpenApiSpex
        OpenApiSpex.schema(unquote(Macro.escape(body)), derive?: false)
        unquote(ExOpenApiUtils.JasonEncoder.build_ast(property_attrs))
      end,
      Macro.Env.location(__ENV__)
    )
  end

  @doc false
  # Synthesises the writeOnly and readOnly %Property{} entries for a
  # single `open_api_polymorphic_property/1` declaration. These are
  # appended to the parent's `@open_api_properties` via normal
  # `Module.put_attribute` calls inside `__before_compile__` — no
  # attribute rewrite. Each property's `schema.oneOf` and
  # `schema.discriminator.mapping` already point at the parent-contextual
  # siblings, so the downstream `__submodule_spec__/4` loop picks them
  # up verbatim.
  def __synthesize_polymorphic_properties__(_parent_module, decl, polymorphic_variants) do
    entry = Map.fetch!(polymorphic_variants, decl.key)
    discriminator_string = entry.discriminator_string

    request_mapping =
      Enum.into(entry.variant_entries, %{}, fn variant ->
        {variant.wire, variant.parent_contextual_request_submodule}
      end)

    response_mapping =
      Enum.into(entry.variant_entries, %{}, fn variant ->
        {variant.wire, variant.parent_contextual_response_submodule}
      end)

    request_one_of =
      Enum.map(entry.variant_entries, & &1.parent_contextual_request_submodule)

    response_one_of =
      Enum.map(entry.variant_entries, & &1.parent_contextual_response_submodule)

    write_schema = %OpenApiSpex.Schema{
      type: :object,
      writeOnly: true,
      oneOf: request_one_of,
      discriminator: %OpenApiSpex.Discriminator{
        propertyName: discriminator_string,
        mapping: request_mapping
      }
    }

    read_schema = %OpenApiSpex.Schema{
      type: :object,
      readOnly: true,
      oneOf: response_one_of,
      discriminator: %OpenApiSpex.Discriminator{
        propertyName: discriminator_string,
        mapping: response_mapping
      }
    }

    write_prop = %Property{key: decl.key, source: decl.key, schema: write_schema}
    read_prop = %Property{key: decl.key, source: decl.key, schema: read_schema}

    {write_prop, read_prop}
  end

  def is_readOnly?(%OpenApiSpex.Schema{readOnly: readOnly}) do
    !!readOnly
  end

  def is_readOnly?(%OpenApiSpex.Reference{"$ref": ref}) do
    String.ends_with?(ref, "Response")
  end

  def is_readOnly?(module) do
    apply(module, :schema, [])
    |> is_readOnly?()
  end

  def is_writeOnly?(%OpenApiSpex.Schema{writeOnly: writeOnly}) do
    !!writeOnly
  end

  def is_writeOnly?(%OpenApiSpex.Reference{"$ref": ref}) do
    String.ends_with?(ref, "Request")
  end

  def is_writeOnly?(module) do
    apply(module, :schema, [])
    |> is_writeOnly?()
  end
end
