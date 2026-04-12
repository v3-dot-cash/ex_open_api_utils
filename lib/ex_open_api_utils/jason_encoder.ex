defmodule ExOpenApiUtils.JasonEncoder do
  @moduledoc false

  # Builds a `defimpl Jason.Encoder` AST for a generated schema module.
  #
  # The generated encoder does an inline `Enum.reduce` over `property_attrs`,
  # applying nil-stripping via `Mapper.Utils.nil_aware_put/4`, and passes the
  # result to `Jason.Encode.map/2`. Nested struct values stay as structs —
  # `Jason.Encode.map` dispatches to their own Jason.Encoder impls lazily.
  def build_ast(property_attrs) do
    quote do
      if Code.ensure_loaded?(Jason.Encoder) do
        defimpl Jason.Encoder, for: __MODULE__ do
          def encode(struct, opts) do
            result =
              Enum.reduce(
                unquote(Macro.escape(property_attrs)),
                %{},
                fn %ExOpenApiUtils.Property{} = property, acc ->
                  val = Map.get(struct, property.key)

                  ExOpenApiUtils.Mapper.Utils.nil_aware_put(
                    acc,
                    Atom.to_string(property.key),
                    val,
                    property.schema
                  )
                end
              )

            Jason.Encode.map(result, opts)
          end
        end
      end
    end
  end
end
