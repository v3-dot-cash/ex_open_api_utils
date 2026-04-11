defmodule PhoenixEctoOpenApiDemoWeb.SubscriptionJSON do
  @moduledoc """
  JSON renderer for subscriptions. `ExOpenApiUtils.Mapper.to_map/1` handles
  everything — including stamping the wire discriminators
  (`"destination_type" => "webhook"`, `"auth_type" => "oauth"`,
  `"grant_type" => "client_credentials"`) at every nesting level of the
  polymorphic tree.
  """

  def index(%{subscriptions: subscriptions}) do
    Enum.map(subscriptions, &ExOpenApiUtils.Mapper.to_map/1)
  end

  def show(%{subscription: subscription}) do
    ExOpenApiUtils.Mapper.to_map(subscription)
  end
end
