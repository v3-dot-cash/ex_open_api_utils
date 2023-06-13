defmodule PhoenixEctoOpenApiDemo.BusinessContextTest do
  use PhoenixEctoOpenApiDemo.DataCase

  alias PhoenixEctoOpenApiDemo.BusinessContext

  describe "businesses" do
    alias PhoenixEctoOpenApiDemo.BusinessContext.Business

    import PhoenixEctoOpenApiDemo.BusinessContextFixtures

    @invalid_attrs %{name: nil}

    test "list_businesses/0 returns all businesses" do
      business = business_fixture()
      assert BusinessContext.list_businesses() == [business]
    end

    test "get_business!/1 returns the business with given id" do
      business = business_fixture()
      assert BusinessContext.get_business!(business.id) == business
    end

    test "create_business/1 with valid data creates a business" do
      valid_attrs = %{name: "some name"}

      assert {:ok, %Business{} = business} = BusinessContext.create_business(valid_attrs)
      assert business.name == "some name"
    end

    test "create_business/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = BusinessContext.create_business(@invalid_attrs)
    end

    test "update_business/2 with valid data updates the business" do
      business = business_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Business{} = business} =
               BusinessContext.update_business(business, update_attrs)

      assert business.name == "some updated name"
    end

    test "update_business/2 with invalid data returns error changeset" do
      business = business_fixture()

      assert {:error, %Ecto.Changeset{}} =
               BusinessContext.update_business(business, @invalid_attrs)

      assert business == BusinessContext.get_business!(business.id)
    end

    test "delete_business/1 deletes the business" do
      business = business_fixture()
      assert {:ok, %Business{}} = BusinessContext.delete_business(business)
      assert_raise Ecto.NoResultsError, fn -> BusinessContext.get_business!(business.id) end
    end

    test "change_business/1 returns a business changeset" do
      business = business_fixture()
      assert %Ecto.Changeset{} = BusinessContext.change_business(business)
    end
  end
end
