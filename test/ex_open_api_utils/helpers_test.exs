defmodule ExOpenApiUtils.HelpersTest do
  use ExUnit.Case, async: true

  alias ExOpenApiUtils.Helpers

  describe "enum_schema/1" do
    test "creates schema with enum values" do
      schema = Helpers.enum_schema(values: ["a", "b", "c"])

      assert schema.enum == ["a", "b", "c"]
      assert schema.type == :string
    end

    test "adds x-enum-varnames extension" do
      schema =
        Helpers.enum_schema(
          values: ["pending", "active"],
          varnames: ["PENDING", "ACTIVE"]
        )

      assert schema.extensions["x-enum-varnames"] == ["PENDING", "ACTIVE"]
    end

    test "supports custom type" do
      schema = Helpers.enum_schema(values: [1, 2, 3], type: :integer)

      assert schema.type == :integer
      assert schema.enum == [1, 2, 3]
    end

    test "includes description" do
      schema = Helpers.enum_schema(values: ["a", "b"], description: "Status field")

      assert schema.description == "Status field"
    end

    test "returns nil extensions when no varnames provided" do
      schema = Helpers.enum_schema(values: ["a", "b"])

      assert schema.extensions == nil
    end
  end
end
