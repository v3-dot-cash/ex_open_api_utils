defprotocol ExOpenApiUtils.Mapper do
  @fallback_to_any true
  @spec to_map(Ecto.Schema.t() | OpenApiSpex.Schema.t()) :: map() | list() | atom()
  def to_map(struct)
end

defimpl ExOpenApiUtils.Mapper, for: Any do
  defmacro __deriving__(module, _struct, opts) do
    property_attrs = Keyword.fetch!(opts, :property_attrs)
    map_direction = Keyword.fetch!(opts, :map_direction)
    polymorphic_variants = Keyword.get(opts, :polymorphic_variants, %{})

    quote do
      alias ExOpenApiUtils.Property

      defimpl ExOpenApiUtils.Mapper, for: unquote(module) do
        def to_map(arg) do
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

                raw_val = val
                val = val |> ExOpenApiUtils.Mapper.to_map()

                val =
                  ExOpenApiUtils.Mapper.Polymorphic.inject(
                    val,
                    raw_val,
                    property.key,
                    unquote(Macro.escape(polymorphic_variants)),
                    :from_ecto
                  )

                Map.put(acc, Atom.to_string(property.key), val)
              end)

            :from_open_api ->
              Enum.reduce(unquote(Macro.escape(property_attrs)), %{}, fn %Property{} = property,
                                                                         acc ->
                destination = property.source || property.key

                raw_val = Map.get(arg, property.key)
                val = raw_val |> ExOpenApiUtils.Mapper.to_map()

                val =
                  ExOpenApiUtils.Mapper.Polymorphic.inject(
                    val,
                    raw_val,
                    property.key,
                    unquote(Macro.escape(polymorphic_variants)),
                    :from_open_api
                  )

                if is_list(destination) do
                  [root | rest] = destination
                  exploded_map = ExOpenApiUtils.Mapper.Utils.explode_map(rest, val)

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

  def to_map(val) do
    val
  end
end

defimpl ExOpenApiUtils.Mapper, for: [Map] do
  def to_map(val) do
    Enum.reduce(val, %{}, fn {k, v}, acc ->
      Map.put(acc, k, ExOpenApiUtils.Mapper.to_map(v))
    end)
  end
end

defimpl ExOpenApiUtils.Mapper, for: [List] do
  def to_map(list) do
    Enum.map(list, &ExOpenApiUtils.Mapper.to_map/1)
  end
end

defimpl ExOpenApiUtils.Mapper, for: Ecto.Association.NotLoaded do
  def to_map(_val) do
    :not_loaded
  end
end

defmodule ExOpenApiUtils.Mapper.Utils do
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

defmodule ExOpenApiUtils.Mapper.Polymorphic do
  @moduledoc false

  # Injects a discriminator key into `val` when `property_key` is a polymorphic
  # field. Looks up the raw struct's module in the variant_map; if found, picks
  # the direction-appropriate injection key (string for :from_ecto, atom for
  # :from_open_api) and puts the wire value on the map.
  #
  # When the property is not polymorphic, `val` is returned unchanged.

  def inject(val, raw_val, property_key, polymorphic_variants, direction)
      when is_map(polymorphic_variants) and map_size(polymorphic_variants) > 0 do
    case Map.fetch(polymorphic_variants, property_key) do
      :error ->
        val

      {:ok, %{variant_map: variant_map, discriminator_string: disc_str, type_field_atom: type_atom}} ->
        with %struct_mod{} <- raw_val,
             {:ok, wire_value} <- Map.fetch(variant_map, struct_mod),
             true <- is_map(val) do
          case direction do
            :from_ecto -> Map.put(val, disc_str, wire_value)
            :from_open_api -> Map.put(val, type_atom, wire_value)
          end
        else
          _ -> val
        end
    end
  end

  def inject(val, _raw_val, _property_key, _polymorphic_variants, _direction), do: val
end
