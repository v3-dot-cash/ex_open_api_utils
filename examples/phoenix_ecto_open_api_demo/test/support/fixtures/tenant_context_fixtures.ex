defmodule PhoenixEctoOpenApiDemo.TenantContextFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PhoenixEctoOpenApiDemo.TenantContext` context.
  """

  @doc """
  Generate a tenant.
  """
  def tenant_fixture(attrs \\ %{}) do
    {:ok, tenant} =
      attrs
      |> Enum.into(%{
        name: "some name"
      })
      |> PhoenixEctoOpenApiDemo.TenantContext.create_tenant()

    tenant
  end
end
