defmodule ExOpenApiUtils.Helpers do
  @moduledoc """
  Helper functions for creating OpenAPI schemas with extensions targeting:
  - TypeScript client SDK (openapi-generator)
  - NestJS server stubs (class-validator, class-transformer)
  - Drizzle ORM (schema hints, relations)
  """

  alias OpenApiSpex.Schema

  # ===========================================================================
  # Enum Extensions (TypeScript codegen)
  # ===========================================================================

  @doc """
  Creates an enum schema with x-enum-varnames and x-enum-descriptions extensions.

  These extensions are used by TypeScript code generators to create proper enum types.

  ## Options
    * `:values` - (required) List of enum values
    * `:varnames` - List of variable names for code generation (e.g., ["PENDING", "ACTIVE"])
    * `:descriptions` - List of descriptions for each enum value
    * `:description` - Overall description for the enum field
    * `:type` - Schema type, defaults to `:string`

  ## Example

      Helpers.enum_schema(
        values: ["pending", "active", "suspended"],
        varnames: ["PENDING", "ACTIVE", "SUSPENDED"],
        descriptions: ["Awaiting activation", "Active account", "Suspended account"],
        description: "Account status"
      )

  ## Generated TypeScript

      export enum Status {
        /** Awaiting activation */
        PENDING = "pending",
        /** Active account */
        ACTIVE = "active",
        /** Suspended account */
        SUSPENDED = "suspended"
      }
  """
  @spec enum_schema(keyword()) :: Schema.t()
  def enum_schema(opts) do
    values = Keyword.fetch!(opts, :values)
    varnames = Keyword.get(opts, :varnames)
    descriptions = Keyword.get(opts, :descriptions)

    extensions =
      %{}
      |> maybe_put("x-enum-varnames", varnames)
      |> maybe_put("x-enum-descriptions", descriptions)

    schema_opts =
      opts
      |> Keyword.drop([:values, :varnames, :descriptions])
      |> Keyword.put(:enum, values)
      |> Keyword.put_new(:type, :string)
      |> maybe_put_extensions(extensions)

    struct(Schema, schema_opts)
  end

  # ===========================================================================
  # Constraints (NestJS class-validator + Drizzle)
  # ===========================================================================

  @doc """
  Adds x-constraints extension to an existing schema.

  Constraints map to NestJS class-validator decorators and Drizzle schema modifiers.

  ## Supported Constraints

  | Constraint | NestJS Decorator | Drizzle |
  |------------|------------------|---------|
  | `unique` | - | `.unique()` |
  | `email` | `@IsEmail()` | - |
  | `url` | `@IsUrl()` | - |
  | `uuid` | `@IsUUID()` | - |
  | `min` / `max` | `@Min()` / `@Max()` | - |
  | `minLength` / `maxLength` | `@MinLength()` / `@MaxLength()` | `varchar({length})` |
  | `pattern` | `@Matches(regex)` | - |
  | `isArray` | `@IsArray()` | - |
  | `isOptional` | `@IsOptional()` | - |
  | `isNotEmpty` | `@IsNotEmpty()` | `.notNull()` |
  | `isInt` | `@IsInt()` | `integer()` |
  | `isJSON` | `@IsJSON()` | `jsonb()` |

  ## Example

      %Schema{type: :string, format: :email}
      |> Helpers.with_constraints(%{
        "unique" => true,
        "email" => true,
        "maxLength" => 255
      })
  """
  @spec with_constraints(Schema.t(), map()) :: Schema.t()
  def with_constraints(%Schema{} = schema, constraints) when is_map(constraints) do
    existing_extensions = schema.extensions || %{}
    existing_constraints = Map.get(existing_extensions, "x-constraints", %{})
    merged_constraints = Map.merge(existing_constraints, constraints)

    new_extensions = Map.put(existing_extensions, "x-constraints", merged_constraints)
    %{schema | extensions: new_extensions}
  end

  @doc """
  Creates a schema with constraints and optional transforms.

  ## Options
    * `:type` - Schema type (required)
    * `:format` - Schema format
    * `:description` - Field description
    * `:constraints` - Map of constraints
    * `:transforms` - List of transforms (see `with_transforms/2`)

  ## Example

      Helpers.constrained_schema(
        type: :string,
        format: :email,
        constraints: %{"unique" => true, "email" => true},
        transforms: ["trim", "toLowerCase"]
      )
  """
  @spec constrained_schema(keyword()) :: Schema.t()
  def constrained_schema(opts) do
    constraints = Keyword.get(opts, :constraints, %{})
    transforms = Keyword.get(opts, :transforms, [])

    schema_opts = Keyword.drop(opts, [:constraints, :transforms])
    schema = struct(Schema, schema_opts)

    schema
    |> with_constraints(constraints)
    |> with_transforms(transforms)
  end

  # ===========================================================================
  # Relations (Drizzle)
  # ===========================================================================

  @doc """
  Adds x-relation extension to a schema for Drizzle relation generation.

  ## Options
    * `:type` - Relation type: `:one` or `:many`
    * `:target` - Target table name
    * `:field` - Foreign key field name
    * `:references` - Referenced field (default: `:id`)
    * `:on_delete` - Delete behavior: `:cascade`, `:set_null`, `:restrict`
    * `:on_update` - Update behavior: `:cascade`, `:set_null`, `:restrict`

  ## Example

      %Schema{type: :string, format: :uuid}
      |> Helpers.with_relation(
        type: :one,
        target: "users",
        field: :user_id,
        references: :id,
        on_delete: :cascade
      )
  """
  @spec with_relation(Schema.t(), keyword()) :: Schema.t()
  def with_relation(%Schema{} = schema, opts) do
    relation = %{
      "type" => to_string(Keyword.fetch!(opts, :type)),
      "target" => Keyword.fetch!(opts, :target),
      "field" => to_string(Keyword.get(opts, :field)),
      "references" => to_string(Keyword.get(opts, :references, :id))
    }

    relation =
      relation
      |> maybe_put("onDelete", opts[:on_delete] && to_string(opts[:on_delete]))
      |> maybe_put("onUpdate", opts[:on_update] && to_string(opts[:on_update]))

    add_extension(schema, "x-relation", relation)
  end

  @doc """
  Creates a belongs_to (many-to-one) relation schema.

  ## Example

      Helpers.belongs_to("organizations",
        field: :organization_id,
        references: :id,
        on_delete: :cascade
      )
  """
  @spec belongs_to(String.t(), keyword()) :: Schema.t()
  def belongs_to(target, opts \\ []) do
    %Schema{type: :string, format: :uuid}
    |> with_relation(Keyword.merge([type: :one, target: target], opts))
  end

  @doc """
  Creates a has_many (one-to-many) relation schema.

  ## Example

      Helpers.has_many("posts", field: :author_id, references: :id)
  """
  @spec has_many(String.t(), keyword()) :: Schema.t()
  def has_many(target, opts \\ []) do
    %Schema{type: :array, items: %Schema{type: :object}}
    |> with_relation(Keyword.merge([type: :many, target: target], opts))
  end

  @doc """
  Creates a has_one (one-to-one) relation schema.

  ## Example

      Helpers.has_one("profile", field: :user_id, references: :id)
  """
  @spec has_one(String.t(), keyword()) :: Schema.t()
  def has_one(target, opts \\ []) do
    %Schema{type: :object}
    |> with_relation(Keyword.merge([type: :one, target: target], opts))
  end

  # ===========================================================================
  # Pagination (Flop → NestJS)
  # ===========================================================================

  @doc """
  Adds x-pagination extension to a schema.

  Used to generate NestJS pagination decorators and query params.

  ## Options
    * `:strategy` - Pagination strategy: `:offset`, `:cursor`, `:page`
    * `:default_limit` - Default page size
    * `:max_limit` - Maximum page size
    * `:sortable` - List of sortable field names
    * `:filterable` - List of filterable field names
    * `:default_sort` - Tuple of `{field, direction}` e.g., `{:created_at, :desc}`

  ## Example

      %Schema{type: :object}
      |> Helpers.with_pagination(
        strategy: :offset,
        default_limit: 20,
        max_limit: 100,
        sortable: [:created_at, :name],
        filterable: [:status, :type]
      )
  """
  @spec with_pagination(Schema.t(), keyword()) :: Schema.t()
  def with_pagination(%Schema{} = schema, opts) do
    pagination =
      %{}
      |> maybe_put("strategy", opts[:strategy] && to_string(opts[:strategy]))
      |> maybe_put("defaultLimit", opts[:default_limit])
      |> maybe_put("maxLimit", opts[:max_limit])
      |> maybe_put("sortable", opts[:sortable] && Enum.map(opts[:sortable], &to_string/1))
      |> maybe_put("filterable", opts[:filterable] && Enum.map(opts[:filterable], &to_string/1))
      |> maybe_put_default_sort(opts[:default_sort])

    add_extension(schema, "x-pagination", pagination)
  end

  @doc """
  Creates pagination extensions map for use in `open_api_schema`.

  ## Example

      open_api_schema(
        title: "Post",
        extensions: Helpers.pagination_extensions(
          strategy: :offset,
          default_limit: 20,
          sortable: [:created_at, :title]
        )
      )
  """
  @spec pagination_extensions(keyword()) :: map()
  def pagination_extensions(opts) do
    pagination =
      %{}
      |> maybe_put("strategy", opts[:strategy] && to_string(opts[:strategy]))
      |> maybe_put("defaultLimit", opts[:default_limit])
      |> maybe_put("maxLimit", opts[:max_limit])
      |> maybe_put("sortable", opts[:sortable] && Enum.map(opts[:sortable], &to_string/1))
      |> maybe_put("filterable", opts[:filterable] && Enum.map(opts[:filterable], &to_string/1))
      |> maybe_put_default_sort(opts[:default_sort])

    %{"x-pagination" => pagination}
  end

  # ===========================================================================
  # Transforms (NestJS class-transformer)
  # ===========================================================================

  @doc """
  Adds x-transforms extension to a schema.

  Transforms map to NestJS class-transformer decorators.

  ## Supported Transforms

  | Transform | NestJS Decorator |
  |-----------|------------------|
  | `trim` | `@Transform(({ value }) => value?.trim())` |
  | `toLowerCase` | `@Transform(({ value }) => value?.toLowerCase())` |
  | `toUpperCase` | `@Transform(({ value }) => value?.toUpperCase())` |
  | `toInt` | `@Transform(({ value }) => parseInt(value))` |
  | `toFloat` | `@Transform(({ value }) => parseFloat(value))` |
  | `toBoolean` | `@Transform(({ value }) => value === 'true')` |
  | `toDate` | `@Transform(({ value }) => new Date(value))` |
  | `toArray` | `@Transform(({ value }) => value?.split(','))` |

  ## Example

      %Schema{type: :string}
      |> Helpers.with_transforms(["trim", "toLowerCase"])
  """
  @spec with_transforms(Schema.t(), list(String.t())) :: Schema.t()
  def with_transforms(%Schema{} = schema, []), do: schema

  def with_transforms(%Schema{} = schema, transforms) when is_list(transforms) do
    add_extension(schema, "x-transforms", transforms)
  end

  # ===========================================================================
  # Binary Content (OAS 3.1)
  # ===========================================================================

  @doc """
  Creates a schema for binary content with encoding and media type.

  ## Options
    * `:encoding` - Content encoding: `:base64`, `:base64url`, or custom string
    * `:media_type` - MIME type (required)
    * `:description` - Field description
    * `:max_size` - Maximum file size in bytes

  ## Example

      Helpers.binary_content_schema(
        encoding: :base64,
        media_type: "image/png",
        description: "Profile picture"
      )
  """
  @spec binary_content_schema(keyword()) :: Schema.t()
  def binary_content_schema(opts) do
    encoding = Keyword.get(opts, :encoding, :base64)
    media_type = Keyword.fetch!(opts, :media_type)
    max_size = Keyword.get(opts, :max_size)

    encoding_str =
      case encoding do
        :base64 -> "base64"
        :base64url -> "base64url"
        str when is_binary(str) -> str
      end

    extensions =
      %{
        "x-contentEncoding" => encoding_str,
        "x-contentMediaType" => media_type
      }
      |> maybe_put("x-maxFileSize", max_size)

    schema_opts =
      opts
      |> Keyword.drop([:encoding, :media_type, :max_size])
      |> Keyword.put(:type, :string)
      |> Keyword.put(:extensions, extensions)

    struct(Schema, schema_opts)
  end

  @doc """
  Creates a file upload schema with allowed types and size constraints.

  ## Options
    * `:encoding` - Content encoding (default: `:base64`)
    * `:allowed_types` - List of allowed MIME types (required)
    * `:max_size` - Maximum file size in bytes
    * `:description` - Field description

  ## Example

      Helpers.file_upload_schema(
        allowed_types: ["image/png", "image/jpeg"],
        max_size: 5_242_880,
        description: "Profile picture (max 5MB)"
      )
  """
  @spec file_upload_schema(keyword()) :: Schema.t()
  def file_upload_schema(opts) do
    encoding = Keyword.get(opts, :encoding, :base64)
    allowed_types = Keyword.fetch!(opts, :allowed_types)
    max_size = Keyword.get(opts, :max_size)
    primary_type = List.first(allowed_types)

    encoding_str =
      case encoding do
        :base64 -> "base64"
        :base64url -> "base64url"
        str when is_binary(str) -> str
      end

    extensions =
      %{
        "x-contentEncoding" => encoding_str,
        "x-contentMediaType" => primary_type,
        "x-allowedMimeTypes" => allowed_types
      }
      |> maybe_put("x-maxFileSize", max_size)

    schema_opts =
      opts
      |> Keyword.drop([:encoding, :allowed_types, :max_size])
      |> Keyword.put(:type, :string)
      |> Keyword.put(:extensions, extensions)

    struct(Schema, schema_opts)
  end

  # ===========================================================================
  # Database Hints (Drizzle)
  # ===========================================================================

  @doc """
  Adds x-db extension with Drizzle schema hints.

  ## Supported Hints

  | Hint | Drizzle |
  |------|---------|
  | `type` | Override column type (`text`, `jsonb`, `uuid`) |
  | `default` | Default value |
  | `index` | Create index |
  | `primaryKey` | Mark as primary key |
  | `autoIncrement` | Serial/auto-increment |
  | `precision` | Decimal precision |
  | `scale` | Decimal scale |

  ## Example

      %Schema{type: :object}
      |> Helpers.with_db_hints(%{type: "jsonb", default: "{}"})
  """
  @spec with_db_hints(Schema.t(), map()) :: Schema.t()
  def with_db_hints(%Schema{} = schema, hints) when is_map(hints) do
    existing_extensions = schema.extensions || %{}
    existing_hints = Map.get(existing_extensions, "x-db", %{})

    # Convert atom keys to strings for consistency
    string_hints =
      hints
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Map.new()

    merged_hints = Map.merge(existing_hints, string_hints)

    new_extensions = Map.put(existing_extensions, "x-db", merged_hints)
    %{schema | extensions: new_extensions}
  end

  # ===========================================================================
  # Metadata (Documentation/UI hints)
  # ===========================================================================

  @doc """
  Adds metadata extensions to a schema.

  ## Supported Metadata

  | Key | Purpose |
  |-----|---------|
  | `internal` | Hide from public docs |
  | `deprecated_message` | Deprecation reason |
  | `deprecated_since` | Version deprecated |
  | `replacement` | Replacement field/endpoint |
  | `group` | Group for UI organization |
  | `sort_order` | Sort order in docs |

  ## Example

      %Schema{type: :string}
      |> Helpers.with_metadata(%{group: "auth", sort_order: 1})
  """
  @spec with_metadata(Schema.t(), map()) :: Schema.t()
  def with_metadata(%Schema{} = schema, metadata) when is_map(metadata) do
    existing_extensions = schema.extensions || %{}

    new_extensions =
      Enum.reduce(metadata, existing_extensions, fn {key, value}, acc ->
        ext_key = "x-#{to_kebab_case(to_string(key))}"
        Map.put(acc, ext_key, value)
      end)

    %{schema | extensions: new_extensions}
  end

  @doc """
  Marks a schema as internal (hidden from public docs).

  ## Example

      %Schema{type: :string}
      |> Helpers.internal_schema()
  """
  @spec internal_schema(Schema.t()) :: Schema.t()
  def internal_schema(%Schema{} = schema) do
    add_extension(schema, "x-internal", true)
  end

  @doc """
  Marks a schema as deprecated with optional details.

  ## Options
    * `:message` - Deprecation reason
    * `:since` - Version deprecated
    * `:replacement` - Replacement field/endpoint

  ## Example

      %Schema{type: :string}
      |> Helpers.deprecated_schema(
        message: "Use 'id' instead",
        since: "2.0.0",
        replacement: "id"
      )
  """
  @spec deprecated_schema(Schema.t(), keyword()) :: Schema.t()
  def deprecated_schema(%Schema{} = schema, opts \\ []) do
    schema = %{schema | deprecated: true}

    schema
    |> maybe_add_extension("x-deprecated-message", opts[:message])
    |> maybe_add_extension("x-deprecated-since", opts[:since])
    |> maybe_add_extension("x-replacement", opts[:replacement])
  end

  # ===========================================================================
  # Flop Meta Helpers
  # ===========================================================================

  @doc """
  Converts Flop.Meta struct to a map suitable for OpenAPI response.

  ## Example

      meta = %Flop.Meta{
        current_page: 1,
        page_size: 20,
        total_count: 100,
        total_pages: 5
      }

      Helpers.flop_meta_to_map(meta)
      # => %{
      #   "currentPage" => 1,
      #   "pageSize" => 20,
      #   "totalCount" => 100,
      #   "totalPages" => 5,
      #   "hasNextPage" => true,
      #   "hasPreviousPage" => false
      # }
  """
  @spec flop_meta_to_map(struct()) :: map()
  def flop_meta_to_map(meta) do
    %{
      "currentPage" => Map.get(meta, :current_page),
      "pageSize" => Map.get(meta, :page_size),
      "totalCount" => Map.get(meta, :total_count),
      "totalPages" => Map.get(meta, :total_pages),
      "hasNextPage" => Map.get(meta, :has_next_page?, false),
      "hasPreviousPage" => Map.get(meta, :has_previous_page?, false)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc """
  Creates an OpenAPI schema for pagination metadata (Flop.Meta).

  ## Example

      Helpers.pagination_meta_schema()
  """
  @spec pagination_meta_schema() :: Schema.t()
  def pagination_meta_schema do
    %Schema{
      type: :object,
      description: "Pagination metadata",
      properties: %{
        currentPage: %Schema{type: :integer, description: "Current page number"},
        pageSize: %Schema{type: :integer, description: "Number of items per page"},
        totalCount: %Schema{type: :integer, description: "Total number of items"},
        totalPages: %Schema{type: :integer, description: "Total number of pages"},
        hasNextPage: %Schema{type: :boolean, description: "Whether there is a next page"},
        hasPreviousPage: %Schema{type: :boolean, description: "Whether there is a previous page"}
      }
    }
  end

  # ===========================================================================
  # Private Helpers
  # ===========================================================================

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_extensions(opts, extensions) when map_size(extensions) == 0, do: opts

  defp maybe_put_extensions(opts, extensions) do
    existing = Keyword.get(opts, :extensions, %{})
    Keyword.put(opts, :extensions, Map.merge(existing, extensions))
  end

  defp maybe_put_default_sort(map, nil), do: map

  defp maybe_put_default_sort(map, {field, direction}) do
    Map.put(map, "defaultSort", %{
      "field" => to_string(field),
      "direction" => to_string(direction)
    })
  end

  defp add_extension(%Schema{} = schema, key, value) do
    existing_extensions = schema.extensions || %{}
    new_extensions = Map.put(existing_extensions, key, value)
    %{schema | extensions: new_extensions}
  end

  defp maybe_add_extension(schema, _key, nil), do: schema
  defp maybe_add_extension(schema, key, value), do: add_extension(schema, key, value)

  defp to_kebab_case(string) do
    string
    |> String.replace(~r/([a-z])([A-Z])/, "\\1-\\2")
    |> String.replace("_", "-")
    |> String.downcase()
  end
end
