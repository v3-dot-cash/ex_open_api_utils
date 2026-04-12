defmodule ExOpenApiUtils.NilStrippingMapperTest do
  @moduledoc """
  GH-38 regression lock: `Mapper.to_map/1` must omit nil values for
  non-nullable properties but emit nil for nullable properties.

  Fixture `NilStrippingSchema` covers the full required × nullable matrix:

      ┌─────────────┬───────────────────────────┬───────────────────────────┐
      │             │ nullable: false (default)  │ nullable: true            │
      ├─────────────┼───────────────────────────┼───────────────────────────┤
      │ required    │ :name, :id                │ :nickname                 │
      ├─────────────┼───────────────────────────┼───────────────────────────┤
      │ optional    │ :region, :base_path,      │ :notes, :description      │
      │             │ :tags, :active            │                           │
      └─────────────┴───────────────────────────┴───────────────────────────┘
  """
  use ExUnit.Case, async: true

  alias ExOpenApiUtils.Mapper
  alias ExOpenApiUtilsTest.NilStrippingSchema

  # ------------------------------------------------------------------
  # :from_ecto direction (outbound — struct → wire JSON map)
  # ------------------------------------------------------------------

  describe ":from_ecto — optional non-nullable nil fields are omitted" do
    test "nil region and base_path are absent from output" do
      struct = %NilStrippingSchema{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        name: "Test",
        nickname: "testy",
        region: nil,
        base_path: nil
      }

      result = Mapper.to_map(struct)

      assert result["name"] == "Test"
      assert result["id"] == "851b18d7-0c88-4095-9969-cbe385926420"
      refute Map.has_key?(result, "region")
      refute Map.has_key?(result, "base_path")
    end

    test "nil tags and active (non-nullable) are absent" do
      struct = %NilStrippingSchema{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        name: "Test",
        nickname: "testy",
        tags: nil,
        active: nil
      }

      result = Mapper.to_map(struct)

      refute Map.has_key?(result, "tags")
      refute Map.has_key?(result, "active")
    end
  end

  describe ":from_ecto — optional nullable nil fields ARE emitted" do
    test "nil notes and description are present with nil value" do
      struct = %NilStrippingSchema{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        name: "Test",
        nickname: "testy",
        notes: nil,
        description: nil
      }

      result = Mapper.to_map(struct)

      assert Map.has_key?(result, "notes")
      assert is_nil(result["notes"])
      assert Map.has_key?(result, "description")
      assert is_nil(result["description"])
    end
  end

  describe ":from_ecto — required nullable nil field IS emitted" do
    test "nil nickname is present with nil value" do
      struct = %NilStrippingSchema{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        name: "Test",
        nickname: nil
      }

      result = Mapper.to_map(struct)

      assert Map.has_key?(result, "nickname")
      assert is_nil(result["nickname"])
    end
  end

  describe ":from_ecto — non-nil values always emitted regardless of nullable" do
    test "all fields populated → all keys present" do
      struct = %NilStrippingSchema{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        name: "Test",
        nickname: "testy",
        region: "us-west-2",
        base_path: "/data",
        notes: "some notes",
        description: "a description",
        tags: ["prod"],
        active: true
      }

      result = Mapper.to_map(struct)

      assert result["name"] == "Test"
      assert result["nickname"] == "testy"
      assert result["region"] == "us-west-2"
      assert result["base_path"] == "/data"
      assert result["notes"] == "some notes"
      assert result["description"] == "a description"
      assert result["tags"] == ["prod"]
      assert result["active"] == true
    end
  end

  describe ":from_ecto — falsy non-nil values are NOT stripped" do
    test "empty string, empty list, and false are all emitted" do
      struct = %NilStrippingSchema{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        name: "Test",
        nickname: "",
        region: "",
        base_path: "",
        tags: [],
        active: false
      }

      result = Mapper.to_map(struct)

      assert result["nickname"] == ""
      assert result["region"] == ""
      assert result["base_path"] == ""
      assert result["tags"] == []
      assert result["active"] == false
    end
  end

  # ------------------------------------------------------------------
  # :from_open_api direction (inbound — request struct → changeset attrs)
  # ------------------------------------------------------------------

  describe ":from_open_api — optional non-nullable nil fields are omitted" do
    test "nil region and base_path are absent from changeset attrs" do
      request =
        struct!(request_module(), %{
          name: "Test",
          nickname: "testy",
          region: nil,
          base_path: nil
        })

      result = Mapper.to_map(request)

      assert result[:name] == "Test"
      refute Map.has_key?(result, :region)
      refute Map.has_key?(result, :base_path)
    end
  end

  describe ":from_open_api — optional nullable nil fields ARE emitted" do
    test "nil notes and description are present with nil value" do
      request =
        struct!(request_module(), %{
          name: "Test",
          nickname: "testy",
          notes: nil,
          description: nil
        })

      result = Mapper.to_map(request)

      assert Map.has_key?(result, :notes)
      assert is_nil(result[:notes])
      assert Map.has_key?(result, :description)
      assert is_nil(result[:description])
    end
  end

  describe ":from_open_api — required nullable nil field IS emitted" do
    test "nil nickname is present with nil value for changeset" do
      request =
        struct!(request_module(), %{
          name: "Test",
          nickname: nil
        })

      result = Mapper.to_map(request)

      assert Map.has_key?(result, :nickname)
      assert is_nil(result[:nickname])
    end
  end

  describe ":from_open_api — non-nil values always emitted" do
    test "all fields populated → all keys present" do
      request =
        struct!(request_module(), %{
          name: "Test",
          nickname: "testy",
          region: "us-west-2",
          base_path: "/data",
          notes: "some notes",
          description: "a description",
          tags: ["prod"],
          active: true
        })

      result = Mapper.to_map(request)

      assert result[:name] == "Test"
      assert result[:nickname] == "testy"
      assert result[:region] == "us-west-2"
      assert result[:base_path] == "/data"
      assert result[:notes] == "some notes"
      assert result[:description] == "a description"
      assert result[:tags] == ["prod"]
      assert result[:active] == true
    end
  end

  describe ":from_open_api — falsy non-nil values are NOT stripped" do
    test "empty string, empty list, and false are all emitted" do
      request =
        struct!(request_module(), %{
          name: "Test",
          nickname: "",
          region: "",
          base_path: "",
          tags: [],
          active: false
        })

      result = Mapper.to_map(request)

      assert result[:nickname] == ""
      assert result[:region] == ""
      assert result[:base_path] == ""
      assert result[:tags] == []
      assert result[:active] == false
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp request_module do
    ExOpenApiUtilsTest.OpenApiSchema.NilStrippingSchemaRequest
  end
end
