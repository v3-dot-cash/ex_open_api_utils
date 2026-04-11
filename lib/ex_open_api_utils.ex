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
  `oneOf + discriminator` composition. The bridge is two parts: write two
  `open_api_property` calls for the polymorphic field (one `writeOnly` with
  `*Request` variant submodules, one `readOnly` with `*Response` variant
  submodules), then declare the bridge with `polymorphic_embed_discriminator/1`.

  See `polymorphic_embed_discriminator/1` for the full shape.
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
          polymorphic_embed_discriminator: 1
        ]

      alias ExOpenApiUtils.Helpers
      alias ExOpenApiUtils.Tag
      alias OpenApiSpex.Schema
      import Ecto.Changeset, except: [cast: 4, cast: 3]
      import ExOpenApiUtils.Changeset, only: [cast: 4, cast: 3]

      Module.register_attribute(__MODULE__, :open_api_properties, accumulate: true)
      Module.register_attribute(__MODULE__, :open_api_schemas, accumulate: true)

      Module.register_attribute(__MODULE__, :polymorphic_embed_declarations, accumulate: true)

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
  Declares the bridge between a `polymorphic_embeds_one` field and its
  corresponding `oneOf + discriminator` `open_api_property` pair.

  Use this macro on the parent schema, next to (or near) the matching
  `polymorphic_embeds_one` declaration. The library cross-checks at compile
  time that the Ecto side and the OpenAPI side agree on variants, wire values,
  and the discriminator property name.

  ## Options

    * `:key` (required) — atom. The field name on the parent that is both a
      `polymorphic_embeds_one` and the key of the two `open_api_property`
      entries (one `writeOnly`, one `readOnly`).
    * `:type_field_name` (required) — atom. Must match the `type_field_name:`
      option passed to `polymorphic_embeds_one`. This is the atom key that
      `cast_polymorphic_embed/3` reads from the flattened params map. It may
      differ from the OpenAPI discriminator `propertyName:` (which lives on
      the wire as a string); the library bridges the two names.

  ## Example

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

      polymorphic_embed_discriminator(
        key: :channel,
        type_field_name: :__type__
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
  defmacro polymorphic_embed_discriminator(opts) do
    key = Keyword.fetch!(opts, :key)
    type_field_name = Keyword.fetch!(opts, :type_field_name)

    unless is_atom(key) do
      raise ArgumentError,
            "polymorphic_embed_discriminator :key must be an atom, got: #{inspect(key)}"
    end

    unless is_atom(type_field_name) do
      raise ArgumentError,
            "polymorphic_embed_discriminator :type_field_name must be an atom, got: " <>
              inspect(type_field_name)
    end

    quote do
      Module.put_attribute(
        __MODULE__,
        :polymorphic_embed_declarations,
        %{key: unquote(key), type_field_name: unquote(type_field_name)}
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
          @polymorphic_embed_declarations,
          @open_api_properties,
          @ecto_fields
        )

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
            OpenApiSpex.schema(unquote(Macro.escape(request_body)))
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
            OpenApiSpex.schema(unquote(Macro.escape(response_body)))
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
                                             @open_api_schemas
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
  def __schemas_index__(module, schemas) do
    [root_module | _] = Module.split(module)

    Enum.map(schemas, fn %SchemaDefinition{title: title} ->
      %{
        title: title,
        request_module: Module.concat([root_module, "OpenApiSchema", "#{title}Request"]),
        response_module: Module.concat([root_module, "OpenApiSchema", "#{title}Response"])
      }
    end)
  end

  @doc false
  # Builds the polymorphic_variants map consumed by the Mapper derive calls.
  #
  # Scans @polymorphic_embed_declarations, and for each entry:
  #   1. locates the matching polymorphic_embeds_one field in @ecto_fields
  #   2. locates the writeOnly + readOnly open_api_property entries for the key
  #   3. cross-checks discriminator propertyName agreement
  #   4. cross-checks type_field_name agreement with polymorphic_embed
  #   5. cross-checks wire value sets across all three sources
  #   6. cross-checks oneOf/mapping agree within each open_api_property
  #   7. cross-checks submodule refs resolve back to the Ecto variant modules
  #      via each variant's __ex_open_api_utils_schemas__/0 reflection helper
  #   8. builds the unified variant_map keyed by all three struct flavors
  #
  # Any failure raises a CompileError whose message names the specific item
  # that diverges.
  def __build_polymorphic_variants__(parent_module, declarations, properties, ecto_fields) do
    declarations
    |> Enum.reverse()
    |> Enum.reduce(%{}, fn decl, acc ->
      entry = build_one_polymorphic_entry!(parent_module, decl, properties, ecto_fields)
      Map.put(acc, decl.key, entry)
    end)
  end

  defp build_one_polymorphic_entry!(parent_module, decl, properties, ecto_fields) do
    %{key: key, type_field_name: type_field_name} = decl

    ecto_opts = fetch_polymorphic_embed_opts!(parent_module, key, ecto_fields)

    unless ecto_opts.type_field_name == type_field_name do
      raise CompileError,
        description:
          "polymorphic_embed_discriminator(#{inspect(key)}) declares :type_field_name " <>
            "#{inspect(type_field_name)} but polymorphic_embeds_one :#{key} declares " <>
            ":type_field_name #{inspect(ecto_opts.type_field_name)} — they must match"
    end

    ecto_variant_map =
      Enum.into(ecto_opts.types_metadata, %{}, fn %{type: type, module: mod} ->
        {to_string(type), mod}
      end)

    ecto_wire_values = ecto_variant_map |> Map.keys() |> MapSet.new()

    key_properties = Enum.filter(properties, &(&1.key == key))

    {write_prop, read_prop} = fetch_directional_properties!(key, key_properties)

    discriminator_string =
      fetch_matching_discriminator_property_name!(key, write_prop, read_prop)

    check_oneof_matches_mapping!(key, :writeOnly, write_prop.schema)
    check_oneof_matches_mapping!(key, :readOnly, read_prop.schema)

    request_mod_by_wire = map_wire_to_modules!(key, :writeOnly, write_prop.schema)
    response_mod_by_wire = map_wire_to_modules!(key, :readOnly, read_prop.schema)

    check_wire_values_agree!(
      key,
      ecto_wire_values,
      request_mod_by_wire |> Map.keys() |> MapSet.new(),
      response_mod_by_wire |> Map.keys() |> MapSet.new()
    )

    check_submodules_match_reflection!(
      key,
      ecto_variant_map,
      request_mod_by_wire,
      response_mod_by_wire
    )

    variant_map =
      ecto_variant_map
      |> Enum.flat_map(fn {wire, ecto_mod} ->
        req = Map.fetch!(request_mod_by_wire, wire)
        res = Map.fetch!(response_mod_by_wire, wire)
        [{ecto_mod, wire}, {req, wire}, {res, wire}]
      end)
      |> Map.new()

    # Store the atom form of the discriminator propertyName in the
    # returned map. This map flows through
    # `Protocol.derive(..., polymorphic_variants: ...)` which passes it
    # to `ExOpenApiUtils.Mapper.__deriving__/3`, where `Macro.escape/1`
    # pins the whole map as a literal inside the generated Mapper impl's
    # `to_map/1` body. Elixir's compiler stashes that literal in the
    # module's LitT (literal pool) chunk, and the BEAM loader
    # materialises every atom inside the literal pool at module-load
    # time — so `:object_type` (or whatever the user declared) is
    # present in the runtime atom table the moment the compiled `.beam`
    # file is loaded, even in a freshly-started BEAM that has never run
    # the library's compile-time `__before_compile__` hook.
    # See GH-27 for the bug this fixes.
    %{
      variant_map: variant_map,
      discriminator_string: discriminator_string,
      discriminator_atom: String.to_atom(discriminator_string),
      type_field_atom: type_field_name
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
            "polymorphic_embed_discriminator(#{inspect(key)}) declared in " <>
              "#{inspect(parent_module)} but no matching polymorphic_embeds_one :#{key} " <>
              "found in the Ecto schema"
    end
  end

  defp fetch_directional_properties!(key, key_properties) do
    write = Enum.find(key_properties, &is_writeOnly?(&1.schema))
    read = Enum.find(key_properties, &is_readOnly?(&1.schema))

    cond do
      is_nil(write) ->
        raise CompileError,
          description:
            "polymorphic_embed_discriminator(#{inspect(key)}) requires a writeOnly " <>
              "open_api_property with the same :key — none found"

      is_nil(read) ->
        raise CompileError,
          description:
            "polymorphic_embed_discriminator(#{inspect(key)}) requires a readOnly " <>
              "open_api_property with the same :key — none found"

      true ->
        check_is_polymorphic_schema!(key, :writeOnly, write.schema)
        check_is_polymorphic_schema!(key, :readOnly, read.schema)
        {write, read}
    end
  end

  defp check_is_polymorphic_schema!(key, direction, %OpenApiSpex.Schema{} = schema) do
    cond do
      is_nil(schema.oneOf) ->
        raise CompileError,
          description:
            "polymorphic_embed_discriminator(#{inspect(key)}) #{direction} schema " <>
              "must have :oneOf set"

      is_nil(schema.discriminator) ->
        raise CompileError,
          description:
            "polymorphic_embed_discriminator(#{inspect(key)}) #{direction} schema " <>
              "must have :discriminator set"

      schema.type != :object ->
        raise CompileError,
          description:
            "polymorphic_embed_discriminator(#{inspect(key)}) #{direction} schema " <>
              "must have type: :object (this is the OpenApiSpex dispatch gate)"

      true ->
        :ok
    end
  end

  defp check_is_polymorphic_schema!(key, direction, other) do
    raise CompileError,
      description:
        "polymorphic_embed_discriminator(#{inspect(key)}) #{direction} property " <>
          "schema must be an %OpenApiSpex.Schema{}, got: #{inspect(other)}"
  end

  defp fetch_matching_discriminator_property_name!(key, write_prop, read_prop) do
    w_name = write_prop.schema.discriminator.propertyName
    r_name = read_prop.schema.discriminator.propertyName

    cond do
      is_nil(w_name) or w_name == "" ->
        raise CompileError,
          description:
            "polymorphic_embed_discriminator(#{inspect(key)}) writeOnly schema " <>
              "discriminator.propertyName must be a non-empty string"

      is_nil(r_name) or r_name == "" ->
        raise CompileError,
          description:
            "polymorphic_embed_discriminator(#{inspect(key)}) readOnly schema " <>
              "discriminator.propertyName must be a non-empty string"

      w_name != r_name ->
        raise CompileError,
          description:
            "polymorphic_embed_discriminator(#{inspect(key)}) writeOnly and readOnly " <>
              "schemas must share the same discriminator.propertyName — got " <>
              "#{inspect(w_name)} vs #{inspect(r_name)}"

      true ->
        w_name
    end
  end

  defp check_oneof_matches_mapping!(key, direction, %OpenApiSpex.Schema{
         oneOf: one_of,
         discriminator: %OpenApiSpex.Discriminator{mapping: mapping}
       }) do
    one_of_set = MapSet.new(one_of)
    mapping_set = mapping |> Map.values() |> MapSet.new()

    unless one_of_set == mapping_set do
      raise CompileError,
        description:
          "polymorphic_embed_discriminator(#{inspect(key)}) #{direction} schema " <>
            "oneOf entries and discriminator.mapping values must match 1:1 — got " <>
            "oneOf=#{inspect(MapSet.to_list(one_of_set))} vs mapping values " <>
            "#{inspect(MapSet.to_list(mapping_set))}"
    end

    :ok
  end

  defp map_wire_to_modules!(key, direction, %OpenApiSpex.Schema{
         discriminator: %OpenApiSpex.Discriminator{mapping: mapping}
       }) do
    Enum.reduce(mapping, %{}, fn {wire, mod}, acc ->
      unless is_atom(mod) do
        raise CompileError,
          description:
            "polymorphic_embed_discriminator(#{inspect(key)}) #{direction} schema " <>
              "discriminator.mapping values must be module atoms, got: #{inspect(mod)} " <>
              "for wire value #{inspect(wire)}"
      end

      Map.put(acc, wire, mod)
    end)
  end

  defp check_wire_values_agree!(key, ecto_set, req_set, res_set) do
    if ecto_set != req_set or ecto_set != res_set do
      raise CompileError,
        description:
          "polymorphic_embed_discriminator(#{inspect(key)}) wire value sets must " <>
            "match across all three sources — polymorphic_embeds_one: " <>
            "#{inspect(MapSet.to_list(ecto_set))}, writeOnly mapping: " <>
            "#{inspect(MapSet.to_list(req_set))}, readOnly mapping: " <>
            "#{inspect(MapSet.to_list(res_set))}"
    end

    :ok
  end

  defp check_submodules_match_reflection!(
         key,
         ecto_variant_map,
         request_mod_by_wire,
         response_mod_by_wire
       ) do
    Enum.each(ecto_variant_map, fn {wire, ecto_mod} ->
      Code.ensure_compiled!(ecto_mod)

      unless function_exported?(ecto_mod, :__ex_open_api_utils_schemas__, 0) do
        raise CompileError,
          description:
            "polymorphic_embed_discriminator(#{inspect(key)}) variant module " <>
              "#{inspect(ecto_mod)} must `use ExOpenApiUtils` — it does not export " <>
              "__ex_open_api_utils_schemas__/0"
      end

      variant_schemas = ecto_mod.__ex_open_api_utils_schemas__()

      {expected_request, expected_response} =
        case variant_schemas do
          [%{request_module: req, response_module: res} | _] ->
            {req, res}

          _ ->
            raise CompileError,
              description:
                "polymorphic_embed_discriminator(#{inspect(key)}) variant module " <>
                  "#{inspect(ecto_mod)} has no open_api_schema defined"
        end

      actual_request = Map.fetch!(request_mod_by_wire, wire)
      actual_response = Map.fetch!(response_mod_by_wire, wire)

      if actual_request != expected_request do
        raise CompileError,
          description:
            "polymorphic_embed_discriminator(#{inspect(key)}) wire value " <>
              "#{inspect(wire)} writeOnly mapping references " <>
              "#{inspect(actual_request)} but variant #{inspect(ecto_mod)} expects " <>
              "#{inspect(expected_request)}"
      end

      if actual_response != expected_response do
        raise CompileError,
          description:
            "polymorphic_embed_discriminator(#{inspect(key)}) wire value " <>
              "#{inspect(wire)} readOnly mapping references " <>
              "#{inspect(actual_response)} but variant #{inspect(ecto_mod)} expects " <>
              "#{inspect(expected_response)}"
      end
    end)

    :ok
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
