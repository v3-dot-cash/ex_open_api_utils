defmodule PhoenixEctoOpenApiDemo.SubscriptionContext do
  @moduledoc """
  Context module for event subscriptions with a nested polymorphic
  delivery destination.

  Demonstrates the GH-34 nested polymorphic pattern end-to-end:
  `Subscription.destination` → (`WebhookDestination` → `:auth` → `OAuthAuth`
  → `:grant` → leaf grants) or `EmailDestination` (flat). Three
  `open_api_polymorphic_property` macros stacked, handled transparently
  by the library's self-stamping parent-contextual sibling Mapper impls.
  """
  import Ecto.Query, warn: false

  alias PhoenixEctoOpenApiDemo.Repo
  alias PhoenixEctoOpenApiDemo.SubscriptionContext.Subscription

  def list_subscriptions do
    Repo.all(Subscription)
  end

  def get_subscription!(id), do: Repo.get!(Subscription, id)

  def create_subscription(attrs) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  def update_subscription(%Subscription{} = subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update()
  end

  def delete_subscription(%Subscription{} = subscription) do
    Repo.delete(subscription)
  end
end
