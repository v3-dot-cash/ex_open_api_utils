defmodule ExOpenApiUtilsTest do
  use ExUnit.Case
  doctest ExOpenApiUtils

  describe "x-order property generation" do
    test "Request schema should have x-order extension property" do
      schema = ExOpenApiUtilsTest.OpenApiSchema.TestSchemaRequest.schema()

      # Verify x-order exists in extensions
      assert Map.has_key?(schema.extensions, "x-order")

      # Verify x-order contains the expected property order
      assert is_list(schema.extensions["x-order"])

      # Verify it contains properties (excluding readOnly properties like :id)
      assert :name in schema.extensions["x-order"]
      assert :email in schema.extensions["x-order"]
      assert :tenant_id in schema.extensions["x-order"]
    end

    test "Response schema should have x-order extension property" do
      schema = ExOpenApiUtilsTest.OpenApiSchema.TestSchemaResponse.schema()

      # Verify x-order exists in extensions
      assert Map.has_key?(schema.extensions, "x-order")

      # Verify x-order contains the expected property order
      assert is_list(schema.extensions["x-order"])

      # Verify it contains all properties (including readOnly properties like :id)
      assert :id in schema.extensions["x-order"]
      assert :name in schema.extensions["x-order"]
      assert :email in schema.extensions["x-order"]
      assert :tenant_id in schema.extensions["x-order"]
    end

    test "Request schema should NOT have non-prefixed 'order' property" do
      schema = ExOpenApiUtilsTest.OpenApiSchema.TestSchemaRequest.schema()

      # Verify that the schema struct does not have an :order field
      refute Map.has_key?(schema, :order)

      # Verify that extensions does not have "order" key (without x- prefix)
      refute Map.has_key?(schema.extensions, "order")
    end

    test "Response schema should NOT have non-prefixed 'order' property" do
      schema = ExOpenApiUtilsTest.OpenApiSchema.TestSchemaResponse.schema()

      # Verify that the schema struct does not have an :order field
      refute Map.has_key?(schema, :order)

      # Verify that extensions does not have "order" key (without x- prefix)
      refute Map.has_key?(schema.extensions, "order")
    end

    test "x-order preserves property ordering from schema definition" do
      schema = ExOpenApiUtilsTest.OpenApiSchema.TestSchemaResponse.schema()

      # The order should match the order defined in open_api_schema properties
      expected_order = [:id, :name, :email, :tenant_id]
      assert schema.extensions["x-order"] == expected_order
    end
  end
end
