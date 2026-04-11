defmodule PhoenixEctoOpenApiDemo.SubscriptionContextFixtures do
  @moduledoc """
  Test helpers for creating `PhoenixEctoOpenApiDemo.SubscriptionContext`
  entities. Fixtures exercise the three nested polymorphic depths:

    * `email_subscription_fixture/1` — 1-level (flat EmailDestination)
    * `basic_auth_subscription_fixture/1` — 2-level (WebhookDestination → BasicAuth)
    * `oauth_client_credentials_subscription_fixture/1` — 3-level
      (WebhookDestination → OAuthAuth → ClientCredentialsGrant)
    * `oauth_authorization_code_subscription_fixture/1` — 3-level
      (WebhookDestination → OAuthAuth → AuthorizationCodeGrant)

  Each uses the Ecto atom `:__type__` key because the changeset path
  consumes the maps via `cast_polymorphic_embed/3`, which reads
  `:__type__` at every nesting level.
  """

  alias PhoenixEctoOpenApiDemo.SubscriptionContext

  @doc "Creates a subscription with a flat email destination (level 1)."
  def email_subscription_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Ops digest",
        destination: %{
          __type__: "email",
          recipient: "ops@example.com"
        }
      })

    {:ok, subscription} = SubscriptionContext.create_subscription(attrs)
    subscription
  end

  @doc "Creates a subscription with a webhook destination + basic auth (level 2)."
  def basic_auth_subscription_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Infra alerts",
        destination: %{
          __type__: "webhook",
          url: "https://hooks.example.com/infra",
          method: "POST",
          auth: %{
            __type__: "basic",
            username: "alice",
            password: "s3cret"
          }
        }
      })

    {:ok, subscription} = SubscriptionContext.create_subscription(attrs)
    subscription
  end

  @doc """
  Creates a subscription with a webhook destination + OAuth +
  client_credentials grant (level 3 — the deepest chain).
  """
  def oauth_client_credentials_subscription_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Order events subscription",
        destination: %{
          __type__: "webhook",
          url: "https://hooks.example.com/orders",
          method: "POST",
          auth: %{
            __type__: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-abc-123",
            grant: %{
              __type__: "client_credentials",
              client_secret: "sk-example-secret",
              scope: "read:events write:webhooks"
            }
          }
        }
      })

    {:ok, subscription} = SubscriptionContext.create_subscription(attrs)
    subscription
  end

  @doc """
  Creates a subscription with a webhook destination + OAuth +
  authorization_code grant (level 3 — alternate deepest chain).
  """
  def oauth_authorization_code_subscription_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Authz-code subscription",
        destination: %{
          __type__: "webhook",
          url: "https://hooks.example.com/authz",
          method: "POST",
          auth: %{
            __type__: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-zzz-789",
            grant: %{
              __type__: "authorization_code",
              authorization_code: "ac_example_code",
              redirect_uri: "https://app.example.com/oauth/callback"
            }
          }
        }
      })

    {:ok, subscription} = SubscriptionContext.create_subscription(attrs)
    subscription
  end
end
