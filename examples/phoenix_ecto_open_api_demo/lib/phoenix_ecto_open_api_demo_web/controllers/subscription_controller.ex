defmodule PhoenixEctoOpenApiDemoWeb.SubscriptionController do
  @moduledoc """
  Controller for the nested-polymorphic-backed `Subscription` resource.

  This is the GH-34 end-to-end lock. The `:destination` property is a
  polymorphic oneOf over `[webhook, email]`, and the `webhook` variant
  (`WebhookDestination`) has a further polymorphic `:auth` over
  `[oauth, basic]`, and the `oauth` variant (`OAuthAuth`) has a further
  polymorphic `:grant` over `[client_credentials, authorization_code]`.
  Three stacked `open_api_polymorphic_property` macros.

  Before 0.15.0, posting a subscription with `destination_type=webhook`,
  `auth_type=oauth`, `grant_type=client_credentials` raised
  `PolymorphicEmbed.raise_cannot_infer_type_from_data/1` at the nested
  `cast_polymorphic_embed(:auth)` or `cast_polymorphic_embed(:grant)`
  call because `Mapper.to_map` dropped `:__type__` at the nested levels.
  The self-stamping parent-contextual sibling Mapper impls close that gap.
  """
  use PhoenixEctoOpenApiDemoWeb, :controller

  alias PhoenixEctoOpenApiDemo.SubscriptionContext
  alias PhoenixEctoOpenApiDemo.SubscriptionContext.Subscription

  alias PhoenixEctoOpenApiDemo.OpenApiSchema.SubscriptionRequest
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.SubscriptionResponse

  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true

  action_fallback PhoenixEctoOpenApiDemoWeb.FallbackController

  tags(["Subscription"])

  operation(:index,
    summary: "Lists subscriptions (with nested polymorphic destinations)",
    operation_id: "Subscription.list",
    responses: [
      ok:
        {"Subscription list response", "application/json",
         %Schema{
           type: :array,
           description: "list of subscriptions — each destination is a nested polymorphic tree",
           items: SubscriptionResponse
         }}
    ]
  )

  def index(conn, _params) do
    subscriptions = SubscriptionContext.list_subscriptions()
    render(conn, :index, subscriptions: subscriptions)
  end

  operation(:create,
    summary: "Creates a subscription with a nested polymorphic destination",
    operation_id: "Subscription.create",
    request_body: {"Subscription creation body", "application/json", SubscriptionRequest},
    responses: [
      created: {"Subscription response", "application/json", SubscriptionResponse}
    ]
  )

  def create(%{body_params: %SubscriptionRequest{} = request} = conn, _params) do
    with {:ok, %Subscription{} = subscription} <-
           SubscriptionContext.create_subscription(request) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/subscriptions/#{subscription}")
      |> render(:show, subscription: subscription)
    end
  end

  operation(:show,
    summary: "Fetches a subscription",
    operation_id: "Subscription.show",
    parameters: [
      id: [
        in: :path,
        description: "Subscription ID",
        type: :string,
        example: "b7f4c2a0-1e3d-4a7e-9c6b-8f2d1e5c3a9b"
      ]
    ],
    responses: [
      ok: {"Subscription response", "application/json", SubscriptionResponse}
    ]
  )

  def show(conn, %{id: id}) do
    subscription = SubscriptionContext.get_subscription!(id)
    render(conn, :show, subscription: subscription)
  end

  operation(:update,
    summary: "Updates a subscription",
    operation_id: "Subscription.update",
    parameters: [
      id: [
        in: :path,
        description: "Subscription ID",
        type: :string,
        example: "b7f4c2a0-1e3d-4a7e-9c6b-8f2d1e5c3a9b"
      ]
    ],
    request_body: {"Subscription update body", "application/json", SubscriptionRequest},
    responses: [
      ok: {"Subscription response", "application/json", SubscriptionResponse}
    ]
  )

  def update(%{body_params: %SubscriptionRequest{} = request} = conn, %{id: id}) do
    subscription = SubscriptionContext.get_subscription!(id)

    with {:ok, %Subscription{} = subscription} <-
           SubscriptionContext.update_subscription(subscription, request) do
      render(conn, :show, subscription: subscription)
    end
  end

  operation(:delete,
    summary: "Deletes an existing subscription",
    operation_id: "Subscription.delete",
    parameters: [
      id: [
        in: :path,
        description: "Subscription ID",
        type: :string,
        example: "b7f4c2a0-1e3d-4a7e-9c6b-8f2d1e5c3a9b"
      ]
    ],
    responses: [
      no_content: "Empty Response"
    ]
  )

  def delete(conn, %{id: id}) do
    subscription = SubscriptionContext.get_subscription!(id)

    with {:ok, %Subscription{}} <- SubscriptionContext.delete_subscription(subscription) do
      send_resp(conn, :no_content, "")
    end
  end
end
