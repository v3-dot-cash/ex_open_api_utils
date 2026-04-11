defmodule ExOpenApiUtils.NestedPolymorphicCastRoundTripTest do
  @moduledoc """
  GH-34 regression lock: `Mapper.to_map/1` must preserve the Ecto
  `type_field_name` atom (`:__type__`) on nested polymorphic submaps during
  the `:from_open_api` direction, so `cast_polymorphic_embed/3` at every
  nesting level can route variants correctly.

  Fixture tree (three stacked `open_api_polymorphic_property` macros):

      Nested.Subscription (level 0)
      ├── :destination polymorphic over [webhook, email]
      │     wire "destination_type"
      │
      ├── Nested.WebhookDestination (level 1, intermediate)
      │   └── :auth polymorphic over [oauth, basic]
      │         wire "auth_type"
      │         │
      │         ├── Nested.OAuthAuth (level 2, intermediate)
      │         │   └── :grant polymorphic over [client_credentials, authorization_code]
      │         │         wire "grant_type"
      │         │         │
      │         │         ├── Nested.ClientCredentialsGrant (level 3 leaf)
      │         │         └── Nested.AuthorizationCodeGrant (level 3 leaf)
      │         │
      │         └── Nested.BasicAuth (level 2 leaf)
      │
      └── Nested.EmailDestination (level 1 leaf — contrast)

  Before the fix: `Mapper.to_map` stamps `:__type__ => "webhook"` on the
  outer `:destination` submap (the level-1 case GH-30 covered), but the
  nested `:auth` and `:grant` submaps get no `:__type__` because
  `ToolSubscriptionWebhookDestinationRequest`'s Mapper impl is derived at
  Subscription's compile time with only Subscription's `polymorphic_variants`
  baked in — it doesn't know about WebhookDestination's own `:auth`
  declaration.

  After the fix (Option 3 self-stamping siblings): each parent-contextual
  sibling's Mapper impl is derived with two new options —
  `self_stamp_atom: :__type__` and `self_stamp_wire: "<wire>"` — and the
  `Any.__deriving__/3` macro splices a `Map.put(acc, atom, wire)` at the
  tail of the generated walker body. Each sibling stamps its own discriminator
  on its own result map from compile-time constants, no outer-walker coupling.
  """
  use ExUnit.Case, async: true

  alias OpenApiSpex.Cast
  alias OpenApiSpex.Schema

  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.AuthorizationCodeGrant
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.BasicAuth
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.ClientCredentialsGrant
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.EmailDestination
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.OAuthAuth
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.Subscription
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Nested.WebhookDestination

  alias ExOpenApiUtilsTest.OpenApiSchema.SubscriptionRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.SubscriptionResponse

  # Parent-contextual siblings generated at Subscription's __before_compile__
  alias ExOpenApiUtilsTest.OpenApiSchema.SubscriptionWebhookDestinationRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.SubscriptionWebhookDestinationResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.SubscriptionEmailDestinationRequest

  # Parent-contextual siblings generated at WebhookDestination's __before_compile__
  alias ExOpenApiUtilsTest.OpenApiSchema.WebhookDestinationOAuthRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.WebhookDestinationBasicAuthRequest

  # Parent-contextual siblings generated at OAuthAuth's __before_compile__
  alias ExOpenApiUtilsTest.OpenApiSchema.OAuthClientCredentialsGrantRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.OAuthAuthorizationCodeGrantRequest

  defp resolved_schemas do
    empty_spec = %OpenApiSpex.OpenApi{
      info: %OpenApiSpex.Info{title: "test", version: "0"},
      paths: %{},
      components: %OpenApiSpex.Components{schemas: %{}}
    }

    empty_spec
    |> OpenApiSpex.add_schemas([SubscriptionRequest, SubscriptionResponse])
    |> then(& &1.components.schemas)
  end

  defp cast_request(wire_map) do
    schemas = resolved_schemas()
    schema = Map.fetch!(schemas, "SubscriptionRequest")
    Cast.cast(schema, wire_map, schemas)
  end

  describe "GH-34 — Mapper.to_map stamps :__type__ at every nesting level on :from_open_api" do
    test "deepest chain (subscription → webhook → oauth → client_credentials) stamps :__type__ at all three polymorphic levels" do
      request = %SubscriptionRequest{
        name: "Order events subscription",
        destination: %SubscriptionWebhookDestinationRequest{
          destination_type: "webhook",
          url: "https://hooks.example.com/deliveries",
          method: "POST",
          auth: %WebhookDestinationOAuthRequest{
            auth_type: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-abc-123",
            grant: %OAuthClientCredentialsGrantRequest{
              grant_type: "client_credentials",
              client_secret: "sk-example-secret",
              scope: "read:events write:webhooks"
            }
          }
        }
      }

      attrs_map = ExOpenApiUtils.Mapper.to_map(request)

      # Level 1 — :destination submap
      assert get_in(attrs_map, [:destination, :__type__]) == "webhook"

      # Level 2 — :auth submap inside :destination — THIS IS THE GAP GH-34 CLOSES
      assert get_in(attrs_map, [:destination, :auth, :__type__]) == "oauth"

      # Level 3 — :grant submap inside :auth inside :destination — depth-unbounded
      assert get_in(attrs_map, [:destination, :auth, :grant, :__type__]) ==
               "client_credentials"

      # Wire-side discriminators (the existing discriminator_prop walker keeps these working)
      assert get_in(attrs_map, [:destination, :destination_type]) == "webhook"
      assert get_in(attrs_map, [:destination, :auth, :auth_type]) == "oauth"
      assert get_in(attrs_map, [:destination, :auth, :grant, :grant_type]) ==
               "client_credentials"
    end

    test "middle chain (subscription → webhook → basic) terminates cleanly at level 2" do
      request = %SubscriptionRequest{
        name: "Infra alerts",
        destination: %SubscriptionWebhookDestinationRequest{
          destination_type: "webhook",
          url: "https://hooks.example.com/infra",
          method: "POST",
          auth: %WebhookDestinationBasicAuthRequest{
            auth_type: "basic",
            username: "alice",
            password: "s3cret"
          }
        }
      }

      attrs_map = ExOpenApiUtils.Mapper.to_map(request)

      assert get_in(attrs_map, [:destination, :__type__]) == "webhook"
      assert get_in(attrs_map, [:destination, :auth, :__type__]) == "basic"
      assert get_in(attrs_map, [:destination, :auth, :username]) == "alice"
    end

    test "shallow chain (subscription → email) locks parity with 0.14.0 single-level behavior" do
      request = %SubscriptionRequest{
        name: "Ops digest",
        destination: %SubscriptionEmailDestinationRequest{
          destination_type: "email",
          recipient: "ops@example.com"
        }
      }

      attrs_map = ExOpenApiUtils.Mapper.to_map(request)

      assert get_in(attrs_map, [:destination, :__type__]) == "email"
      assert get_in(attrs_map, [:destination, :recipient]) == "ops@example.com"
    end

    test "authorization_code grant leaf is reachable via the same deepest chain" do
      request = %SubscriptionRequest{
        name: "Authz-code subscription",
        destination: %SubscriptionWebhookDestinationRequest{
          destination_type: "webhook",
          url: "https://hooks.example.com/authz",
          method: "POST",
          auth: %WebhookDestinationOAuthRequest{
            auth_type: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-zzz-789",
            grant: %OAuthAuthorizationCodeGrantRequest{
              grant_type: "authorization_code",
              authorization_code: "ac_example_code",
              redirect_uri: "https://app.example.com/oauth/callback"
            }
          }
        }
      }

      attrs_map = ExOpenApiUtils.Mapper.to_map(request)

      assert get_in(attrs_map, [:destination, :__type__]) == "webhook"
      assert get_in(attrs_map, [:destination, :auth, :__type__]) == "oauth"

      assert get_in(attrs_map, [:destination, :auth, :grant, :__type__]) ==
               "authorization_code"
    end
  end

  describe "GH-34 — full changeset round-trip through Ecto cast_polymorphic_embed at every nesting level" do
    test "deepest chain resolves to the full Ecto struct tree via apply_action(:insert)" do
      request = %SubscriptionRequest{
        name: "Order events subscription",
        destination: %SubscriptionWebhookDestinationRequest{
          destination_type: "webhook",
          url: "https://hooks.example.com/deliveries",
          method: "POST",
          auth: %WebhookDestinationOAuthRequest{
            auth_type: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-abc-123",
            grant: %OAuthClientCredentialsGrantRequest{
              grant_type: "client_credentials",
              client_secret: "sk-example-secret",
              scope: "read:events write:webhooks"
            }
          }
        }
      }

      assert {:ok,
              %Subscription{
                name: "Order events subscription",
                destination: %WebhookDestination{
                  url: "https://hooks.example.com/deliveries",
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
              }} =
               %Subscription{}
               |> Subscription.changeset(request)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "middle chain (basic auth) resolves to the Ecto tree, level 2 terminates cleanly" do
      request = %SubscriptionRequest{
        name: "Infra alerts",
        destination: %SubscriptionWebhookDestinationRequest{
          destination_type: "webhook",
          url: "https://hooks.example.com/infra",
          method: "POST",
          auth: %WebhookDestinationBasicAuthRequest{
            auth_type: "basic",
            username: "alice",
            password: "s3cret"
          }
        }
      }

      assert {:ok,
              %Subscription{
                destination: %WebhookDestination{
                  auth: %BasicAuth{username: "alice", password: "s3cret"}
                }
              }} =
               %Subscription{}
               |> Subscription.changeset(request)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "shallow chain (email destination) still works identically to 0.14.0 single-level case" do
      request = %SubscriptionRequest{
        name: "Ops digest",
        destination: %SubscriptionEmailDestinationRequest{
          destination_type: "email",
          recipient: "ops@example.com"
        }
      }

      assert {:ok,
              %Subscription{
                destination: %EmailDestination{recipient: "ops@example.com"}
              }} =
               %Subscription{}
               |> Subscription.changeset(request)
               |> Ecto.Changeset.apply_action(:insert)
    end

    test "authorization_code grant variant resolves to %AuthorizationCodeGrant{} at level 3" do
      request = %SubscriptionRequest{
        name: "Authz-code subscription",
        destination: %SubscriptionWebhookDestinationRequest{
          destination_type: "webhook",
          url: "https://hooks.example.com/authz",
          method: "POST",
          auth: %WebhookDestinationOAuthRequest{
            auth_type: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-zzz-789",
            grant: %OAuthAuthorizationCodeGrantRequest{
              grant_type: "authorization_code",
              authorization_code: "ac_example_code",
              redirect_uri: "https://app.example.com/oauth/callback"
            }
          }
        }
      }

      assert {:ok,
              %Subscription{
                destination: %WebhookDestination{
                  auth: %OAuthAuth{
                    grant: %AuthorizationCodeGrant{
                      authorization_code: "ac_example_code",
                      redirect_uri: "https://app.example.com/oauth/callback"
                    }
                  }
                }
              }} =
               %Subscription{}
               |> Subscription.changeset(request)
               |> Ecto.Changeset.apply_action(:insert)
    end
  end

  describe "GH-34 — :from_ecto direction regression lock (already worked in 0.14.0, no regression after fix)" do
    test "Mapper.to_map on the Ecto struct tree stamps wire discriminators at every level" do
      ecto_tree = %Subscription{
        id: "3f7d8c7a-3c3b-4c2d-9c5a-3f7d8c7a3c3b",
        name: "Order events",
        destination: %WebhookDestination{
          url: "https://hooks.example.com/deliveries",
          method: "POST",
          auth: %OAuthAuth{
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-abc-123",
            grant: %ClientCredentialsGrant{
              client_secret: "sk-example-secret",
              scope: "read:events"
            }
          }
        }
      }

      wire = ExOpenApiUtils.Mapper.to_map(ecto_tree)

      assert get_in(wire, ["destination", "destination_type"]) == "webhook"
      assert get_in(wire, ["destination", "auth", "auth_type"]) == "oauth"
      assert get_in(wire, ["destination", "auth", "grant", "grant_type"]) ==
               "client_credentials"
    end
  end

  describe "GH-34 — schema composition introspection" do
    test "WebhookDestinationOAuthRequest is an allOf composition with auto-filled title and x-struct" do
      schema = WebhookDestinationOAuthRequest.schema()

      assert %Schema{allOf: all_of} = schema
      assert length(all_of) == 2

      assert schema."x-struct" == WebhookDestinationOAuthRequest
      assert schema.title == "WebhookDestinationOAuthRequest"
    end

    test "OAuthClientCredentialsGrantRequest has :__type__ unnecessary on defstruct — defstruct only has client_secret + scope + grant_type" do
      # The parent-contextual sibling's defstruct is built from
      # `Schema.properties/1` walking the allOf. The patch schema adds the
      # *wire* discriminator (grant_type) as a first-class field, NOT the
      # Ecto :__type__ atom. :__type__ is stamped on the runtime map by
      # the self-stamp splice, not on the defstruct.
      keys = %OAuthClientCredentialsGrantRequest{} |> Map.from_struct() |> Map.keys()

      assert :client_secret in keys
      assert :scope in keys
      assert :grant_type in keys
      refute :__type__ in keys
    end
  end

  describe "GH-34 — round-trip through wire map → cast → re-serialize" do
    test "wire map cast routes to SubscriptionWebhookDestinationRequest with nested oauth/client_credentials" do
      wire_map = %{
        "name" => "Order events subscription",
        "destination" => %{
          "destination_type" => "webhook",
          "url" => "https://hooks.example.com/deliveries",
          "method" => "POST",
          "auth" => %{
            "auth_type" => "oauth",
            "token_url" => "https://auth.example.com/oauth/token",
            "client_id" => "client-abc-123",
            "grant" => %{
              "grant_type" => "client_credentials",
              "client_secret" => "sk-example-secret",
              "scope" => "read:events"
            }
          }
        }
      }

      assert {:ok, cast_output} = cast_request(wire_map)

      assert %SubscriptionRequest{
               name: "Order events subscription",
               destination: %SubscriptionWebhookDestinationRequest{
                 destination_type: "webhook",
                 url: "https://hooks.example.com/deliveries",
                 method: "POST",
                 auth: %WebhookDestinationOAuthRequest{
                   auth_type: "oauth",
                   grant: %OAuthClientCredentialsGrantRequest{
                     grant_type: "client_credentials"
                   }
                 }
               }
             } = cast_output

      # Now pipe cast output through Mapper.to_map and assert :__type__ is
      # stamped at every polymorphic level — this is the full round-trip
      # that controllers run in practice.
      attrs_map = ExOpenApiUtils.Mapper.to_map(cast_output)

      assert get_in(attrs_map, [:destination, :__type__]) == "webhook"
      assert get_in(attrs_map, [:destination, :auth, :__type__]) == "oauth"

      assert get_in(attrs_map, [:destination, :auth, :grant, :__type__]) ==
               "client_credentials"
    end
  end
end
