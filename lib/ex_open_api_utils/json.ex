defprotocol ExOpenApiUtils.Json do
  @spec to_json(Ecto.Schema.t()) :: map() | list() | atom()
  def to_json(struct)
end

defimpl ExOpenApiUtils.Json, for: Any do
  defmacro __deriving__(module, _struct, property_attrs: property_attrs) do
    quote do
      alias ExOpenApiUtils.Property

      defimpl ExOpenApiUtils.Json, for: unquote(module) do
        def to_json(arg) do
          Enum.reduce(unquote(Macro.escape(property_attrs)), %{}, fn %Property{} = property,
                                                                     acc ->
            source = property.source || property.key
            val = Map.get(arg, source) |> ExOpenApiUtils.Json.to_json()
            Map.put(acc, Atom.to_string(property.key), val)
          end)
        end
      end
    end
  end

  def to_json(_struct) do
    raise "protocol needs to be defined with properties"
  end
end

defimpl ExOpenApiUtils.Json,
  for: [
    Integer,
    String,
    BitString,
    Decimal,
    Date,
    Time,
    NaiveDateTime,
    DateTime
  ] do
  def to_json(val), do: val
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

defimpl ExOpenApiUtils.Json, for: Ecto.Association.NotLoaded  do
  def to_json(_val) do
    :not_loaded
  end
end
