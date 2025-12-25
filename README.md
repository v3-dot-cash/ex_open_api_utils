# ExOpenApiUtils

OpenAPI 3.2 schema generation from Ecto schemas for Elixir/Phoenix applications.

[![Module Version](https://img.shields.io/hexpm/v/ex_open_api_utils.svg)](https://hex.pm/packages/ex_open_api_utils)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ex_open_api_utils/)
[![Total Download](https://img.shields.io/hexpm/dt/ex_open_api_utils.svg)](https://hex.pm/packages/ex_open_api_utils)
[![License](https://img.shields.io/hexpm/l/ex_open_api_utils.svg)](https://github.com/v3-dot-cash/ex_open_api_utils/blob/main/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/v3-dot-cash/ex_open_api_utils.svg)](https://github.com/v3-dot-cash/ex_open_api_utils/commits/main)

## Features

- **OpenAPI 3.2 compliant** - Native support for tag hierarchy (`parent`, `kind`, `summary`)
- **Ecto schema integration** - Define OpenAPI schemas alongside your Ecto schemas
- **Auto-generated Request/Response schemas** - Separate schemas for input (writeOnly) and output (readOnly)
- **Property ordering** - `x-order` extension for consistent code generation
- **TypeScript codegen support** - `x-enum-varnames` for proper TypeScript enum generation

## Installation

Add `ex_open_api_utils` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_open_api_utils, "~> 0.10.0"}
  ]
end
```

## Quick Start

### 1. Define your schema

```elixir
defmodule MyApp.User do
  use ExOpenApiUtils

  open_api_property(
    key: :id,
    schema: %Schema{
      type: :string,
      format: :uuid,
      description: "User ID",
      readOnly: true
    }
  )

  open_api_property(
    key: :email,
    schema: %Schema{
      type: :string,
      format: :email,
      description: "User email address"
    }
  )

  open_api_property(
    key: :status,
    schema: Helpers.enum_schema(
      values: ["pending", "active", "suspended"],
      varnames: ["PENDING", "ACTIVE", "SUSPENDED"],
      description: "Account status"
    )
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :email, :string
    field :status, :string
    timestamps()
  end

  open_api_schema(
    title: "User",
    description: "Application user",
    required: [:email],
    properties: [:id, :email, :status],
    tags: ["Users"]
  )
end
```

This generates:
- `MyApp.OpenApiSchema.UserRequest` - For input (excludes `readOnly` fields)
- `MyApp.OpenApiSchema.UserResponse` - For output (excludes `writeOnly` fields)

### 2. Configure your API spec

```elixir
defmodule MyApp.ApiSpec do
  alias OpenApiSpex.{Info, OpenApi, Server}
  alias ExOpenApiUtils.Tag

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      openapi: ExOpenApiUtils.openapi_version(),  # "3.2.0"
      info: %Info{
        title: "My API",
        version: "1.0.0"
      },
      servers: [%Server{url: "https://api.example.com"}],
      tags: tags()
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  defp tags do
    [
      Tag.new("Users", summary: "User management"),
      Tag.nested("Profile", "Users", summary: "User profiles"),
      Tag.navigation("Admin", summary: "Administration")
    ]
    |> Tag.to_open_api_spex_list()
  end
end
```

## Best Practices

### Use standard OpenAPI fields for validation

Standard OpenAPI schema fields are supported by all code generators:

```elixir
open_api_property(
  key: :email,
  schema: %Schema{
    type: :string,
    format: :email,
    minLength: 5,
    maxLength: 255,
    pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
  }
)
```

### Use `readOnly` and `writeOnly` appropriately

```elixir
# Server-generated fields (not in request body)
open_api_property(
  key: :id,
  schema: %Schema{type: :string, format: :uuid, readOnly: true}
)

open_api_property(
  key: :created_at,
  schema: %Schema{type: :string, format: :"date-time", readOnly: true}
)

# Input-only fields (not in response)
open_api_property(
  key: :password,
  schema: %Schema{type: :string, minLength: 8, writeOnly: true}
)
```

### Use nullable for optional fields

Mark fields as nullable when they can accept null values:

```elixir
# Optional field (not in required list, can be omitted or null)
open_api_property(
  key: :middle_name,
  schema: %Schema{
    type: :string,
    nullable: true,
    description: "Optional middle name"
  }
)

# Required field that can be null (must be present, but can be null)
open_api_property(
  key: :nickname,
  schema: %Schema{
    type: :string,
    nullable: true,
    description: "Nickname (required field, but can be null)"
  }
)

# Nullable with readOnly (optional server-generated field)
open_api_property(
  key: :external_id,
  schema: %Schema{
    type: :string,
    format: :uuid,
    nullable: true,
    readOnly: true,
    description: "External system ID (may not be set yet)"
  }
)

# Nullable with writeOnly (optional input field)
open_api_property(
  key: :password,
  schema: %Schema{
    type: :string,
    minLength: 8,
    nullable: true,
    writeOnly: true,
    description: "Password (optional for updates)"
  }
)

```

**Schema-level nullable:**

Mark entire schemas as nullable in their definition:

```elixir
# In your UIParameters module:
defmodule MyApp.UIParameters do
  use ExOpenApiUtils

  open_api_property(
    key: :theme,
    schema: %Schema{type: :string, description: "UI theme"}
  )

  schema "ui_parameters" do
    field :theme, :string
  end

  open_api_schema(
    title: "UIParameters",
    description: "UI configuration parameters",
    properties: [:theme],
    nullable: true  # The entire schema can be null
  )
end

# Then reference it simply:
open_api_property(
  schema: MyApp.OpenApiSchema.UIParametersResponse,
  key: :ui_parameters
)
```

**Required vs Nullable:**
- `required: [:field]` - Field must be present in the payload
- `nullable: true` - Field can have a null value
- `required: [:field]` + `nullable: true` - Field must be present but can be null
- Not in required + `nullable: true` - Field can be omitted or explicitly set to null

### Use enum_schema for TypeScript enums

```elixir
open_api_property(
  key: :role,
  schema: Helpers.enum_schema(
    values: ["user", "admin", "moderator"],
    varnames: ["USER", "ADMIN", "MODERATOR"],
    description: "User role"
  )
)
```

Generated TypeScript:
```typescript
export enum UserRole {
  USER = "user",
  ADMIN = "admin",
  MODERATOR = "moderator"
}
```

### Use tag hierarchy for organized documentation

```elixir
Tag.new("Settings", summary: "Application settings")
Tag.nested("Profile", "Settings", summary: "Profile settings")
Tag.nested("Security", "Settings", summary: "Security settings")
Tag.navigation("Admin", summary: "Admin panel")
```

Generated OpenAPI:
```yaml
tags:
  - name: Settings
    summary: Application settings
  - name: Profile
    summary: Profile settings
    parent: Settings
  - name: Security
    summary: Security settings
    parent: Settings
  - name: Admin
    summary: Admin panel
    kind: navigation
```

## Migration Guide

### From v0.8.x/v0.9.x to v0.10.x

#### 1. Update OpenAPI version

```elixir
# Before
%OpenApi{openapi: "3.0.0", ...}

# After
%OpenApi{openapi: ExOpenApiUtils.openapi_version(), ...}  # Returns "3.2.0"
```

#### 2. Migrate to tag hierarchy (optional)

```elixir
# Before - flat tags
%OpenApi{
  tags: [
    %OpenApiSpex.Tag{name: "Users"},
    %OpenApiSpex.Tag{name: "Profile"}
  ]
}

# After - hierarchical tags
alias ExOpenApiUtils.Tag

%OpenApi{
  tags: [
    Tag.new("Users", summary: "User Management"),
    Tag.nested("Profile", "Users", summary: "User Profiles")
  ] |> Tag.to_open_api_spex_list()
}
```

#### 3. Replace Redoc extensions with OpenAPI 3.2 native fields

| Old (Redoc)       | New (OpenAPI 3.2)    |
|-------------------|----------------------|
| `x-tagGroups`     | `Tag.nested/3`       |
| `x-displayName`   | `summary` field      |

#### 4. Removed helpers

The following helpers were removed in v0.10.0 to focus on standard OpenAPI compliance:

- `with_constraints/2` - Use standard OpenAPI fields (`minLength`, `maxLength`, `pattern`, etc.)
- `with_transforms/2` - Handle transforms in your application layer
- `with_relation/2`, `belongs_to/2`, `has_many/2`, `has_one/2` - Use `$ref` for related schemas
- `with_pagination/2` - Define pagination schemas explicitly
- `with_db_hints/2` - Database hints are not part of OpenAPI spec
- `with_metadata/2`, `internal_schema/1`, `deprecated_schema/2` - Use standard `deprecated` field

### Extensions retained

These extensions are kept for TypeScript/NestJS code generation:

- `x-enum-varnames` - TypeScript enum member names (via `Helpers.enum_schema/1`)
- `x-order` - Property ordering in generated code (auto-generated)

## API Reference

### ExOpenApiUtils

- `openapi_version/0` - Returns `"3.2.0"`
- `tag/2` - Creates a tag (delegates to `Tag.new/2`)
- `nested_tag/3` - Creates a nested tag (delegates to `Tag.nested/3`)
- `navigation_tag/2` - Creates a navigation tag (delegates to `Tag.navigation/2`)

### ExOpenApiUtils.Tag

- `new(name, opts)` - Create a basic tag
- `nested(name, parent, opts)` - Create a tag nested under a parent
- `navigation(name, opts)` - Create a navigation tag
- `to_open_api_spex(tag)` - Convert to OpenApiSpex.Tag
- `to_open_api_spex_list(tags)` - Convert list of tags

### ExOpenApiUtils.Helpers

- `enum_schema(opts)` - Create enum schema with `x-enum-varnames`

## Documentation

Full documentation is available at [HexDocs](https://hexdocs.pm/ex_open_api_utils).

## License

MIT License - see [LICENSE.md](LICENSE.md)
