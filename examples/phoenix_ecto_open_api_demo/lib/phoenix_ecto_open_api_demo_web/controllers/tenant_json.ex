defmodule PhoenixEctoOpenApiDemoWeb.TenantJSON do
  alias PhoenixEctoOpenApiDemo.TenantContext.Tenant

  @doc """
  Renders a list of tenants.
  """
  def index(%{tenants: tenants}) do
    for(tenant <- tenants, do: data(tenant))
  end

  @doc """
  Renders a single tenant.
  """
  def show(%{tenant: tenant}) do
    data(tenant)
  end

  defp data(%Tenant{} = tenant) do
    ExOpenApiUtils.Json.to_json(tenant)
  end
end
