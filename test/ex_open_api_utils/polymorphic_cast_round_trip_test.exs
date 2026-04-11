defmodule ExOpenApiUtils.PolymorphicCastRoundTripTest do
  @moduledoc """
  GH-30 regression lock: the round-trip cast of a polymorphic response body
  must preserve the wire discriminator on the typed variant struct.

  Before the fix (0.13.1 behaviour): `OpenApiSpex.Cast.cast/4` routes the body
  through the parent's oneOf + discriminator, re-casts against the variant
  submodule (e.g. `EmailChannelResponse`), and the resulting typed struct has
  no `:channel_type` field because the variant submodule's defstruct was built
  from the variant's own `open_api_property` list without the discriminator.
  The single drop point is `Kernel.struct/2` inside `to_struct/1` at
  `deps/open_api_spex/lib/open_api_spex/cast/object.ex:204`.

  After the fix: the library generates a parent-contextual sibling submodule
  per (parent, variant, direction) triple — e.g.
  `NotificationEmailChannelResponse` — whose schema composes the original
  variant's schema with an inline discriminator patch via `allOf`.
  `OpenApiSpex.schema/1`'s defstruct generator walks the allOf via
  `Schema.properties/1` and includes the discriminator as a real field, so
  `Kernel.struct/2` keeps it and the round-trip is lossless.
  """
  use ExUnit.Case, async: true

  alias OpenApiSpex.Cast
  alias OpenApiSpex.Schema

  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Analytics
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.ClickEvent
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Notification
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.SmsChannel
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.WebhookChannel

  alias ExOpenApiUtilsTest.OpenApiSchema.AnalyticsRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.AnalyticsResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.NotificationRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.NotificationResponse

  # Parent-contextual sibling submodules — these are NEW after the GH-30 fix.
  # Before the fix they do not exist and tests referencing them fail with
  # `UndefinedFunctionError` at call time.  This is the red half of TDD.
  alias ExOpenApiUtilsTest.OpenApiSchema.AnalyticsClickEventResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.NotificationEmailChannelResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.NotificationSmsChannelResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.NotificationWebhookChannelResponse

  defp resolved_schemas do
    empty_spec = %OpenApiSpex.OpenApi{
      info: %OpenApiSpex.Info{title: "test", version: "0"},
      paths: %{},
      components: %OpenApiSpex.Components{schemas: %{}}
    }

    empty_spec
    |> OpenApiSpex.add_schemas([
      NotificationRequest,
      NotificationResponse,
      AnalyticsRequest,
      AnalyticsResponse
    ])
    |> then(& &1.components.schemas)
  end

  defp cast_response(wire_map, schema_title) do
    schemas = resolved_schemas()
    schema = Map.fetch!(schemas, schema_title)
    Cast.cast(schema, wire_map, schemas, read_write_scope: :read)
  end

  describe "GH-30 round-trip — Notification.channel preserves the discriminator on the variant struct" do
    test "baseline — cast output's :channel is the new parent-contextual sibling type (Phase 2c updates this from the pre-fix EmailChannelResponse)" do
      notification = %Notification{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        subject: "Your order has shipped",
        channel: %EmailChannel{
          to: "buyer@example.com",
          from: "store@example.com",
          body: "Tracking: 1Z999AA10123456784"
        }
      }

      wire = ExOpenApiUtils.Mapper.to_map(notification)
      assert get_in(wire, ["channel", "channel_type"]) == "email"

      assert {:ok, cast_output} = cast_response(wire, "NotificationResponse")

      assert %NotificationResponse{channel: %NotificationEmailChannelResponse{}} = cast_output
    end

    test "lossless round-trip via NotificationEmailChannelResponse (main regression lock)" do
      notification = %Notification{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        subject: "Your order has shipped",
        channel: %EmailChannel{
          to: "buyer@example.com",
          from: "store@example.com",
          body: "Tracking: 1Z999AA10123456784"
        }
      }

      wire = ExOpenApiUtils.Mapper.to_map(notification)
      assert {:ok, cast_output} = cast_response(wire, "NotificationResponse")

      assert %NotificationResponse{
               channel: %NotificationEmailChannelResponse{
                 to: "buyer@example.com",
                 from: "store@example.com",
                 body: "Tracking: 1Z999AA10123456784",
                 channel_type: "email"
               }
             } = cast_output

      assert Map.get(cast_output.channel, :channel_type) == "email"

      # Full lossless round-trip: mirror the ApiHelpers.to_api_map/2
      # production flow (Mapper.to_map |> cast_to_schema) on the response
      # struct and re-cast. Exercises (a) the parent-contextual sibling's
      # own Mapper derive (converts the sibling struct to a plain map),
      # and (b) OpenApiSpex's Cast.Discriminator routing through the
      # re-cast pipeline. The final re_cast must produce the same typed
      # struct shape as the first cast — discriminator preserved on both
      # hops.
      re_serialized = ExOpenApiUtils.Mapper.to_map(cast_output)
      assert {:ok, re_cast} = cast_response(re_serialized, "NotificationResponse")

      assert %NotificationResponse{
               channel: %NotificationEmailChannelResponse{
                 to: "buyer@example.com",
                 from: "store@example.com",
                 body: "Tracking: 1Z999AA10123456784",
                 channel_type: "email"
               }
             } = re_cast
    end

    test "sms variant round-trip via NotificationSmsChannelResponse" do
      notification = %Notification{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        subject: "Verification code",
        channel: %SmsChannel{
          phone_number: "+15551234567",
          body: "Your code is 4242"
        }
      }

      wire = ExOpenApiUtils.Mapper.to_map(notification)
      assert {:ok, cast_output} = cast_response(wire, "NotificationResponse")

      assert %NotificationResponse{
               channel: %NotificationSmsChannelResponse{
                 phone_number: "+15551234567",
                 body: "Your code is 4242",
                 channel_type: "sms"
               }
             } = cast_output
    end

    test "webhook variant round-trip via NotificationWebhookChannelResponse" do
      notification = %Notification{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        subject: "Order event",
        channel: %WebhookChannel{
          url: "https://hooks.example.com/abc",
          method: "POST"
        }
      }

      wire = ExOpenApiUtils.Mapper.to_map(notification)
      assert {:ok, cast_output} = cast_response(wire, "NotificationResponse")

      assert %NotificationResponse{
               channel: %NotificationWebhookChannelResponse{
                 url: "https://hooks.example.com/abc",
                 method: "POST",
                 channel_type: "webhook"
               }
             } = cast_output
    end

    test "NotificationEmailChannelResponse has :channel_type as a real defstruct field" do
      keys = %NotificationEmailChannelResponse{} |> Map.from_struct() |> Map.keys()
      assert :channel_type in keys
      assert :to in keys
      assert :from in keys
      assert :body in keys
    end

    test "NotificationEmailChannelResponse.schema/0 is an allOf composition with auto-filled title and x-struct" do
      schema = NotificationEmailChannelResponse.schema()

      assert %Schema{allOf: all_of} = schema
      assert length(all_of) == 2

      # Auto-filled by OpenApiSpex.build_schema/2 from opts[:module] (which is
      # NotificationEmailChannelResponse at macro-expansion time inside the
      # library's Module.create quote block).
      assert schema."x-struct" == NotificationEmailChannelResponse
      # Auto-filled by title_from_module/1 from the last segment of the flat
      # module name.
      assert schema.title == "NotificationEmailChannelResponse"
    end

    test "the original EmailChannelResponse sibling is still untouched and usable standalone" do
      # The non-parent-contextual submodule that SNS / EmailChannel generate
      # via their own __before_compile__ stays exactly as it is today — the
      # library fix only adds new parent-contextual siblings.
      keys = %EmailChannelResponse{} |> Map.from_struct() |> Map.keys()
      assert :to in keys
      assert :from in keys
      assert :body in keys
      # And crucially — no discriminator leaked into the standalone variant's
      # defstruct.  The discriminator lives on the parent-contextual sibling
      # only.
      refute :channel_type in keys
    end
  end

  describe "GH-30 round-trip — Analytics.event (cross-name bridge: wire 'kind' vs Ecto :event_type)" do
    test "click variant round-trip via AnalyticsClickEventResponse preserves the 'kind' wire value" do
      analytics = %Analytics{
        id: "11111111-1111-1111-1111-111111111111",
        user_id: "22222222-2222-2222-2222-222222222222",
        event: %ClickEvent{selector: "#submit-btn"}
      }

      wire = ExOpenApiUtils.Mapper.to_map(analytics)
      assert get_in(wire, ["event", "kind"]) == "click"

      assert {:ok, cast_output} = cast_response(wire, "AnalyticsResponse")

      assert %AnalyticsResponse{
               event: %AnalyticsClickEventResponse{
                 selector: "#submit-btn",
                 kind: "click"
               }
             } = cast_output
    end
  end
end
