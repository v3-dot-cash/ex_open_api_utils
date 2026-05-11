defmodule PhoenixEctoOpenApiDemo.DualChannelNotificationTest do
  @moduledoc """
  End-to-end lock for GH-47. The `DualChannelNotification` schema declares
  two `open_api_polymorphic_property/1` calls sharing the same variant pool
  (`Email` / `Sms` / `Webhook`). Before the fix, compiling this module under
  `--warnings-as-errors` failed with `redefining module ...` warnings on
  the parent-contextual sibling submodules (and on their derived
  `ExOpenApiUtils.Mapper` impls).

  This test never touches the DB — the regression is purely at compile +
  schema-reflection time, plus a Mapper round-trip to prove the shared
  parent-contextual siblings route both embed keys correctly.
  """
  use ExUnit.Case, async: true

  alias OpenApiSpex.Cast

  alias PhoenixEctoOpenApiDemo.NotificationContext.DualChannelNotification
  alias PhoenixEctoOpenApiDemo.NotificationContext.Email
  alias PhoenixEctoOpenApiDemo.NotificationContext.Sms

  alias PhoenixEctoOpenApiDemo.OpenApiSchema.DualChannelNotificationEmailRequest
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.DualChannelNotificationEmailResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.DualChannelNotificationRequest
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.DualChannelNotificationResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.DualChannelNotificationSmsRequest
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.DualChannelNotificationSmsResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.DualChannelNotificationWebhookRequest
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.DualChannelNotificationWebhookResponse

  defp resolved_schemas do
    empty_spec = %OpenApiSpex.OpenApi{
      info: %OpenApiSpex.Info{title: "test", version: "0"},
      paths: %{},
      components: %OpenApiSpex.Components{schemas: %{}}
    }

    empty_spec
    |> OpenApiSpex.add_schemas([DualChannelNotificationRequest, DualChannelNotificationResponse])
    |> then(& &1.components.schemas)
  end

  describe "GH-47: dedupe parent-contextual siblings across embeds" do
    test "all six (variant × direction) parent-contextual siblings exist exactly once" do
      for mod <- [
            DualChannelNotificationEmailRequest,
            DualChannelNotificationEmailResponse,
            DualChannelNotificationSmsRequest,
            DualChannelNotificationSmsResponse,
            DualChannelNotificationWebhookRequest,
            DualChannelNotificationWebhookResponse
          ] do
        assert Code.ensure_loaded?(mod), "expected #{inspect(mod)} to be defined"
        assert function_exported?(mod, :schema, 0)
      end
    end

    test "primary_channel and fallback_channel point at the same shared sibling family" do
      schema = DualChannelNotificationRequest.schema()
      primary = schema.properties[:primary_channel]
      fallback = schema.properties[:fallback_channel]

      assert primary.oneOf == fallback.oneOf
      assert primary.discriminator.propertyName == "channel_type"
      assert fallback.discriminator.propertyName == "channel_type"
      assert primary.discriminator.mapping == fallback.discriminator.mapping
      assert DualChannelNotificationEmailRequest in primary.oneOf
      assert DualChannelNotificationSmsRequest in primary.oneOf
    end
  end

  describe "round-trip through the shared sibling for both embed keys" do
    test "casts both primary_channel (email) and fallback_channel (sms) on one payload" do
      payload = %{
        "subject" => "Order shipped",
        "primary_channel" => %{
          "channel_type" => "email",
          "to" => "to@example.com",
          "from" => "from@example.com",
          "body" => "Your order shipped"
        },
        "fallback_channel" => %{
          "channel_type" => "sms",
          "phone_number" => "+15551234",
          "body" => "fallback"
        }
      }

      schemas = resolved_schemas()
      schema = Map.fetch!(schemas, "DualChannelNotificationRequest")

      assert {:ok,
              %DualChannelNotificationRequest{
                primary_channel: %DualChannelNotificationEmailRequest{
                  to: "to@example.com",
                  channel_type: "email"
                },
                fallback_channel: %DualChannelNotificationSmsRequest{
                  phone_number: "+15551234",
                  channel_type: "sms"
                }
              }} = Cast.cast(schema, payload, schemas)
    end

    test "Mapper.to_map stamps channel_type independently on both embeds" do
      notification = %DualChannelNotification{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        subject: "Order shipped",
        primary_channel: %Email{to: "a@x", from: "b@x", body: "primary"},
        fallback_channel: %Sms{phone_number: "+15551234", body: "fallback"}
      }

      result = ExOpenApiUtils.Mapper.to_map(notification)

      assert result["primary_channel"]["channel_type"] == "email"
      assert result["primary_channel"]["to"] == "a@x"
      assert result["fallback_channel"]["channel_type"] == "sms"
      assert result["fallback_channel"]["phone_number"] == "+15551234"
    end
  end
end
