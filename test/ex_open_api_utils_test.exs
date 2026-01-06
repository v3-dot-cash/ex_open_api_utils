defmodule ExOpenApiUtilsTest do
  use ExUnit.Case
  doctest ExOpenApiUtils

  alias OpenApiSpex.Reference

  describe "is_readOnly?/1 with Reference" do
    test "returns true for Reference ending with Response" do
      ref = %Reference{"$ref": "#/components/schemas/UserResponse"}
      assert ExOpenApiUtils.is_readOnly?(ref) == true
    end

    test "returns false for Reference ending with Request" do
      ref = %Reference{"$ref": "#/components/schemas/UserRequest"}
      assert ExOpenApiUtils.is_readOnly?(ref) == false
    end

    test "returns false for Reference with other suffix" do
      ref = %Reference{"$ref": "#/components/schemas/User"}
      assert ExOpenApiUtils.is_readOnly?(ref) == false
    end
  end

  describe "is_writeOnly?/1 with Reference" do
    test "returns true for Reference ending with Request" do
      ref = %Reference{"$ref": "#/components/schemas/UserRequest"}
      assert ExOpenApiUtils.is_writeOnly?(ref) == true
    end

    test "returns false for Reference ending with Response" do
      ref = %Reference{"$ref": "#/components/schemas/UserResponse"}
      assert ExOpenApiUtils.is_writeOnly?(ref) == false
    end

    test "returns false for Reference with other suffix" do
      ref = %Reference{"$ref": "#/components/schemas/User"}
      assert ExOpenApiUtils.is_writeOnly?(ref) == false
    end
  end

  describe "schema type field" do
    test "Request schema always has type: :object" do
      schema = ExOpenApiUtilsTest.OpenApiSchema.TestSchemaRequest.schema()
      assert schema.type == :object
    end

    test "Response schema always has type: :object" do
      schema = ExOpenApiUtilsTest.OpenApiSchema.TestSchemaResponse.schema()
      assert schema.type == :object
    end

    test "Nullable Response schema has both type: :object and nullable: true" do
      schema = ExOpenApiUtilsTest.OpenApiSchema.NullableSchemaResponse.schema()
      assert schema.type == :object
      assert schema.nullable == true
    end

    test "Nullable Request schema has both type: :object and nullable: true" do
      schema = ExOpenApiUtilsTest.OpenApiSchema.NullableSchemaRequest.schema()
      assert schema.type == :object
      assert schema.nullable == true
    end

    test "Nullable schema serializes with type field in JSON" do
      schema = ExOpenApiUtilsTest.OpenApiSchema.NullableSchemaResponse.schema()
      # Use OpenApiSpex JSON encoder
      json_map = OpenApiSpex.OpenApi.to_map(schema)

      assert json_map["type"] == "object"
      assert json_map["nullable"] == true
    end

    test "Nullable schema serializes with type field in YAML" do
      schema = ExOpenApiUtilsTest.OpenApiSchema.NullableSchemaResponse.schema()
      json_map = OpenApiSpex.OpenApi.to_map(schema)
      {:ok, yaml} = Ymlr.document(json_map)

      assert yaml =~ "type: object"
      assert yaml =~ "nullable: true"
    end
  end

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
