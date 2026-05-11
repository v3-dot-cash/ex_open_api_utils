defmodule ExOpenApiUtils.PolymorphicDualEmbedTest do
  @moduledoc """
  GH-47 regression lock: two `open_api_polymorphic_property/1` declarations
  on the same parent backed by the same variant pool must compile cleanly
  (no `redefining module` warning) and route both embed keys through the
  shared parent-contextual sibling correctly.

  See `test/support/polymorphic_discriminator/dual_channel_notification.ex`
  for the fixture.
  """
  use ExUnit.Case, async: true

  alias OpenApiSpex.Cast

  alias ExOpenApiUtilsTest.OpenApiSchema.DualChannelNotificationEmailChannelRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.DualChannelNotificationEmailChannelResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.DualChannelNotificationRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.DualChannelNotificationResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.DualChannelNotificationSmsChannelRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.DualChannelNotificationSmsChannelResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.DualChannelNotificationWebhookChannelRequest

  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.DualChannelNotification
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.SmsChannel

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

  defp cast_request(payload) do
    schemas = resolved_schemas()
    schema = Map.fetch!(schemas, "DualChannelNotificationRequest")
    Cast.cast(schema, payload, schemas)
  end

  describe "parent-contextual sibling generation (GH-47 dedupe)" do
    test "each unique sibling module is generated exactly once and is loadable" do
      for mod <- [
            DualChannelNotificationEmailChannelRequest,
            DualChannelNotificationEmailChannelResponse,
            DualChannelNotificationSmsChannelRequest,
            DualChannelNotificationSmsChannelResponse,
            DualChannelNotificationWebhookChannelRequest
          ] do
        assert Code.ensure_loaded?(mod), "expected #{inspect(mod)} to be defined"
        # OpenApiSpex.schema/1 produces both __struct__/0 and schema/0
        assert function_exported?(mod, :__struct__, 0)
        assert function_exported?(mod, :schema, 0)
      end
    end

    test "both primary_channel and fallback_channel resolve to the same shared sibling oneOf entries" do
      request_schema = DualChannelNotificationRequest.schema()
      primary = request_schema.properties[:primary_channel]
      fallback = request_schema.properties[:fallback_channel]

      assert primary.oneOf == fallback.oneOf
      assert primary.discriminator.mapping == fallback.discriminator.mapping
      assert DualChannelNotificationEmailChannelRequest in primary.oneOf
    end
  end

  describe "round-trip through the shared sibling for both keys" do
    test "primary_channel email payload casts via the shared parent-contextual sibling" do
      payload = %{
        "subject" => "Order shipped",
        "primary_channel" => %{
          "channel_type" => "email",
          "to" => "to@example.com",
          "from" => "from@example.com",
          "body" => "Your order shipped"
        }
      }

      assert {:ok,
              %DualChannelNotificationRequest{
                subject: "Order shipped",
                primary_channel: %DualChannelNotificationEmailChannelRequest{
                  to: "to@example.com",
                  channel_type: "email"
                }
              }} = cast_request(payload)
    end

    test "fallback_channel sms payload casts via the same shared sibling family" do
      payload = %{
        "subject" => "Order shipped",
        "primary_channel" => %{
          "channel_type" => "email",
          "to" => "to@example.com",
          "from" => "from@example.com",
          "body" => "primary"
        },
        "fallback_channel" => %{
          "channel_type" => "sms",
          "phone_number" => "+15551234",
          "body" => "fallback"
        }
      }

      assert {:ok,
              %DualChannelNotificationRequest{
                primary_channel: %DualChannelNotificationEmailChannelRequest{},
                fallback_channel: %DualChannelNotificationSmsChannelRequest{
                  phone_number: "+15551234",
                  channel_type: "sms"
                }
              }} = cast_request(payload)
    end

    test "Mapper.to_map stamps channel_type on both embeds independently" do
      notification = %DualChannelNotification{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        subject: "hi",
        primary_channel: %EmailChannel{to: "a@x", from: "b@x", body: "hello"},
        fallback_channel: %SmsChannel{phone_number: "+15551234", body: "fallback"}
      }

      result = ExOpenApiUtils.Mapper.to_map(notification)

      assert result["primary_channel"]["channel_type"] == "email"
      assert result["primary_channel"]["to"] == "a@x"
      assert result["fallback_channel"]["channel_type"] == "sms"
      assert result["fallback_channel"]["phone_number"] == "+15551234"
    end

    test "request-side Mapper.to_map emits :__type__ for both embeds" do
      request = %DualChannelNotificationRequest{
        subject: "hi",
        primary_channel: %DualChannelNotificationEmailChannelRequest{
          to: "a@x",
          from: "b@x",
          body: "hello"
        },
        fallback_channel: %DualChannelNotificationSmsChannelRequest{
          phone_number: "+15551234",
          body: "fallback"
        }
      }

      result = ExOpenApiUtils.Mapper.to_map(request)
      assert result.primary_channel[:__type__] == "email"
      assert result.fallback_channel[:__type__] == "sms"
    end
  end

  describe "two decls colliding on sibling name with disagreeing bodies (GH-47 raise path)" do
    test "differing open_api_discriminator_property across decls raises a CompileError" do
      code = """
      defmodule Test.PolyDual.DisagreeingDiscriminator do
        use ExOpenApiUtils

        alias ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel
        alias ExOpenApiUtilsTest.PolymorphicDiscriminator.SmsChannel

        import PolymorphicEmbed

        open_api_polymorphic_property(
          key: :primary_channel,
          type_field_name: :__type__,
          open_api_discriminator_property: "channel_type",
          variants: [email: EmailChannel, sms: SmsChannel]
        )

        open_api_polymorphic_property(
          key: :fallback_channel,
          type_field_name: :__type__,
          open_api_discriminator_property: "other_channel_type",
          variants: [email: EmailChannel, sms: SmsChannel]
        )

        @primary_key {:id, :binary_id, autogenerate: true}
        schema "disagreeing_discriminator" do
          field(:subject, :string)

          polymorphic_embeds_one(:primary_channel,
            types: [email: EmailChannel, sms: SmsChannel],
            type_field_name: :__type__,
            on_type_not_found: :raise,
            on_replace: :update
          )

          polymorphic_embeds_one(:fallback_channel,
            types: [email: EmailChannel, sms: SmsChannel],
            type_field_name: :__type__,
            on_type_not_found: :raise,
            on_replace: :update
          )
        end

        open_api_schema(
          title: "DisagreeingDiscriminator",
          description: "x",
          properties: [:primary_channel, :fallback_channel]
        )
      end
      """

      assert_raise CompileError, ~r/both derive parent-contextual sibling/, fn ->
        Code.compile_string(code)
      end
    end
  end
end
