defmodule PhoenixEctoOpenApiDemoWeb.NotificationController do
  @moduledoc """
  Controller for the polymorphic-embed backed `Notification` resource.

  Key points:

    * `NotificationRequest` / `NotificationResponse` are the auto-generated
      `use ExOpenApiUtils` submodules. Their `:channel` property is a
      `oneOf + discriminator` schema pointing at the parent-contextual
      variant submodules (`NotificationEmailRequest` /
      `NotificationEmailResponse`, etc.) that GH-30's
      `open_api_polymorphic_property/1` macro generates via allOf
      composition. These siblings carry the discriminator as a real
      defstruct field so it survives the full round-trip through
      `Kernel.struct/2` unchanged.
    * `OpenApiSpex.Plug.CastAndValidate` casts the request body into a
      typed `%NotificationRequest{channel: %NotificationEmailRequest{...}}`
      struct and attaches it to `conn.body_params`.
    * The `:channel` field on the inbound struct already has
      `:channel_type` as a real field — `ExOpenApiUtils.Changeset.cast/3`
      walks the struct via the Mapper, which bridges the wire
      discriminator ("channel_type") to the Ecto `type_field_name`
      (`:__type__`) before handing the flattened params to
      `Ecto.Changeset.cast` and `cast_polymorphic_embed/3`.
    * `NotificationJSON` renders via `ExOpenApiUtils.Mapper.to_map/1`, which
      injects the wire form (`"channel_type" => "email"`) for the response.
  """
  use PhoenixEctoOpenApiDemoWeb, :controller

  alias PhoenixEctoOpenApiDemo.NotificationContext
  alias PhoenixEctoOpenApiDemo.NotificationContext.Notification

  alias PhoenixEctoOpenApiDemo.OpenApiSchema.NotificationRequest
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.NotificationResponse

  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true

  action_fallback PhoenixEctoOpenApiDemoWeb.FallbackController

  tags(["Notification"])

  operation(:index,
    summary: "Lists notifications (with polymorphic channels)",
    operation_id: "Notification.list",
    responses: [
      ok:
        {"Notification list response", "application/json",
         %Schema{
           type: :array,
           description: "list of notifications — each channel is a oneOf variant",
           items: NotificationResponse
         }}
    ]
  )

  def index(conn, _params) do
    notifications = NotificationContext.list_notifications()
    render(conn, :index, notifications: notifications)
  end

  operation(:create,
    summary: "Creates a notification with a polymorphic channel",
    operation_id: "Notification.create",
    request_body: {"Notification creation body", "application/json", NotificationRequest},
    responses: [
      created: {"Notification response", "application/json", NotificationResponse}
    ]
  )

  def create(%{body_params: %NotificationRequest{} = request} = conn, _params) do
    with {:ok, %Notification{} = notification} <-
           NotificationContext.create_notification(request) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/notifications/#{notification}")
      |> render(:show, notification: notification)
    end
  end

  operation(:show,
    summary: "Fetches a notification",
    operation_id: "Notification.show",
    parameters: [
      id: [
        in: :path,
        description: "Notification ID",
        type: :string,
        example: "851b18d7-0c88-4095-9969-cbe385926420"
      ]
    ],
    responses: [
      ok: {"Notification response", "application/json", NotificationResponse}
    ]
  )

  def show(conn, %{id: id}) do
    notification = NotificationContext.get_notification!(id)
    render(conn, :show, notification: notification)
  end

  operation(:update,
    summary: "Updates a notification",
    operation_id: "Notification.update",
    parameters: [
      id: [
        in: :path,
        description: "Notification ID",
        type: :string,
        example: "851b18d7-0c88-4095-9969-cbe385926420"
      ]
    ],
    request_body: {"Notification update body", "application/json", NotificationRequest},
    responses: [
      ok: {"Notification response", "application/json", NotificationResponse}
    ]
  )

  def update(%{body_params: %NotificationRequest{} = request} = conn, %{id: id}) do
    notification = NotificationContext.get_notification!(id)

    with {:ok, %Notification{} = notification} <-
           NotificationContext.update_notification(notification, request) do
      render(conn, :show, notification: notification)
    end
  end

  operation(:delete,
    summary: "Deletes an existing notification",
    operation_id: "Notification.delete",
    parameters: [
      id: [
        in: :path,
        description: "Notification ID",
        type: :string,
        example: "851b18d7-0c88-4095-9969-cbe385926420"
      ]
    ],
    responses: [
      no_content: "Empty Response"
    ]
  )

  def delete(conn, %{id: id}) do
    notification = NotificationContext.get_notification!(id)

    with {:ok, %Notification{}} <- NotificationContext.delete_notification(notification) do
      send_resp(conn, :no_content, "")
    end
  end
end
