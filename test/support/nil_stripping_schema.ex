defmodule ExOpenApiUtilsTest.NilStrippingSchema do
  @moduledoc """
  GH-38 fixture: exercises the full required × nullable matrix.

  ┌─────────────────┬──────────────────────────────────┬──────────────────────────────────┐
  │                 │  nullable: false (default)        │  nullable: true                  │
  ├─────────────────┼──────────────────────────────────┼──────────────────────────────────┤
  │  required       │  :name, :id                      │  :nickname                       │
  │                 │  always present, never nil        │  must be present, can be null    │
  ├─────────────────┼──────────────────────────────────┼──────────────────────────────────┤
  │  optional       │  :region, :base_path             │  :notes, :description            │
  │  (not required) │  nil → omit key                  │  nil → emit key with null        │
  └─────────────────┴──────────────────────────────────┴──────────────────────────────────┘

  Additional edge-case fields (optional, non-nullable):
    :tags    — {:array, :string} — empty list is NOT nil, must emit
    :active  — :boolean — false is NOT nil, must emit
  """
  use ExOpenApiUtils

  # ── required, non-nullable ──────────────────────────────────────────

  open_api_property(
    key: :id,
    schema: %Schema{
      type: :string,
      format: :uuid,
      readOnly: true,
      example: "851b18d7-0c88-4095-9969-cbe385926420"
    }
  )

  open_api_property(
    key: :name,
    schema: %Schema{type: :string, example: "My Resource"}
  )

  # ── required, nullable ─────────────────────────────────────────────

  open_api_property(
    key: :nickname,
    schema: %Schema{type: :string, nullable: true, description: "Required but can be null"}
  )

  # ── optional, non-nullable ─────────────────────────────────────────

  open_api_property(
    key: :region,
    schema: %Schema{type: :string, example: "us-west-2"}
  )

  open_api_property(
    key: :base_path,
    schema: %Schema{type: :string, example: "/data"}
  )

  open_api_property(
    key: :tags,
    schema: %Schema{
      type: :array,
      items: %Schema{type: :string},
      example: ["prod", "critical"]
    }
  )

  open_api_property(
    key: :active,
    schema: %Schema{type: :boolean, example: true}
  )

  # ── optional, nullable ─────────────────────────────────────────────

  open_api_property(
    key: :notes,
    schema: %Schema{type: :string, nullable: true, description: "Free-text notes (nullable)"}
  )

  open_api_property(
    key: :description,
    schema: %Schema{
      type: :string,
      nullable: true,
      description: "Optional description (nullable)"
    }
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "nil_stripping_schemas" do
    field(:name, :string)
    field(:nickname, :string)
    field(:region, :string)
    field(:base_path, :string, default: "")
    field(:notes, :string)
    field(:description, :string)
    field(:tags, {:array, :string}, default: [])
    field(:active, :boolean, default: true)
    timestamps()
  end

  open_api_schema(
    required: [:name, :nickname],
    title: "NilStrippingSchema",
    description: "GH-38 fixture for nil-stripping mapper tests",
    properties: [:id, :name, :nickname, :region, :base_path, :tags, :active, :notes, :description]
  )

  def changeset(schema, attrs) do
    schema
    |> Ecto.Changeset.cast(attrs, [
      :name,
      :nickname,
      :region,
      :base_path,
      :notes,
      :description,
      :tags,
      :active
    ])
    |> Ecto.Changeset.validate_required([:name])
  end
end
