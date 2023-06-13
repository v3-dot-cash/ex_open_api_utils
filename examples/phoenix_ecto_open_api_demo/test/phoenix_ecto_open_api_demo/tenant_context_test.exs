defmodule PhoenixEctoOpenApiDemo.TenantContextTest do
  use PhoenixEctoOpenApiDemo.DataCase

  alias PhoenixEctoOpenApiDemo.TenantContext

  describe "tenants" do
    alias PhoenixEctoOpenApiDemo.TenantContext.Tenant

    import PhoenixEctoOpenApiDemo.TenantContextFixtures

    @invalid_attrs %{name: nil}

    test "list_tenants/0 returns all tenants" do
      tenant = tenant_fixture()
      assert TenantContext.list_tenants() == [tenant]
    end

    test "get_tenant!/1 returns the tenant with given id" do
      tenant = tenant_fixture()
      assert TenantContext.get_tenant!(tenant.id) == tenant
    end

    test "create_tenant/1 with valid data creates a tenant" do
      valid_attrs = %{name: "some name"}

      assert {:ok, %Tenant{} = tenant} = TenantContext.create_tenant(valid_attrs)
      assert tenant.name == "some name"
    end

    test "create_tenant/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = TenantContext.create_tenant(@invalid_attrs)
    end

    test "update_tenant/2 with valid data updates the tenant" do
      tenant = tenant_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Tenant{} = tenant} = TenantContext.update_tenant(tenant, update_attrs)
      assert tenant.name == "some updated name"
    end

    test "update_tenant/2 with invalid data returns error changeset" do
      tenant = tenant_fixture()
      assert {:error, %Ecto.Changeset{}} = TenantContext.update_tenant(tenant, @invalid_attrs)
      assert tenant == TenantContext.get_tenant!(tenant.id)
    end

    test "delete_tenant/1 deletes the tenant" do
      tenant = tenant_fixture()
      assert {:ok, %Tenant{}} = TenantContext.delete_tenant(tenant)
      assert_raise Ecto.NoResultsError, fn -> TenantContext.get_tenant!(tenant.id) end
    end

    test "change_tenant/1 returns a tenant changeset" do
      tenant = tenant_fixture()
      assert %Ecto.Changeset{} = TenantContext.change_tenant(tenant)
    end
  end
end
