defmodule ExOpenApiUtils do
  @moduledoc """
  Documentation for `ExOpenApiUtils`.
  """
  alias ExOpenApiUtils.Property

  defmacro __using__(_opts) do
    quote do
      import ExOpenApiUtils, only: [open_api_schema: 1]
      require ExOpenApiUtils
      @behaviour ExOpenApiUtils.Schema
      # for dependency <- unquote(dependencies) do
      #   create_schema(dependency)
      # end

      Module.register_attribute(__MODULE__, :open_api_property, accumulate: true)
      @after_compile ExOpenApiUtils
    end
  end

  defmacro open_api_schema(opts) do
    required_attrs = Keyword.get(opts, :required, [])
    title = Keyword.fetch!(opts, :title)
    description = Keyword.fetch!(opts, :description)
    type = Keyword.get(opts, :type, :object)

    quote do
      Module.put_attribute(__MODULE__, :open_api_schema, %{name: %{minLength: 10}})

      def __open_api_schema__() do
        [
          property_attrs: @open_api_property,
          required: unquote(required_attrs),
          type: unquote(type),
          description: unquote(description),
          title: unquote(title)
        ]
      end
    end
  end

  # defmacro create_schema(module) do
  #   quote do
  #     require Protocol

  #     [
  #       property_attrs: property_attrs,
  #       required: required,
  #       type: type,
  #       description: description,
  #       title: title
  #     ] = apply(unquote(module), :__open_api_schema__, [])

  #     example =
  #       Enum.reduce(property_attrs, %{}, fn %Property{} = property, acc ->
  #         example = OpenApiSpex.Schema.example(property.schema)
  #         Map.put(acc, Atom.to_string(property.key), example)
  #       end)

  #     properties =
  #       Enum.reduce(property_attrs, %{}, fn %Property{} = property, acc ->
  #         Map.put(acc, property.key, property.schema)
  #       end)

  #     module_name = Module.concat(unquote(module), "OpenApiSchema")

  #     body = %{
  #       title: title,
  #       type: type,
  #       required: required,
  #       description: description,
  #       properties: properties,
  #       example: example
  #     }

  #     contents =
  #       quote do
  #         require OpenApiSpex

  #         OpenApiSpex.schema(unquote(Macro.escape(body)))
  #       end

  #     quote do
  #       defimpl ExOpenApiUtils.Json, for: __MODULE__ do
  #         def to_json(arg) do
  #           unquote(Macro.escape(property_attrs))
  #         end
  #       end
  #     end

  #     Module.create(module_name, contents, Macro.Env.location(__ENV__))
  #   end
  # end

  defmacro __after_compile__(%{module: module}, _bytecode) do
    quote do
      require Protocol
      alias OpenApiSpex.Schema

      [
        property_attrs: property_attrs,
        required: required,
        type: type,
        description: description,
        title: title
      ] = apply(unquote(module), :__open_api_schema__, [])

      example =
        Enum.reduce(property_attrs, %{}, fn %Property{} = property, acc ->
          example = OpenApiSpex.Schema.example(property.schema)
          Map.put(acc, Atom.to_string(property.key), example)
        end)

      properties =
        Enum.reduce(property_attrs, %{}, fn %Property{} = property, acc ->
          Map.put(acc, property.key, property.schema)
        end)

      schema_module_name = Module.concat(unquote(module), "OpenApiSchema")
      request_module_name = Module.concat(unquote(module), "Request")
      response_module_name = Module.concat(unquote(module), "Response")
      list_response_module_name = Module.concat(unquote(module), "ListResponse")

      request_key = Inflex.underscore(title) |> String.to_atom()
      request_key_example = Inflex.underscore(title)

      body = %{
        title: title,
        type: type,
        required: required,
        description: description,
        properties: properties,
        example: example
      }

      contents =
        quote do
          require OpenApiSpex

          OpenApiSpex.schema(unquote(Macro.escape(body)))
        end

      Module.create(schema_module_name, contents, Macro.Env.location(__ENV__))

      body = %{
        title: Inflex.camelize(title <> "Request"),
        type: :object,
        description: description <> "Request Body",
        properties: %{request_key => schema_module_name},
        example: %{request_key_example => example}
      }

      contents =
        quote do
          require OpenApiSpex

          OpenApiSpex.schema(unquote(Macro.escape(body)))
        end

      Module.create(request_module_name, contents, Macro.Env.location(__ENV__))

      body = %{
        title: Inflex.camelize(title <> "Response"),
        type: :object,
        description: description <> "Response Body",
        properties: %{data: schema_module_name},
        example: %{"data" => example}
      }

      contents =
        quote do
          require OpenApiSpex

          OpenApiSpex.schema(unquote(Macro.escape(body)))
        end

      Module.create(response_module_name, contents, Macro.Env.location(__ENV__))

      body = %{
        title: Inflex.camelize(title <> "ListResponse"),
        type: :object,
        description: description <> "List Response Body",
        properties: %{
          data: %Schema{
            type: :array,
            description: "list of " <> title,
            items: [schema_module_name]
          }
        },
        example: %{"data" => [example]}
      }

      contents =
        quote do
          require OpenApiSpex

          OpenApiSpex.schema(unquote(Macro.escape(body)))
        end

      Module.create(list_response_module_name, contents, Macro.Env.location(__ENV__))

      Protocol.derive(ExOpenApiUtils.Json, __MODULE__, property_attrs: property_attrs)
    end
  end
end
