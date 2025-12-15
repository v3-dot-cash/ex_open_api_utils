defmodule PhoenixEctoOpenApiDemoWeb.TenantController do
  use PhoenixEctoOpenApiDemoWeb, :controller

  alias PhoenixEctoOpenApiDemo.TenantContext
  alias PhoenixEctoOpenApiDemo.TenantContext.Tenant

  alias PhoenixEctoOpenApiDemo.OpenApiSchema.{TenantRequest, TenantResponse}
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true

  action_fallback PhoenixEctoOpenApiDemoWeb.FallbackController

  tags(["Tenant"])

  operation(:index,
    summary: "Gets the list of tenants",
    operation_id: "Tenant.list",
    responses: [
      ok:
        {"Tenant list response", "application/json",
         %Schema{type: :array, description: "list of tenants", items: TenantResponse}}
    ]
  )

  def index(conn, _params) do
    tenants = TenantContext.list_tenants()
    render(conn, :index, tenants: tenants)
  end

  operation(:create,
    summary: "Create a new tenant",
    operation_id: "Tenant.create",
    request_body: {"Tenant Creating Body", "application/json", TenantRequest},
    responses: [
      created: {"Tenant  response", "application/json", TenantResponse}
    ]
  )

  def create(%{body_params: %TenantRequest{} = tenant_request} = conn, %{}) do
    with {:ok, %Tenant{} = tenant} <- TenantContext.create_tenant(tenant_request) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/tenants/#{tenant}")
      |> render(:show, tenant: tenant)
    end
  end

  operation(:show,
    summary: "Gets the details of individual tenant",
    operation_id: "Tenant.get",
    parameters: [
      id: [
        in: :path,
        description: "Tenant ID",
        type: :string,
        example: "851b18d7-0c88-4095-9969-cbe385926420"
      ]
    ],
    responses: [
      ok: {"Tenant  response", "application/json", TenantResponse}
    ]
  )

  def show(conn, %{id: id}) do
    tenant = TenantContext.get_tenant!(id)
    render(conn, :show, tenant: tenant)
  end

  operation(:update,
    summary: "Update an existing tenant",
    operation_id: "Tenant.update",
    parameters: [
      id: [
        in: :path,
        description: "Tenant ID",
        type: :string,
        example: "851b18d7-0c88-4095-9969-cbe385926420"
      ]
    ],
    request_body: {"Tenant Creating Body", "application/json", TenantRequest},
    responses: [
      ok: {"Tenant  response", "application/json", TenantResponse}
    ]
  )

  def update(%{body_params: %TenantRequest{} = tenant_request} = conn, %{id: id}) do
    tenant = TenantContext.get_tenant!(id)

    with {:ok, %Tenant{} = tenant} <- TenantContext.update_tenant(tenant, tenant_request) do
      render(conn, :show, tenant: tenant)
    end
  end

  operation(:delete,
    summary: "Delete an existing tenant",
    operation_id: "Tenant.delete",
    parameters: [
      id: [
        in: :path,
        description: "Tenant ID",
        type: :string,
        example: "851b18d7-0c88-4095-9969-cbe385926420"
      ]
    ],
    responses: [
      no_content: "Empty Response"
    ]
  )

  def delete(conn, %{id: id}) do
    tenant = TenantContext.get_tenant!(id)

    with {:ok, %Tenant{}} <- TenantContext.delete_tenant(tenant) do
      send_resp(conn, :no_content, "")
    end
  end
end
