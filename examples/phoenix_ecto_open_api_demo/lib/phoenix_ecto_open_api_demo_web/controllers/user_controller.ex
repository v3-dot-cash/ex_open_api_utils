defmodule PhoenixEctoOpenApiDemoWeb.UserController do
  use PhoenixEctoOpenApiDemoWeb, :controller

  alias PhoenixEctoOpenApiDemo.UserContext
  alias PhoenixEctoOpenApiDemo.UserContext.User

  alias PhoenixEctoOpenApiDemo.OpenApiSchema.{UserRequest, UserResponse}
  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true

  action_fallback PhoenixEctoOpenApiDemoWeb.FallbackController

  tags(["User"])

  operation(:index,
    summary: "Gets the list of users",
    operation_id: "User.list",
    responses: [
      ok: {"User list response", "application/json", %Schema{type: :array, items: UserResponse}}
    ]
  )

  def index(conn, _params) do
    users = UserContext.list_users()
    render(conn, :index, users: users)
  end

  operation(:create,
    summary: "Creates an userr",
    operation_id: "User.create",
    request_body: {"User Creation Body", "application/json", UserRequest},
    responses: [
      created: {"User  response", "application/json", UserResponse}
    ]
  )

  def create(%{body_params: %UserRequest{} = user_request} = conn, %{}) do
    with {:ok, %User{} = user} <- UserContext.create_user(user_request) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/users/#{user}")
      |> render(:show, user: user)
    end
  end

  operation(:show,
    summary: "Fetches an user for a customer",
    operation_id: "User.show",
    parameters: [
      id: [
        in: :path,
        description: "User ID",
        type: :string,
        example: "851b18d7-0c88-4095-9969-cbe385926420"
      ]
    ],
    responses: [
      ok: {"User  response", "application/json", UserResponse}
    ]
  )

  def show(conn, %{id: id}) do
    user = UserContext.get_user!(id)
    render(conn, :show, user: user)
  end

  operation(:update,
    summary: "Updates an user for a customer",
    operation_id: "User.update",
    parameters: [
      id: [
        in: :path,
        description: "User ID",
        type: :string,
        example: "851b18d7-0c88-4095-9969-cbe385926420"
      ]
    ],
    request_body: {"User Update Body", "application/json", UserRequest},
    responses: [
      ok: {"User  response", "application/json", UserResponse}
    ]
  )

  def update(%{body_params: %UserRequest{} = user_request} = conn, %{id: id}) do
    user = UserContext.get_user!(id)

    with {:ok, %User{} = user} <- UserContext.update_user(user, user_request) do
      render(conn, :show, user: user)
    end
  end

  operation(:delete,
    summary: "Delete an existing user",
    operation_id: "User.delete",
    parameters: [
      id: [
        in: :path,
        description: "User ID",
        type: :string,
        example: "851b18d7-0c88-4095-9969-cbe385926420"
      ]
    ],
    responses: [
      no_content: "Empty Response"
    ]
  )

  def delete(conn, %{id: id}) do
    user = UserContext.get_user!(id)

    with {:ok, %User{}} <- UserContext.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end
end
