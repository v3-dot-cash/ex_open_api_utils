defmodule PhoenixEctoOpenApiDemoWeb.SubscriptionControllerTest do
  @moduledoc """
  End-to-end lock for GH-34 nested polymorphic `open_api_polymorphic_property`
  support. Each test goes through the full Phoenix pipeline — `CastAndValidate`
  on the request, changeset via `ExOpenApiUtils.Changeset.cast`, Repo insert,
  render via `ExOpenApiUtils.Mapper.to_map`, and finally re-casts the wire
  JSON response via `OpenApiSpex.Cast.cast/4` against the resolved
  `SubscriptionResponse` schema to produce a typed struct tree for
  deep-pattern matching.

  Before 0.15.0, any test with nesting depth >= 2 would fail because
  `Mapper.to_map` didn't stamp `:__type__` on the nested destination submaps
  during the outbound serialization path. `cast_polymorphic_embed/3` at the
  nested level then raised `PolymorphicEmbed.raise_cannot_infer_type_from_data/1`.
  The self-stamping parent-contextual sibling Mapper impls (Option 3) close
  that gap — each sibling's `defimpl` stamps its own Ecto type-field atom on
  its own result map from compile-time constants.
  """
  use PhoenixEctoOpenApiDemoWeb.ConnCase

  import PhoenixEctoOpenApiDemo.SubscriptionContextFixtures

  alias OpenApiSpex.Cast
  alias PhoenixEctoOpenApiDemo.SubscriptionContext
  alias PhoenixEctoOpenApiDemo.SubscriptionContext.AuthorizationCodeGrant
  alias PhoenixEctoOpenApiDemo.SubscriptionContext.BasicAuth
  alias PhoenixEctoOpenApiDemo.SubscriptionContext.ClientCredentialsGrant
  alias PhoenixEctoOpenApiDemo.SubscriptionContext.EmailDestination
  alias PhoenixEctoOpenApiDemo.SubscriptionContext.OAuthAuth
  alias PhoenixEctoOpenApiDemo.SubscriptionContext.Subscription
  alias PhoenixEctoOpenApiDemo.SubscriptionContext.WebhookDestination

  # Auto-generated OpenApiSpex Response submodules. Flat names per the
  # library's naming: `<parent_title><variant_title><direction_suffix>`.
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.OAuthAuthorizationCodeGrantResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.OAuthClientCredentialsGrantResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.SubscriptionEmailDestinationResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.SubscriptionResponse, as: SubscriptionResponseSchema
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.SubscriptionWebhookDestinationResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.WebhookDestinationBasicAuthResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.WebhookDestinationOAuthResponse

  @api_spec PhoenixEctoOpenApiDemoWeb.ApiSpec.spec()

  @email_attrs %{
    name: "Ops digest",
    destination: %{
      destination_type: "email",
      recipient: "ops@example.com"
    }
  }

  @basic_auth_attrs %{
    name: "Infra alerts",
    destination: %{
      destination_type: "webhook",
      url: "https://hooks.example.com/infra",
      method: "POST",
      auth: %{
        auth_type: "basic",
        username: "alice",
        password: "s3cret"
      }
    }
  }

  @client_credentials_attrs %{
    name: "Order events subscription",
    destination: %{
      destination_type: "webhook",
      url: "https://hooks.example.com/orders",
      method: "POST",
      auth: %{
        auth_type: "oauth",
        token_url: "https://auth.example.com/oauth/token",
        client_id: "client-abc-123",
        grant: %{
          grant_type: "client_credentials",
          client_secret: "sk-example-secret",
          scope: "read:events write:webhooks"
        }
      }
    }
  }

  @authorization_code_attrs %{
    name: "Authz-code subscription",
    destination: %{
      destination_type: "webhook",
      url: "https://hooks.example.com/authz",
      method: "POST",
      auth: %{
        auth_type: "oauth",
        token_url: "https://auth.example.com/oauth/token",
        client_id: "client-zzz-789",
        grant: %{
          grant_type: "authorization_code",
          authorization_code: "ac_example_code",
          redirect_uri: "https://app.example.com/oauth/callback"
        }
      }
    }
  }

  setup %{conn: conn} do
    {:ok,
     conn:
       conn
       |> put_req_header("accept", "application/json")
       |> put_req_header("content-type", "application/json")}
  end

  defp cast_response(body) do
    schemas = @api_spec.components.schemas
    schema = Map.fetch!(schemas, "SubscriptionResponse")
    Cast.cast(schema, body, schemas)
  end

  describe "create — nesting depth 3 (webhook → oauth → client_credentials)" do
    test "returns 201 with all three discriminators on the wire, cast tree has correct leaf type, Ecto tree persisted",
         %{conn: conn} do
      conn = post(conn, ~p"/api/subscriptions", @client_credentials_attrs)
      body = json_response(conn, 201)

      # Wire shape — the three wire discriminators at three nesting levels
      assert body["destination"]["destination_type"] == "webhook"
      assert body["destination"]["auth"]["auth_type"] == "oauth"
      assert body["destination"]["auth"]["grant"]["grant_type"] == "client_credentials"

      # Re-cast via OpenApiSpex → typed struct tree, three oneOf routings
      assert {:ok, cast} = cast_response(body)

      assert %SubscriptionResponseSchema{
               id: id,
               name: "Order events subscription",
               destination: %SubscriptionWebhookDestinationResponse{
                 url: "https://hooks.example.com/orders",
                 method: "POST",
                 auth: %WebhookDestinationOAuthResponse{
                   token_url: "https://auth.example.com/oauth/token",
                   client_id: "client-abc-123",
                   grant: %OAuthClientCredentialsGrantResponse{
                     scope: "read:events write:webhooks"
                   }
                 }
               }
             } = cast

      assert is_binary(id)
      assert {:ok, _} = Ecto.UUID.cast(id)

      # Persistence round-trip — Ecto tree hydrated from JSONB
      assert %Subscription{
               id: ^id,
               name: "Order events subscription",
               destination: %WebhookDestination{
                 url: "https://hooks.example.com/orders",
                 method: "POST",
                 auth: %OAuthAuth{
                   token_url: "https://auth.example.com/oauth/token",
                   client_id: "client-abc-123",
                   grant: %ClientCredentialsGrant{
                     client_secret: "sk-example-secret",
                     scope: "read:events write:webhooks"
                   }
                 }
               }
             } = SubscriptionContext.get_subscription!(id)
    end
  end

  describe "create — nesting depth 3 (webhook → oauth → authorization_code)" do
    test "returns 201, cast tree terminates at AuthorizationCodeGrant leaf, Ecto tree persisted",
         %{conn: conn} do
      conn = post(conn, ~p"/api/subscriptions", @authorization_code_attrs)
      body = json_response(conn, 201)

      assert body["destination"]["destination_type"] == "webhook"
      assert body["destination"]["auth"]["auth_type"] == "oauth"
      assert body["destination"]["auth"]["grant"]["grant_type"] == "authorization_code"

      assert {:ok, cast} = cast_response(body)

      assert %SubscriptionResponseSchema{
               id: id,
               name: "Authz-code subscription",
               destination: %SubscriptionWebhookDestinationResponse{
                 auth: %WebhookDestinationOAuthResponse{
                   grant: %OAuthAuthorizationCodeGrantResponse{
                     redirect_uri: "https://app.example.com/oauth/callback"
                   }
                 }
               }
             } = cast

      assert %Subscription{
               destination: %WebhookDestination{
                 auth: %OAuthAuth{
                   grant: %AuthorizationCodeGrant{
                     authorization_code: "ac_example_code",
                     redirect_uri: "https://app.example.com/oauth/callback"
                   }
                 }
               }
             } = SubscriptionContext.get_subscription!(id)
    end
  end

  describe "create — nesting depth 2 (webhook → basic)" do
    test "returns 201, cast tree terminates at BasicAuth leaf, Ecto tree persisted",
         %{conn: conn} do
      conn = post(conn, ~p"/api/subscriptions", @basic_auth_attrs)
      body = json_response(conn, 201)

      assert body["destination"]["destination_type"] == "webhook"
      assert body["destination"]["auth"]["auth_type"] == "basic"

      assert {:ok, cast} = cast_response(body)

      assert %SubscriptionResponseSchema{
               id: id,
               name: "Infra alerts",
               destination: %SubscriptionWebhookDestinationResponse{
                 url: "https://hooks.example.com/infra",
                 method: "POST",
                 auth: %WebhookDestinationBasicAuthResponse{
                   username: "alice"
                 }
               }
             } = cast

      assert %Subscription{
               destination: %WebhookDestination{
                 auth: %BasicAuth{username: "alice", password: "s3cret"}
               }
             } = SubscriptionContext.get_subscription!(id)
    end
  end

  describe "create — nesting depth 1 (flat email)" do
    test "returns 201, cast tree terminates at EmailDestination leaf (0.14.0 parity check)",
         %{conn: conn} do
      conn = post(conn, ~p"/api/subscriptions", @email_attrs)
      body = json_response(conn, 201)

      assert body["destination"]["destination_type"] == "email"

      assert {:ok, cast} = cast_response(body)

      assert %SubscriptionResponseSchema{
               id: id,
               name: "Ops digest",
               destination: %SubscriptionEmailDestinationResponse{
                 recipient: "ops@example.com"
               }
             } = cast

      assert %Subscription{
               destination: %EmailDestination{recipient: "ops@example.com"}
             } = SubscriptionContext.get_subscription!(id)
    end
  end

  describe "create — validation errors on nested levels" do
    test "returns 422 when level-3 grant_type is missing", %{conn: conn} do
      invalid =
        put_in(@client_credentials_attrs, [:destination, :auth, :grant], %{
          client_secret: "sk-example-secret"
        })

      conn = post(conn, ~p"/api/subscriptions", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 when level-2 auth_type is missing", %{conn: conn} do
      invalid = put_in(@basic_auth_attrs, [:destination, :auth], %{username: "alice"})
      conn = post(conn, ~p"/api/subscriptions", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 when level-3 grant_type is a bogus value", %{conn: conn} do
      invalid =
        put_in(
          @client_credentials_attrs,
          [:destination, :auth, :grant, :grant_type],
          "magic_token"
        )

      conn = post(conn, ~p"/api/subscriptions", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "show — full 3-level nested response round-trip" do
    test "GET on a fixture-persisted 3-level subscription returns wire JSON with discriminators at every level",
         %{conn: conn} do
      subscription = oauth_client_credentials_subscription_fixture()

      conn = get(conn, ~p"/api/subscriptions/#{subscription.id}")
      body = json_response(conn, 200)

      # Three wire discriminators at three distinct nesting levels — GH-34
      # would have failed this assertion on the response side because
      # `Mapper.to_map` on the outbound `%Subscription{}` Ecto struct uses
      # the `:from_ecto` direction which was already working, BUT: the
      # assert-schema re-cast below would then fail at the nested level
      # because the resurrected parent-contextual sibling's Mapper impl
      # used to not stamp `:__type__`.
      assert body["destination"]["destination_type"] == "webhook"
      assert body["destination"]["auth"]["auth_type"] == "oauth"
      assert body["destination"]["auth"]["grant"]["grant_type"] == "client_credentials"

      assert {:ok, cast} = cast_response(body)

      assert %SubscriptionResponseSchema{
               destination: %SubscriptionWebhookDestinationResponse{
                 auth: %WebhookDestinationOAuthResponse{
                   grant: %OAuthClientCredentialsGrantResponse{
                     scope: "read:events write:webhooks"
                   }
                 }
               }
             } = cast
    end
  end

  describe "index — mixed nesting depths" do
    test "returns a list where each row's destination casts to the correct nested variant tree",
         %{conn: conn} do
      email_subscription_fixture()
      basic_auth_subscription_fixture()
      oauth_client_credentials_subscription_fixture()

      conn = get(conn, ~p"/api/subscriptions")
      body = json_response(conn, 200)
      assert length(body) == 3

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "SubscriptionResponse")

      cast_items =
        Enum.map(body, fn item ->
          assert {:ok, cast} = Cast.cast(schema, item, schemas)
          cast
        end)

      by_shape =
        Enum.group_by(cast_items, fn
          %SubscriptionResponseSchema{destination: %SubscriptionEmailDestinationResponse{}} ->
            :email

          %SubscriptionResponseSchema{
            destination: %SubscriptionWebhookDestinationResponse{
              auth: %WebhookDestinationBasicAuthResponse{}
            }
          } ->
            :basic

          %SubscriptionResponseSchema{
            destination: %SubscriptionWebhookDestinationResponse{
              auth: %WebhookDestinationOAuthResponse{
                grant: %OAuthClientCredentialsGrantResponse{}
              }
            }
          } ->
            :oauth_client_credentials
        end)

      assert length(by_shape[:email]) == 1
      assert length(by_shape[:basic]) == 1
      assert length(by_shape[:oauth_client_credentials]) == 1
    end
  end
end
