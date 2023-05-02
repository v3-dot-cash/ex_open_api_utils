defmodule ExOpenApiUtils do
  @moduledoc """
  Documentation for `ExOpenApiUtils`.
  """
  alias ExOpenApiUtils.Property
  alias ExOpenApiUtils.SchemaDefinition
  require Protocol

  defmacro __using__(_opts) do
    quote do
      require ExOpenApiUtils

      import ExOpenApiUtils,
        only: [open_api_schema: 1, open_api_property: 1]

      Module.register_attribute(__MODULE__, :open_api_properties, accumulate: true)
      Module.register_attribute(__MODULE__, :open_api_schemas, accumulate: true)

      @after_compile ExOpenApiUtils
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

  defmacro __after_compile__(%{module: module}, _bytecode) do
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

        request_module_name = Module.concat([root_module,"OpenApiSchema" ,"#{title}Request"])
        response_module_name = Module.concat([root_module,"OpenApiSchema", "#{title}Response"])

        properties = Map.take(properties, schema_definition.properties)

        example =
          Map.filter(example, fn {k, _v} ->
            String.to_atom(k) in schema_definition.properties
          end)

        editable_properties =
          Map.filter(properties, fn {_k, v} ->
            !is_map(v) || !Map.get(v, :readOnly, false)
          end)

        editable_prop_example =
          Map.filter(example, fn {k, _v} ->
            prop_key = String.to_atom(k)
            Map.has_key?(editable_properties, prop_key)
          end)

        body = %{
          title: Inflex.camelize(title <> "Request"),
          type: :object,
          description: description <> " Request",
          properties: editable_properties,
          tags: schema_definition.tags,
          example: editable_prop_example
        }

        contents =
          quote do
            require OpenApiSpex

            OpenApiSpex.schema(unquote(Macro.escape(body)))
          end

        Module.create(request_module_name, contents, Macro.Env.location(__ENV__))

        readable_properties =
          Map.filter(properties, fn {_k, v} ->
            !is_map(v) || !Map.get(v, :writeOnly, false)
          end)

        readable_prop_example =
          Map.filter(example, fn {k, _v} ->
            prop_key = String.to_atom(k)
            Map.has_key?(readable_properties, prop_key)
          end)

        body = %{
          title: Inflex.camelize(title <> "Response"),
          type: schema_definition.type,
          required: schema_definition.required,
          description: description,
          properties: readable_properties,
          tags: schema_definition.tags,
          example: readable_prop_example
        }

        contents =
          quote do
            require OpenApiSpex

            OpenApiSpex.schema(unquote(Macro.escape(body)))
          end

        Module.create(response_module_name, contents, Macro.Env.location(__ENV__))
      end

      exported_properties =
        Enum.filter(@open_api_properties, fn %Property{} = property ->
          !property.schema.writeOnly
        end)

      Protocol.derive(ExOpenApiUtils.Json, __MODULE__, property_attrs: exported_properties)
    end
  end
end
