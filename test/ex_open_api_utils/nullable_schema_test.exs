defmodule ExOpenApiUtils.NullableSchemaTest do
  use ExUnit.Case
  alias ExOpenApiUtilsTest.OpenApiSchema.NullableSchemaRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.NullableSchemaResponse

  describe "nullable schema support" do
    test "Request schema has nullable: true" do
      schema = NullableSchemaRequest.schema()
      assert schema.nullable == true
    end

    test "Response schema has nullable: true" do
      schema = NullableSchemaResponse.schema()
      assert schema.nullable == true
    end

    test "Request schema maintains other properties" do
      schema = NullableSchemaRequest.schema()
      assert schema.title == "NullableSchemaRequest"
      assert schema.type == :object
      assert schema.required == [:name]
      assert Map.has_key?(schema.properties, :name)
    end

    test "Response schema maintains other properties" do
      schema = NullableSchemaResponse.schema()
      assert schema.title == "NullableSchemaResponse"
      assert schema.type == :object
      assert schema.required == [:name]
      assert Map.has_key?(schema.properties, :name)
    end
  end

  describe "schema without nullable option" do
    test "existing schemas work without nullable (backward compatibility)" do
      # Use existing TestSchema which doesn't have nullable
      schema = ExOpenApiUtilsTest.OpenApiSchema.TestSchemaRequest.schema()
      assert is_nil(schema.nullable) or schema.nullable == false
    end
  end
end
