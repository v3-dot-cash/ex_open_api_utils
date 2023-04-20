defmodule ExOpenApiUtils do
  @moduledoc """
  Documentation for `ExOpenApiUtils`.
  """
  alias ExOpenApiUtils.Property
  alias ExOpenApiUtils.SchemaDefinition

  defmacro __using__(_opts) do
    quote do
      require ExOpenApiUtils
      import ExOpenApiUtils, only: [open_api_schema: 1, open_api_property: 1]

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

  defmacro __after_compile__(%{module: _module}, _bytecode) do
    quote do
      IO.inspect(@open_api_properties)
      IO.inspect(@open_api_schemas)
    end

    # quote do
    #   require Protocol
    #   alias OpenApiSpex.Schema

    #   [
    #     property_attrs: property_attrs,
    #     required: required,
    #     type: type,
    #     description: description,
    #     title: title
    #   ] = apply(unquote(module), :__open_api_schema__, [])

    #   example =
    #     Enum.reduce(property_attrs, %{}, fn %Property{} = property, acc ->
    #       example = OpenApiSpex.Schema.example(property.schema)
    #       Map.put(acc, Atom.to_string(property.key), example)
    #     end)

    #   properties =
    #     Enum.reduce(property_attrs, %{}, fn %Property{} = property, acc ->
    #       Map.put(acc, property.key, property.schema)
    #     end)

    #   schema_module_name = Module.concat(unquote(module), "OpenApiSchema")
    #   request_module_name = Module.concat(unquote(module), "Request")
    #   response_module_name = Module.concat(unquote(module), "Response")
    #   list_response_module_name = Module.concat(unquote(module), "ListResponse")

    #   request_key = Inflex.underscore(title) |> String.to_atom()
    #   request_key_example = Inflex.underscore(title)

    #   body = %{
    #     title: title,
    #     type: type,
    #     required: required,
    #     description: description,
    #     properties: properties,
    #     example: example
    #   }

    #   contents =
    #     quote do
    #       require OpenApiSpex

    #       OpenApiSpex.schema(unquote(Macro.escape(body)))
    #     end

    #   Module.create(schema_module_name, contents, Macro.Env.location(__ENV__))

    #   body = %{
    #     title: Inflex.camelize(title <> "Request"),
    #     type: :object,
    #     description: description <> "Request Body",
    #     properties: %{request_key => schema_module_name},
    #     example: %{request_key_example => example}
    #   }

    #   contents =
    #     quote do
    #       require OpenApiSpex

    #       OpenApiSpex.schema(unquote(Macro.escape(body)))
    #     end

    #   Module.create(request_module_name, contents, Macro.Env.location(__ENV__))

    #   body = %{
    #     title: Inflex.camelize(title <> "Response"),
    #     type: :object,
    #     description: description <> "Response Body",
    #     properties: %{data: schema_module_name},
    #     example: %{"data" => example}
    #   }

    #   contents =
    #     quote do
    #       require OpenApiSpex

    #       OpenApiSpex.schema(unquote(Macro.escape(body)))
    #     end

    #   Module.create(response_module_name, contents, Macro.Env.location(__ENV__))

    #   body = %{
    #     title: Inflex.camelize(title <> "ListResponse"),
    #     type: :object,
    #     description: description <> "List Response Body",
    #     properties: %{
    #       data: %Schema{
    #         type: :array,
    #         description: "list of " <> title,
    #         items: schema_module_name
    #       }
    #     },
    #     example: %{"data" => [example]}
    #   }

    #   contents =
    #     quote do
    #       require OpenApiSpex

    #       OpenApiSpex.schema(unquote(Macro.escape(body)))
    #     end

    #   Module.create(list_response_module_name, contents, Macro.Env.location(__ENV__))

    #   Protocol.derive(ExOpenApiUtils.Json, __MODULE__, property_attrs: property_attrs)
    # end
  end
end
