defmodule ExOpenApiUtils.HelpersTest do
  use ExUnit.Case, async: true

  alias ExOpenApiUtils.Helpers
  alias OpenApiSpex.Schema

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

    test "adds x-enum-descriptions extension" do
      schema =
        Helpers.enum_schema(
          values: ["a", "b"],
          descriptions: ["Description A", "Description B"]
        )

      assert schema.extensions["x-enum-descriptions"] == ["Description A", "Description B"]
    end

    test "supports custom type" do
      schema = Helpers.enum_schema(values: [1, 2, 3], type: :integer)

      assert schema.type == :integer
      assert schema.enum == [1, 2, 3]
    end
  end

  describe "with_constraints/2" do
    test "adds x-constraints to schema" do
      schema = %Schema{type: :string}
      result = Helpers.with_constraints(schema, %{"unique" => true})

      assert result.extensions["x-constraints"]["unique"] == true
    end

    test "merges with existing constraints" do
      schema = %Schema{
        type: :string,
        extensions: %{"x-constraints" => %{"existing" => true}}
      }

      result = Helpers.with_constraints(schema, %{"new" => true})

      assert result.extensions["x-constraints"]["existing"] == true
      assert result.extensions["x-constraints"]["new"] == true
    end
  end

  describe "constrained_schema/1" do
    test "creates schema with constraints" do
      schema =
        Helpers.constrained_schema(
          type: :string,
          format: :email,
          constraints: %{"unique" => true, "email" => true}
        )

      assert schema.type == :string
      assert schema.format == :email
      assert schema.extensions["x-constraints"]["unique"] == true
      assert schema.extensions["x-constraints"]["email"] == true
    end

    test "creates schema with transforms" do
      schema =
        Helpers.constrained_schema(
          type: :string,
          transforms: ["trim", "toLowerCase"]
        )

      assert schema.extensions["x-transforms"] == ["trim", "toLowerCase"]
    end
  end

  describe "with_relation/2" do
    test "adds x-relation extension" do
      schema = %Schema{type: :string, format: :uuid}

      result =
        Helpers.with_relation(schema,
          type: :one,
          target: "users",
          field: :user_id,
          references: :id
        )

      assert result.extensions["x-relation"]["type"] == "one"
      assert result.extensions["x-relation"]["target"] == "users"
      assert result.extensions["x-relation"]["field"] == "user_id"
      assert result.extensions["x-relation"]["references"] == "id"
    end

    test "includes on_delete and on_update" do
      schema = %Schema{type: :string}

      result =
        Helpers.with_relation(schema,
          type: :one,
          target: "users",
          on_delete: :cascade,
          on_update: :restrict
        )

      assert result.extensions["x-relation"]["onDelete"] == "cascade"
      assert result.extensions["x-relation"]["onUpdate"] == "restrict"
    end
  end

  describe "belongs_to/2" do
    test "creates belongs_to relation schema" do
      schema = Helpers.belongs_to("organizations", field: :org_id, on_delete: :cascade)

      assert schema.type == :string
      assert schema.format == :uuid
      assert schema.extensions["x-relation"]["type"] == "one"
      assert schema.extensions["x-relation"]["target"] == "organizations"
      assert schema.extensions["x-relation"]["onDelete"] == "cascade"
    end
  end

  describe "has_many/2" do
    test "creates has_many relation schema" do
      schema = Helpers.has_many("posts", field: :author_id)

      assert schema.type == :array
      assert schema.extensions["x-relation"]["type"] == "many"
      assert schema.extensions["x-relation"]["target"] == "posts"
    end
  end

  describe "has_one/2" do
    test "creates has_one relation schema" do
      schema = Helpers.has_one("profile", field: :user_id)

      assert schema.type == :object
      assert schema.extensions["x-relation"]["type"] == "one"
      assert schema.extensions["x-relation"]["target"] == "profile"
    end
  end

  describe "with_pagination/2" do
    test "adds x-pagination extension" do
      schema = %Schema{type: :object}

      result =
        Helpers.with_pagination(schema,
          strategy: :offset,
          default_limit: 20,
          max_limit: 100
        )

      assert result.extensions["x-pagination"]["strategy"] == "offset"
      assert result.extensions["x-pagination"]["defaultLimit"] == 20
      assert result.extensions["x-pagination"]["maxLimit"] == 100
    end

    test "includes sortable and filterable fields" do
      schema = %Schema{type: :object}

      result =
        Helpers.with_pagination(schema,
          sortable: [:created_at, :name],
          filterable: [:status]
        )

      assert result.extensions["x-pagination"]["sortable"] == ["created_at", "name"]
      assert result.extensions["x-pagination"]["filterable"] == ["status"]
    end

    test "includes default sort" do
      schema = %Schema{type: :object}

      result = Helpers.with_pagination(schema, default_sort: {:created_at, :desc})

      assert result.extensions["x-pagination"]["defaultSort"] == %{
               "field" => "created_at",
               "direction" => "desc"
             }
    end
  end

  describe "pagination_extensions/1" do
    test "returns extensions map for open_api_schema" do
      extensions =
        Helpers.pagination_extensions(
          strategy: :offset,
          default_limit: 20,
          sortable: [:created_at]
        )

      assert extensions["x-pagination"]["strategy"] == "offset"
      assert extensions["x-pagination"]["defaultLimit"] == 20
      assert extensions["x-pagination"]["sortable"] == ["created_at"]
    end
  end

  describe "with_transforms/2" do
    test "adds x-transforms extension" do
      schema = %Schema{type: :string}
      result = Helpers.with_transforms(schema, ["trim", "toLowerCase"])

      assert result.extensions["x-transforms"] == ["trim", "toLowerCase"]
    end

    test "returns schema unchanged for empty list" do
      schema = %Schema{type: :string}
      result = Helpers.with_transforms(schema, [])

      assert result == schema
    end
  end

  describe "binary_content_schema/1" do
    test "creates schema with content encoding and media type" do
      schema =
        Helpers.binary_content_schema(
          encoding: :base64,
          media_type: "image/png"
        )

      assert schema.type == :string
      assert schema.extensions["x-contentEncoding"] == "base64"
      assert schema.extensions["x-contentMediaType"] == "image/png"
    end

    test "includes max size when provided" do
      schema =
        Helpers.binary_content_schema(
          media_type: "image/png",
          max_size: 5_242_880
        )

      assert schema.extensions["x-maxFileSize"] == 5_242_880
    end
  end

  describe "file_upload_schema/1" do
    test "creates file upload schema with allowed types" do
      schema =
        Helpers.file_upload_schema(
          allowed_types: ["image/png", "image/jpeg"],
          max_size: 5_242_880
        )

      assert schema.type == :string
      assert schema.extensions["x-contentEncoding"] == "base64"
      assert schema.extensions["x-contentMediaType"] == "image/png"
      assert schema.extensions["x-allowedMimeTypes"] == ["image/png", "image/jpeg"]
      assert schema.extensions["x-maxFileSize"] == 5_242_880
    end
  end

  describe "with_db_hints/2" do
    test "adds x-db extension" do
      schema = %Schema{type: :object}
      result = Helpers.with_db_hints(schema, %{type: "jsonb", default: "{}"})

      assert result.extensions["x-db"]["type"] == "jsonb"
      assert result.extensions["x-db"]["default"] == "{}"
    end

    test "merges with existing hints" do
      schema = %Schema{
        type: :object,
        extensions: %{"x-db" => %{"index" => true}}
      }

      result = Helpers.with_db_hints(schema, %{type: "jsonb"})

      assert result.extensions["x-db"]["index"] == true
      assert result.extensions["x-db"]["type"] == "jsonb"
    end
  end

  describe "with_metadata/2" do
    test "adds metadata extensions with x- prefix" do
      schema = %Schema{type: :string}
      result = Helpers.with_metadata(schema, %{group: "auth", sort_order: 1})

      assert result.extensions["x-group"] == "auth"
      assert result.extensions["x-sort-order"] == 1
    end
  end

  describe "internal_schema/1" do
    test "marks schema as internal" do
      schema = %Schema{type: :string}
      result = Helpers.internal_schema(schema)

      assert result.extensions["x-internal"] == true
    end
  end

  describe "deprecated_schema/2" do
    test "marks schema as deprecated" do
      schema = %Schema{type: :string}
      result = Helpers.deprecated_schema(schema)

      assert result.deprecated == true
    end

    test "includes deprecation details" do
      schema = %Schema{type: :string}

      result =
        Helpers.deprecated_schema(schema,
          message: "Use 'id' instead",
          since: "2.0.0",
          replacement: "id"
        )

      assert result.deprecated == true
      assert result.extensions["x-deprecated-message"] == "Use 'id' instead"
      assert result.extensions["x-deprecated-since"] == "2.0.0"
      assert result.extensions["x-replacement"] == "id"
    end
  end

  describe "flop_meta_to_map/1" do
    test "converts meta struct to map" do
      meta = %{
        current_page: 1,
        page_size: 20,
        total_count: 100,
        total_pages: 5,
        has_next_page?: true,
        has_previous_page?: false
      }

      result = Helpers.flop_meta_to_map(meta)

      assert result["currentPage"] == 1
      assert result["pageSize"] == 20
      assert result["totalCount"] == 100
      assert result["totalPages"] == 5
      assert result["hasNextPage"] == true
      assert result["hasPreviousPage"] == false
    end

    test "excludes nil values" do
      meta = %{current_page: 1, page_size: nil, total_count: 100}

      result = Helpers.flop_meta_to_map(meta)

      assert result["currentPage"] == 1
      assert result["totalCount"] == 100
      refute Map.has_key?(result, "pageSize")
    end
  end

  describe "pagination_meta_schema/0" do
    test "returns pagination meta schema" do
      schema = Helpers.pagination_meta_schema()

      assert schema.type == :object
      assert Map.has_key?(schema.properties, :currentPage)
      assert Map.has_key?(schema.properties, :pageSize)
      assert Map.has_key?(schema.properties, :totalCount)
      assert Map.has_key?(schema.properties, :totalPages)
      assert Map.has_key?(schema.properties, :hasNextPage)
      assert Map.has_key?(schema.properties, :hasPreviousPage)
    end
  end
end
