defmodule ExOpenApiUtils.Property do
  @enforce_keys [:key, :schema]
  defstruct schema: nil, key: nil, source: nil

  @type t :: %__MODULE__{
          schema: OpenApiSpex.Schema.t() | module(),
          key: atom(),
          source: atom()
        }
end
