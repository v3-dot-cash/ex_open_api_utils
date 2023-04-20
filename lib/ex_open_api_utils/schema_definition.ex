defmodule ExOpenApiUtils.SchemaDefinition do
  defstruct title: nil, required: [], properties: [], description: "", tags: [], type: :object

  @type t :: %__MODULE__{
          title: bitstring(),
          required: list(atom()),
          properties: list(atom()),
          description: bitstring(),
          tags: list(String.t()),
          type: atom()
        }
  @enforce_keys [:title, :description]
end
