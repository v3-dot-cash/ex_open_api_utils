defmodule PhoenixEctoOpenApiDemoWeb.BusinessController do
  use PhoenixEctoOpenApiDemoWeb, :controller

  alias PhoenixEctoOpenApiDemo.BusinessContext
  alias PhoenixEctoOpenApiDemo.BusinessContext.Business

  alias PhoenixEctoOpenApiDemo.OpenApiSchema.{BusinessRequest, BusinessResponse}
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true

  action_fallback PhoenixEctoOpenApiDemoWeb.FallbackController

  tags(["Business"])

  operation(:index,
    summary: "Gets the list of busineses",
    operationId: "Business.list",
    responses: [
      ok:
        {"Business list response", "application/json",
         %Schema{type: :array, description: "list of tenants", items: BusinessResponse}}
    ]
  )

  def index(conn, _params) do
    businesses = BusinessContext.list_businesses()
    render(conn, :index, businesses: businesses)
  end

  operation(:create,
    summary: "Creates an user for a business",
    operationId: "Business.create",
    request_body: {"User Creation Body", "application/json", BusinessRequest},
    responses: [
      created: {"Business response", "application/json", BusinessResponse}
    ]
  )

  def create(%{body_params: %BusinessRequest{} = business_request} = conn, %{}) do
    with {:ok, %Business{} = business} <- BusinessContext.create_business(business_request) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/businesses/#{business}")
      |> render(:show, business: business)
    end
  end

  operation(:show,
    summary: "Fetches an user",
    operationId: "Business.show",
    parameters: [
      id: [
        in: :path,
        description: "Business ID",
        type: :string,
        example: "851b18d7-0c88-4095-9969-cbe385926420"
      ]
    ],
    responses: [
      ok: {"business  response", "application/json", BusinessResponse}
    ]
  )

  def show(conn, %{id: id}) do
    business = BusinessContext.get_business!(id)
    render(conn, :show, business: business)
  end

  operation(:update,
    summary: "Updates a Business",
    operationId: "Business.update",
    parameters: [
      id: [
        in: :path,
        description: "Business ID",
        type: :string,
        example: "851b18d7-0c88-4095-9969-cbe385926420"
      ]
    ],
    request_body: {"Business Update Body", "application/json", BusinessRequest},
    responses: [
      ok: {"Business response", "application/json", BusinessResponse}
    ]
  )

  def update(%{body_params: %BusinessRequest{} = business_request} = conn, %{id: id}) do
    business = BusinessContext.get_business!(id)

    with {:ok, %Business{} = business} <-
           BusinessContext.update_business(business, business_request) do
      render(conn, :show, business: business)
    end
  end

  operation(:delete,
    summary: "Delete an existing business",
    operationId: "Business.delete",
    parameters: [
      id: [
        in: :path,
        description: "Business ID",
        type: :string,
        example: "851b18d7-0c88-4095-9969-cbe385926420"
      ]
    ],
    responses: [
      no_content: "Empty Response"
    ]
  )

  def delete(conn, %{id: id}) do
    business = BusinessContext.get_business!(id)

    with {:ok, %Business{}} <- BusinessContext.delete_business(business) do
      send_resp(conn, :no_content, "")
    end
  end
end
