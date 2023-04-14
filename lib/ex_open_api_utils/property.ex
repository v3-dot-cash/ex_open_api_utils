defmodule ExOpenApiUtils.Property do
  defstruct schema: nil, key: nil

  @type t :: %__MODULE__{
          schema: OpenApiSpex.Schema.t() | module(),
          key: atom()
        }
  @enforce_keys [:key, :schema]
end
