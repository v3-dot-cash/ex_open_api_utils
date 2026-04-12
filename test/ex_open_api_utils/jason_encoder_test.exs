defmodule ExOpenApiUtils.JasonEncoderTest do
  @moduledoc """
  GH-41 — generated Request, Response, and parent-contextual sibling modules
  get an explicit `defimpl Jason.Encoder` that applies nil-stripping via
  `Mapper.Utils.nil_aware_put/4` and passes the result to `Jason.Encode.map/2`.
  """
  use ExUnit.Case, async: true

  alias ExOpenApiUtilsTest.OpenApiSchema.NilStrippingSchemaRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.NilStrippingSchemaResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.NotificationEmailChannelRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.OAuthClientCredentialsGrantRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.SubscriptionEmailDestinationRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.SubscriptionRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.SubscriptionWebhookDestinationRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.WebhookDestinationOAuthRequest

  describe "GH-41 — nil-stripping via Jason.encode!" do
    test "Request struct: optional non-nullable nil fields are omitted" do
      # :id is readOnly so not on Request; only on Response
      request = %NilStrippingSchemaRequest{
        name: "Test",
        nickname: nil,
        region: nil,
        base_path: nil,
        tags: nil,
        active: nil,
        notes: nil,
        description: nil
      }

      decoded = request |> Jason.encode!() |> Jason.decode!()

      # required non-nullable — always present
      assert decoded["name"] == "Test"

      # required nullable — present with null
      assert Map.has_key?(decoded, "nickname")
      assert decoded["nickname"] == nil

      # optional non-nullable nil — omitted
      refute Map.has_key?(decoded, "region")
      refute Map.has_key?(decoded, "base_path")
      refute Map.has_key?(decoded, "tags")
      refute Map.has_key?(decoded, "active")

      # optional nullable nil — present with null
      assert Map.has_key?(decoded, "notes")
      assert decoded["notes"] == nil
      assert Map.has_key?(decoded, "description")
      assert decoded["description"] == nil
    end

    test "Response struct: same nil-stripping semantics including readOnly fields" do
      response = %NilStrippingSchemaResponse{
        id: "abc-123",
        name: "Test",
        nickname: nil,
        region: "us-west-2",
        base_path: nil,
        tags: nil,
        active: nil,
        notes: "some notes",
        description: nil
      }

      decoded = response |> Jason.encode!() |> Jason.decode!()

      assert decoded["id"] == "abc-123"
      assert decoded["region"] == "us-west-2"
      assert decoded["notes"] == "some notes"

      # optional non-nullable nil — omitted
      refute Map.has_key?(decoded, "base_path")
      refute Map.has_key?(decoded, "tags")
      refute Map.has_key?(decoded, "active")

      # optional nullable nil — present
      assert Map.has_key?(decoded, "description")
      assert decoded["description"] == nil
    end

    test "non-nil values always emitted regardless of nullable" do
      request = %NilStrippingSchemaRequest{
        name: "Test",
        nickname: "Nick",
        region: "us-east-1",
        base_path: "/data",
        tags: ["a", "b"],
        active: false,
        notes: "note",
        description: "desc"
      }

      decoded = request |> Jason.encode!() |> Jason.decode!()

      assert decoded["nickname"] == "Nick"
      assert decoded["region"] == "us-east-1"
      assert decoded["base_path"] == "/data"
      assert decoded["tags"] == ["a", "b"]
      assert decoded["active"] == false
      assert decoded["notes"] == "note"
      assert decoded["description"] == "desc"
    end
  end

  describe "GH-41 — parent-contextual sibling encoding" do
    test "sibling struct includes discriminator in JSON output" do
      sibling = %NotificationEmailChannelRequest{
        channel_type: "email",
        to: "buyer@example.com",
        from: "store@example.com",
        body: "thanks"
      }

      decoded = sibling |> Jason.encode!() |> Jason.decode!()

      assert decoded["channel_type"] == "email"
      assert decoded["to"] == "buyer@example.com"
      assert decoded["from"] == "store@example.com"
      assert decoded["body"] == "thanks"
    end
  end

  describe "GH-41 — nested polymorphic encoding" do
    test "3-level nested subscription encodes discriminators at every level" do
      request = %SubscriptionRequest{
        name: "Order events",
        destination: %SubscriptionWebhookDestinationRequest{
          destination_type: "webhook",
          url: "https://hooks.example.com/orders",
          method: "POST",
          retry_after: nil,
          auth: %WebhookDestinationOAuthRequest{
            auth_type: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-abc",
            grant: %OAuthClientCredentialsGrantRequest{
              grant_type: "client_credentials",
              client_secret: "sk-secret",
              scope: "read:events"
            }
          }
        }
      }

      decoded = request |> Jason.encode!() |> Jason.decode!()

      assert decoded["name"] == "Order events"

      dest = decoded["destination"]
      assert dest["destination_type"] == "webhook"
      assert dest["url"] == "https://hooks.example.com/orders"
      assert dest["method"] == "POST"

      # required nullable nil — present
      assert Map.has_key?(dest, "retry_after")
      assert dest["retry_after"] == nil

      # optional non-nullable nil — omitted
      refute Map.has_key?(dest, "timeout_ms")

      auth = dest["auth"]
      assert auth["auth_type"] == "oauth"
      assert auth["token_url"] == "https://auth.example.com/oauth/token"

      grant = auth["grant"]
      assert grant["grant_type"] == "client_credentials"
      assert grant["client_secret"] == "sk-secret"
      assert grant["scope"] == "read:events"
    end

    test "nil-stripping at nested level — scope absent when nil" do
      request = %SubscriptionRequest{
        name: "Minimal",
        destination: %SubscriptionWebhookDestinationRequest{
          destination_type: "webhook",
          url: "https://hooks.example.com/min",
          method: "POST",
          retry_after: "30",
          auth: %WebhookDestinationOAuthRequest{
            auth_type: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-min",
            grant: %OAuthClientCredentialsGrantRequest{
              grant_type: "client_credentials",
              client_secret: "sk-min"
            }
          }
        }
      }

      decoded = request |> Jason.encode!() |> Jason.decode!()
      grant = decoded["destination"]["auth"]["grant"]

      refute Map.has_key?(grant, "scope")
      assert grant["grant_type"] == "client_credentials"
      assert grant["client_secret"] == "sk-min"
    end

    test "flat email destination encodes cleanly" do
      request = %SubscriptionRequest{
        name: "Ops digest",
        destination: %SubscriptionEmailDestinationRequest{
          destination_type: "email",
          recipient: "ops@example.com"
        }
      }

      decoded = request |> Jason.encode!() |> Jason.decode!()

      assert decoded["destination"]["destination_type"] == "email"
      assert decoded["destination"]["recipient"] == "ops@example.com"
    end
  end

  describe "GH-41 — idempotency with Mapper.to_map" do
    test "Jason.encode!(struct) == Jason.encode!(Mapper.to_map(struct)) for flat request" do
      request = %NilStrippingSchemaRequest{
        name: "Test",
        nickname: nil,
        region: "us-west-2",
        base_path: nil,
        notes: nil
      }

      via_encoder = request |> Jason.encode!() |> Jason.decode!()
      via_mapper = request |> ExOpenApiUtils.Mapper.to_map() |> Jason.encode!() |> Jason.decode!()

      assert via_encoder == via_mapper
    end

    test "Jason.encode!(struct) matches Mapper.to_map(struct) minus :__type__ for nested polymorphic" do
      request = %SubscriptionRequest{
        name: "Roundtrip",
        destination: %SubscriptionWebhookDestinationRequest{
          destination_type: "webhook",
          url: "https://hooks.example.com/rt",
          method: "POST",
          retry_after: nil,
          auth: %WebhookDestinationOAuthRequest{
            auth_type: "oauth",
            token_url: "https://auth.example.com/oauth/token",
            client_id: "client-rt",
            grant: %OAuthClientCredentialsGrantRequest{
              grant_type: "client_credentials",
              client_secret: "sk-rt",
              scope: "read:events"
            }
          }
        }
      }

      via_encoder = request |> Jason.encode!() |> Jason.decode!()
      via_mapper = request |> ExOpenApiUtils.Mapper.to_map() |> Jason.encode!() |> Jason.decode!()

      # Mapper.to_map adds :__type__ at every polymorphic level for Ecto's
      # cast_polymorphic_embed — that's correct for the Mapper's purpose but
      # doesn't belong in wire JSON. The Jason encoder only outputs
      # property_attrs fields, so __type__ is correctly absent.
      assert via_encoder == strip_type_keys(via_mapper)
    end
  end

  defp strip_type_keys(map) when is_map(map) do
    map
    |> Map.delete("__type__")
    |> Map.new(fn {k, v} -> {k, strip_type_keys(v)} end)
  end

  defp strip_type_keys(val), do: val
end
