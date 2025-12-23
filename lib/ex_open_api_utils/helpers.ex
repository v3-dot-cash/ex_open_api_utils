defmodule ExOpenApiUtils.Helpers do
  @moduledoc """
  Helper functions for creating OpenAPI schemas.

  Provides minimal helpers for TypeScript client SDK code generation.
  """

  alias OpenApiSpex.Schema

  @doc """
  Creates an enum schema with x-enum-varnames extension for TypeScript codegen.

  ## Options
    * `:values` - (required) List of enum values
    * `:varnames` - List of variable names for code generation (e.g., ["PENDING", "ACTIVE"])
    * `:description` - Overall description for the enum field
    * `:type` - Schema type, defaults to `:string`

  ## Example

      Helpers.enum_schema(
        values: ["pending", "active", "suspended"],
        varnames: ["PENDING", "ACTIVE", "SUSPENDED"],
        description: "Account status"
      )

  ## Generated TypeScript

      export enum Status {
        PENDING = "pending",
        ACTIVE = "active",
        SUSPENDED = "suspended"
      }
  """
  @spec enum_schema(keyword()) :: Schema.t()
  def enum_schema(opts) do
    values = Keyword.fetch!(opts, :values)
    varnames = Keyword.get(opts, :varnames)

    extensions =
      if varnames do
        %{"x-enum-varnames" => varnames}
      else
        nil
      end

    schema_opts =
      opts
      |> Keyword.drop([:values, :varnames])
      |> Keyword.put(:enum, values)
      |> Keyword.put_new(:type, :string)
      |> maybe_put_extensions(extensions)

    struct(Schema, schema_opts)
  end

  defp maybe_put_extensions(opts, nil), do: opts

  defp maybe_put_extensions(opts, extensions) do
    existing = Keyword.get(opts, :extensions, %{})
    Keyword.put(opts, :extensions, Map.merge(existing, extensions))
  end
end
