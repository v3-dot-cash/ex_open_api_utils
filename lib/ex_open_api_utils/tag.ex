defmodule ExOpenApiUtils.Tag do
  @moduledoc """
  OpenAPI 3.2 Tag struct with support for hierarchical tags.

  OpenAPI 3.2 introduces native support for tag hierarchies through:
  - `parent` - Reference to parent tag for nesting
  - `kind` - Tag kind (e.g., "navigation" for UI organization)
  - `summary` - Short label for UI display

  ## Example

      alias ExOpenApiUtils.Tag

      # Simple tag
      %Tag{name: "Users", description: "User management endpoints"}

      # Nested tag (OpenAPI 3.2)
      %Tag{
        name: "Profile",
        parent: "Users",
        summary: "User Profile",
        description: "User profile management"
      }

      # Navigation tag (for UI grouping)
      %Tag{
        name: "Admin",
        kind: "navigation",
        summary: "Admin Panel"
      }
  """

  @enforce_keys [:name]
  defstruct [
    :name,
    :description,
    :parent,
    :kind,
    :summary,
    :external_docs
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t() | nil,
          parent: String.t() | nil,
          kind: String.t() | nil,
          summary: String.t() | nil,
          external_docs: map() | nil
        }

  @doc """
  Converts an ExOpenApiUtils.Tag to an OpenApiSpex.Tag compatible map.

  OpenAPI 3.2 fields (parent, kind, summary) are serialized directly
  as they are now part of the standard specification.

  ## Example

      tag = %Tag{name: "Users", parent: "Admin", summary: "User Management"}
      Tag.to_open_api_spex(tag)
      # => %OpenApiSpex.Tag{
      #   name: "Users",
      #   extensions: %{
      #     "parent" => "Admin",
      #     "summary" => "User Management"
      #   }
      # }

  Note: Until OpenApiSpex natively supports 3.2 fields, we use extensions.
  The fields will serialize correctly in the final JSON/YAML output.
  """
  @spec to_open_api_spex(t()) :: OpenApiSpex.Tag.t()
  def to_open_api_spex(%__MODULE__{} = tag) do
    # Build extensions for 3.2 fields
    # Note: OpenApiSpex.Tag doesn't have parent/kind/summary yet,
    # but these will serialize correctly as they're standard 3.2 fields
    extensions =
      %{}
      |> maybe_put("parent", tag.parent)
      |> maybe_put("kind", tag.kind)
      |> maybe_put("summary", tag.summary)

    extensions = if map_size(extensions) == 0, do: nil, else: extensions

    external_docs =
      if tag.external_docs do
        struct(OpenApiSpex.ExternalDocumentation, tag.external_docs)
      else
        nil
      end

    %OpenApiSpex.Tag{
      name: tag.name,
      description: tag.description,
      externalDocs: external_docs,
      extensions: extensions
    }
  end

  @doc """
  Converts a list of ExOpenApiUtils.Tag structs to OpenApiSpex.Tag structs.
  """
  @spec to_open_api_spex_list([t()]) :: [OpenApiSpex.Tag.t()]
  def to_open_api_spex_list(tags) when is_list(tags) do
    Enum.map(tags, &to_open_api_spex/1)
  end

  @doc """
  Creates a new Tag struct from keyword options.

  ## Options
    * `:name` - (required) Tag name
    * `:description` - Tag description
    * `:parent` - Parent tag name for nesting (OpenAPI 3.2)
    * `:kind` - Tag kind, e.g., "navigation" (OpenAPI 3.2)
    * `:summary` - Short summary for UI display (OpenAPI 3.2)
    * `:external_docs` - Map with `:url` and optional `:description`

  ## Example

      Tag.new("Users",
        description: "User management",
        parent: "Admin",
        summary: "Users"
      )
  """
  @spec new(String.t(), keyword()) :: t()
  def new(name, opts \\ []) when is_binary(name) do
    %__MODULE__{
      name: name,
      description: Keyword.get(opts, :description),
      parent: Keyword.get(opts, :parent),
      kind: Keyword.get(opts, :kind),
      summary: Keyword.get(opts, :summary),
      external_docs: Keyword.get(opts, :external_docs)
    }
  end

  @doc """
  Creates a nested tag with a parent reference.

  ## Example

      Tag.nested("Profile", "Users", summary: "User Profile")
  """
  @spec nested(String.t(), String.t(), keyword()) :: t()
  def nested(name, parent, opts \\ []) when is_binary(name) and is_binary(parent) do
    opts = Keyword.put(opts, :parent, parent)
    new(name, opts)
  end

  @doc """
  Creates a navigation tag (kind: "navigation").

  Navigation tags are used for UI organization and grouping.

  ## Example

      Tag.navigation("Admin", summary: "Admin Panel")
  """
  @spec navigation(String.t(), keyword()) :: t()
  def navigation(name, opts \\ []) when is_binary(name) do
    opts = Keyword.put(opts, :kind, "navigation")
    new(name, opts)
  end

  # Private helper
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
