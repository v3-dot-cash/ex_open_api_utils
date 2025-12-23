defmodule ExOpenApiUtils.TagTest do
  use ExUnit.Case, async: true

  alias ExOpenApiUtils.Tag

  describe "new/2" do
    test "creates a basic tag" do
      tag = Tag.new("Users")

      assert tag.name == "Users"
      assert tag.description == nil
      assert tag.parent == nil
      assert tag.kind == nil
      assert tag.summary == nil
    end

    test "creates tag with all options" do
      tag =
        Tag.new("Users",
          description: "User management endpoints",
          parent: "Admin",
          kind: "navigation",
          summary: "Users",
          external_docs: %{url: "https://example.com/docs"}
        )

      assert tag.name == "Users"
      assert tag.description == "User management endpoints"
      assert tag.parent == "Admin"
      assert tag.kind == "navigation"
      assert tag.summary == "Users"
      assert tag.external_docs == %{url: "https://example.com/docs"}
    end
  end

  describe "nested/3" do
    test "creates a nested tag with parent" do
      tag = Tag.nested("Profile", "Users")

      assert tag.name == "Profile"
      assert tag.parent == "Users"
    end

    test "creates nested tag with options" do
      tag =
        Tag.nested("Profile", "Users", summary: "User Profile", description: "Profile settings")

      assert tag.name == "Profile"
      assert tag.parent == "Users"
      assert tag.summary == "User Profile"
      assert tag.description == "Profile settings"
    end
  end

  describe "navigation/2" do
    test "creates a navigation tag" do
      tag = Tag.navigation("Admin")

      assert tag.name == "Admin"
      assert tag.kind == "navigation"
    end

    test "creates navigation tag with options" do
      tag = Tag.navigation("Admin", summary: "Admin Panel", description: "Administration")

      assert tag.name == "Admin"
      assert tag.kind == "navigation"
      assert tag.summary == "Admin Panel"
      assert tag.description == "Administration"
    end
  end

  describe "to_open_api_spex/1" do
    test "converts basic tag" do
      tag = Tag.new("Users", description: "User endpoints")
      spex_tag = Tag.to_open_api_spex(tag)

      assert spex_tag.name == "Users"
      assert spex_tag.description == "User endpoints"
      assert spex_tag.extensions == nil
    end

    test "converts tag with 3.2 fields to extensions" do
      tag = Tag.new("Profile", parent: "Users", summary: "Profile Settings", kind: "navigation")
      spex_tag = Tag.to_open_api_spex(tag)

      assert spex_tag.name == "Profile"
      assert spex_tag.extensions["parent"] == "Users"
      assert spex_tag.extensions["summary"] == "Profile Settings"
      assert spex_tag.extensions["kind"] == "navigation"
    end

    test "converts tag with external docs" do
      tag =
        Tag.new("Users", external_docs: %{url: "https://example.com", description: "More info"})

      spex_tag = Tag.to_open_api_spex(tag)

      assert spex_tag.externalDocs.url == "https://example.com"
      assert spex_tag.externalDocs.description == "More info"
    end
  end

  describe "to_open_api_spex_list/1" do
    test "converts list of tags" do
      tags = [
        Tag.new("Users", summary: "User Management"),
        Tag.nested("Profile", "Users", summary: "Profiles"),
        Tag.navigation("Admin", summary: "Admin")
      ]

      spex_tags = Tag.to_open_api_spex_list(tags)

      assert length(spex_tags) == 3
      assert Enum.at(spex_tags, 0).name == "Users"
      assert Enum.at(spex_tags, 1).extensions["parent"] == "Users"
      assert Enum.at(spex_tags, 2).extensions["kind"] == "navigation"
    end
  end
end
