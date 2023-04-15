defprotocol ExOpenApiUtils.Json do
  @spec to_json(Ecto.Schema.t()) :: map()
  def to_json(struct)
end

defimpl ExOpenApiUtils.Json, for: Any do
  defmacro __deriving__(module, _struct, property_attrs: property_attrs) do
    quote do
      defimpl ExOpenApiUtils.Json, for: unquote(module) do
        def to_json(arg) do
          unquote(Macro.escape(property_attrs))
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
    DateTime,
    :integer,
    :binary,
    :float,
    :boolean,
    :binary
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
