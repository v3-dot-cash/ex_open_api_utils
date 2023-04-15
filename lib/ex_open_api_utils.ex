defmodule ExOpenApiUtils do
  @moduledoc """
  Documentation for `ExOpenApiUtils`.
  """
  alias ExOpenApiUtils.Property

  defmacro __using__(opts \\ []) do
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

      module_name = Module.concat(unquote(module), "OpenApiSchema")

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

      Protocol.derive(ExOpenApiUtils.Json, __MODULE__, property_attrs: property_attrs)

      Module.create(module_name, contents, Macro.Env.location(__ENV__))
    end
  end
end
