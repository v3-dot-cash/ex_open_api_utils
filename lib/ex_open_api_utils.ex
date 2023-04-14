defmodule ExOpenApiUtils do
  @moduledoc """
  Documentation for `ExOpenApiUtils`.
  """
  alias ExOpenApiUtils.Property

  defmacro __using__(opts \\ []) do

    dependencies = Keyword.get(opts, :dependencies, [])
    quote do
      import ExOpenApiUtils, only: [open_api_schema: 1, create_schema: 1]
      require ExOpenApiUtils
      @behaviour ExOpenApiUtils.Schema
      for dependency <- unquote(dependencies) do
        create_schema(dependency)
      end
      Module.register_attribute(__MODULE__, :open_api_property, accumulate: true)
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
          properties: @open_api_property,
          required: unquote(required_attrs),
          type: unquote(type),
          description: unquote(description),
          title: unquote(title)
        ]
      end
    end
  end

  def create_schema(module) do
    [
      properties: properties,
      required: required,
      type: type,
      description: description,
      title: title
    ] = apply(module, :__open_api_schema__, [])

    example =
      Enum.reduce(properties, %{}, fn %Property{} = property, acc ->
        example = OpenApiSpex.Schema.example(property.schema)
        Map.put(acc, Atom.to_string(property.key), example)
      end)

    properties =
      Enum.reduce(properties, %{}, fn %Property{} = property, acc ->
        Map.put(acc, property.key, property.schema)
      end)

    module_name = Module.concat(module, "OpenApiSchema")

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

    Module.create(module_name, contents, Macro.Env.location(__ENV__))
  end
end
