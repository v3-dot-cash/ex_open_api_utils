defmodule ExOpenApiUtils do
  @moduledoc """
  Documentation for `ExOpenApiUtils`.
  """
  alias ExOpenApiUtils.Property
  alias ExOpenApiUtils.SchemaDefinition
  require Protocol

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      require ExOpenApiUtils

      import ExOpenApiUtils,
        only: [open_api_schema: 1, open_api_property: 1]

      alias OpenApiSpex.Schema
      alias ExOpenApiUtils.Helpers
      import Ecto.Changeset, except: [cast: 4, cast: 3]
      import ExOpenApiUtils.Changeset, only: [cast: 4, cast: 3]

      Module.register_attribute(__MODULE__, :open_api_properties, accumulate: true)
      Module.register_attribute(__MODULE__, :open_api_schemas, accumulate: true)

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
        type: unquote(type)
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

  defmacro __before_compile__(%{module: module}) do
    quote do
      require Protocol
      alias OpenApiSpex.Schema

      example =
        Enum.reduce(@open_api_properties, %{}, fn %Property{} = property, acc ->
          example = OpenApiSpex.Schema.example(property.schema)
          Map.put(acc, Atom.to_string(property.key), example)
        end)

      properties =
        Enum.reduce(@open_api_properties, %{}, fn %Property{} = property, acc ->
          Map.put(acc, property.key, property.schema)
        end)

      [root_module | _] = Module.split(unquote(module))

      alias ExOpenApiUtils.SchemaDefinition

      for %SchemaDefinition{} = schema_definition <- @open_api_schemas do
        title = schema_definition.title
        description = schema_definition.description

        request_module_name = Module.concat([root_module, "OpenApiSchema", "#{title}Request"])

        request_properties =
          Enum.filter(@open_api_properties, fn %Property{} = property ->
            property.key in schema_definition.properties &&
              !ExOpenApiUtils.is_readOnly?(property.schema)
          end)

        request_properties_map =
          Enum.reduce(request_properties, %{}, fn %Property{} = property, acc ->
            Map.put(acc, property.key, property.schema)
          end)

        request_example =
          Enum.reduce(request_properties, %{}, fn %Property{} = property, acc ->
            example = OpenApiSpex.Schema.example(property.schema)
            Map.put(acc, Atom.to_string(property.key), example)
          end)

        request_properties_keys = Map.keys(request_properties_map)

        request_required_properties =
          Enum.filter(schema_definition.required, &(&1 in request_properties_keys))

        request_order =
          Enum.filter(schema_definition.properties, &(&1 in request_properties_keys))

        body = %{
          title: Inflex.camelize(title <> "Request"),
          type: :object,
          description: description <> " Request",
          required: request_required_properties,
          properties: request_properties_map,
          tags: schema_definition.tags,
          writeOnly: true,
          example: request_example,
          extensions: %{
            "x-order" => request_order
          }
        }

        request_module_contents =
          quote do
            require OpenApiSpex

            OpenApiSpex.schema(unquote(Macro.escape(body)))
          end

        Module.create(request_module_name, request_module_contents, Macro.Env.location(__ENV__))

        Protocol.derive(ExOpenApiUtils.Mapper, request_module_name,
          property_attrs: request_properties,
          map_direction: :from_open_api
        )

        response_module_name = Module.concat([root_module, "OpenApiSchema", "#{title}Response"])

        response_properties =
          Enum.filter(@open_api_properties, fn %Property{} = property ->
            property.key in schema_definition.properties &&
              !ExOpenApiUtils.is_writeOnly?(property.schema)
          end)

        response_properties_map =
          Enum.reduce(response_properties, %{}, fn %Property{} = property, acc ->
            Map.put(acc, property.key, property.schema)
          end)

        response_example =
          Enum.reduce(response_properties, %{}, fn %Property{} = property, acc ->
            example = OpenApiSpex.Schema.example(property.schema)
            Map.put(acc, Atom.to_string(property.key), example)
          end)

        response_properties_keys = Map.keys(response_properties_map)

        response_required_properties =
          Enum.filter(schema_definition.required, &(&1 in response_properties_keys))

        response_order =
          Enum.filter(schema_definition.properties, &(&1 in response_properties_keys))

        body = %{
          title: Inflex.camelize(title <> "Response"),
          type: schema_definition.type,
          required: response_required_properties,
          description: description,
          properties: response_properties_map,
          tags: schema_definition.tags,
          readOnly: true,
          example: response_example,
          extensions: %{
            "x-order" => response_order
          }
        }

        response_module_contents =
          quote do
            require OpenApiSpex

            OpenApiSpex.schema(unquote(Macro.escape(body)))
          end

        Module.create(response_module_name, response_module_contents, Macro.Env.location(__ENV__))

        Protocol.derive(ExOpenApiUtils.Mapper, response_module_name,
          property_attrs: response_properties,
          map_direction: :from_open_api
        )
      end

      exported_properties =
        Enum.filter(@open_api_properties, fn %Property{} = property ->
          !ExOpenApiUtils.is_writeOnly?(property.schema)
        end)

      Protocol.derive(ExOpenApiUtils.Mapper, __MODULE__,
        property_attrs: exported_properties,
        map_direction: :from_ecto
      )
    end
  end

  def is_readOnly?(%OpenApiSpex.Schema{readOnly: readOnly}) do
    !!readOnly
  end

  def is_readOnly?(module) do
    apply(module, :schema, [])
    |> is_readOnly?()
  end

  def is_writeOnly?(%OpenApiSpex.Schema{writeOnly: writeOnly}) do
    !!writeOnly
  end

  def is_writeOnly?(module) do
    apply(module, :schema, [])
    |> is_writeOnly?()
  end
end
