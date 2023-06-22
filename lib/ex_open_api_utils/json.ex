defprotocol ExOpenApiUtils.Json do
  @fallback_to_any true
  @spec to_json(Ecto.Schema.t() | OpenApiSpex.Schema.t()) :: map() | list() | atom()
  def to_json(struct)
end

defimpl ExOpenApiUtils.Json, for: Any do
  defmacro __deriving__(module, _struct,
             property_attrs: property_attrs,
             map_direction: map_direction
           ) do
    quote do
      alias ExOpenApiUtils.Property

      defimpl ExOpenApiUtils.Json, for: unquote(module) do
        def to_json(arg) do
          case unquote(map_direction) do
            :from_ecto ->
              Enum.reduce(unquote(Macro.escape(property_attrs)), %{}, fn %Property{} = property,
                                                                         acc ->
                source = property.source || property.key

                val =
                  if is_list(source) do
                    Enum.reduce(source, arg, fn key, acc ->
                      if acc, do: Map.get(acc, key)
                    end)
                  else
                    Map.get(arg, source)
                  end

                val = val |> ExOpenApiUtils.Json.to_json()
                Map.put(acc, Atom.to_string(property.key), val)
              end)

            :from_open_api ->
              Enum.reduce(unquote(Macro.escape(property_attrs)), %{}, fn %Property{} = property,
                                                                         acc ->
                destination = property.source || property.key

                val = Map.get(arg, property.key)
                val = val |> ExOpenApiUtils.Json.to_json()

                if is_list(destination) do
                  [root | rest] = destination
                  exploded_map = ExOpenApiUtils.Json.Utils.explode_map(rest, val)

                  Map.update(acc, root, %{}, fn existing ->
                    Map.merge(existing, exploded_map)
                  end)
                else
                  Map.put(acc, destination, val)
                end
              end)
          end
        end
      end
    end
  end

  def to_json(val) do
    val
  end
end

defimpl ExOpenApiUtils.Json, for: [Map] do
  def to_json(val) do
    Enum.reduce(val, %{}, fn {k, v}, acc ->
      Map.put(acc, k, ExOpenApiUtils.Json.to_json(v))
    end)
  end
end

defimpl ExOpenApiUtils.Json, for: [List] do
  def to_json(list) do
    Enum.map(list, &ExOpenApiUtils.Json.to_json/1)
  end
end

defimpl ExOpenApiUtils.Json, for: Ecto.Association.NotLoaded do
  def to_json(_val) do
    :not_loaded
  end
end

defmodule ExOpenApiUtils.Json.Utils do
  def explode_map(key, val) when is_atom(key) do
    %{key => val}
  end

  def explode_map([root | rest], val) do
    %{root => explode_map(rest, val)}
  end
  def explode_map([], val) do
    val
  end
end
