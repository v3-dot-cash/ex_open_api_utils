defmodule ExOpenApiUtils.PolymorphicDiscriminatorTest do
  @moduledoc """
  End-to-end coverage for the `polymorphic_embed_discriminator/1` macro plus
  the surrounding `__before_compile__` consistency checks and runtime Mapper
  injection.

  Closes GH-21 (focused cast errors via `oneOf + discriminator` dispatch gate)
  and GH-24 (runtime round-trip via Mapper-side discriminator injection).
  """
  use ExUnit.Case, async: true

  alias OpenApiSpex.Cast
  alias OpenApiSpex.Discriminator
  alias OpenApiSpex.Schema

  alias ExOpenApiUtilsTest.OpenApiSchema.EmailChannelRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.NotificationRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.NotificationResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.SmsChannelRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.SmsChannelResponse
  alias ExOpenApiUtilsTest.OpenApiSchema.WebhookChannelRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.WebhookChannelResponse

  alias ExOpenApiUtilsTest.OpenApiSchema.AnalyticsRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.ClickEventRequest

  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Analytics
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.ClickEvent
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.Notification
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.PageViewEvent
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.SmsChannel
  alias ExOpenApiUtilsTest.PolymorphicDiscriminator.WebhookChannel

  # Pre-resolve the fixture schemas so we can drive OpenApiSpex.Cast.cast
  # directly. In the full Phoenix flow, OpenApiSpex.Plug.CastAndValidate runs
  # schema resolution before casting, which hoists every module reachable
  # from oneOf / discriminator.mapping into components.schemas and replaces
  # the module refs with %Reference{} structs. The library tests short-
  # circuit the Plug but still need normalized schemas. add_schemas/2 is the
  # public entry point for "resolve this list of modules into components";
  # starting from an empty components.schemas and feeding the request/response
  # modules in avoids the self-referential Reference loop that happens if
  # you pre-seed components.schemas with module atoms.
  defp resolved_schemas do
    empty_spec = %OpenApiSpex.OpenApi{
      info: %OpenApiSpex.Info{title: "test", version: "0"},
      paths: %{},
      components: %OpenApiSpex.Components{schemas: %{}}
    }

    empty_spec
    |> OpenApiSpex.add_schemas([NotificationRequest, NotificationResponse, AnalyticsRequest])
    |> then(& &1.components.schemas)
  end

  defp cast_request(payload, schema_title \\ "NotificationRequest") do
    schemas = resolved_schemas()
    schema = Map.fetch!(schemas, schema_title)
    Cast.cast(schema, payload, schemas)
  end

  # ------------------------------------------------------------------
  # 1. Spec generation — Request and Response submodules
  # ------------------------------------------------------------------

  describe "NotificationRequest schema (GH-21 spec half)" do
    setup do
      schema = NotificationRequest.schema()
      {:ok, schema: schema, channel: schema.properties[:channel]}
    end

    test "top-level wrapper is type :object", %{schema: schema} do
      assert schema.type == :object
      assert schema.title == "NotificationRequest"
    end

    test ":channel property has type :object (dispatch gate)", %{channel: channel} do
      assert %Schema{type: :object} = channel
    end

    test ":channel has writeOnly set (direction marker)", %{channel: channel} do
      assert channel.writeOnly == true
    end

    test ":channel oneOf references *Request submodules", %{channel: channel} do
      assert channel.oneOf == [EmailChannelRequest, SmsChannelRequest, WebhookChannelRequest]
    end

    test ":channel discriminator uses object_type with module-valued mapping", %{
      channel: channel
    } do
      assert %Discriminator{propertyName: "object_type", mapping: mapping} = channel.discriminator

      assert mapping == %{
               "email" => EmailChannelRequest,
               "sms" => SmsChannelRequest,
               "webhook" => WebhookChannelRequest
             }
    end

    test ":id is excluded from the Request submodule (readOnly)", %{schema: schema} do
      refute Map.has_key?(schema.properties, :id)
    end
  end

  describe "NotificationResponse schema" do
    setup do
      schema = NotificationResponse.schema()
      {:ok, schema: schema, channel: schema.properties[:channel]}
    end

    test "top-level wrapper is type :object and readOnly", %{schema: schema} do
      assert schema.type == :object
      assert schema.readOnly == true
      assert schema.title == "NotificationResponse"
    end

    test ":channel oneOf references *Response submodules", %{channel: channel} do
      assert channel.oneOf == [
               EmailChannelResponse,
               SmsChannelResponse,
               WebhookChannelResponse
             ]
    end

    test ":channel discriminator mapping uses *Response submodules", %{channel: channel} do
      assert %Discriminator{propertyName: "object_type", mapping: mapping} = channel.discriminator

      assert mapping == %{
               "email" => EmailChannelResponse,
               "sms" => SmsChannelResponse,
               "webhook" => WebhookChannelResponse
             }
    end

    test ":id is included in the Response submodule", %{schema: schema} do
      assert Map.has_key?(schema.properties, :id)
    end
  end

  # ------------------------------------------------------------------
  # 2. GH-21 regression lock — focused cast errors
  # ------------------------------------------------------------------

  describe "focused cast errors (GH-21 regression lock)" do
    test "valid email payload casts to %EmailChannelRequest{}" do
      payload = %{
        "subject" => "Your receipt",
        "channel" => %{
          "object_type" => "email",
          "to" => "buyer@example.com",
          "from" => "store@example.com",
          "body" => "thanks"
        }
      }

      assert {:ok, %NotificationRequest{channel: %EmailChannelRequest{} = c}} =
               cast_request(payload)

      assert c.to == "buyer@example.com"
      assert c.from == "store@example.com"
      assert c.body == "thanks"
    end

    test "valid sms payload casts to %SmsChannelRequest{}" do
      payload = %{
        "subject" => "Code",
        "channel" => %{
          "object_type" => "sms",
          "phone_number" => "+15551234567",
          "body" => "4242"
        }
      }

      assert {:ok, %NotificationRequest{channel: %SmsChannelRequest{}}} =
               cast_request(payload)
    end

    test "valid webhook payload casts to %WebhookChannelRequest{}" do
      payload = %{
        "subject" => "Event",
        "channel" => %{
          "object_type" => "webhook",
          "url" => "https://hooks.example.com/123",
          "method" => "POST"
        }
      }

      assert {:ok, %NotificationRequest{channel: %WebhookChannelRequest{}}} =
               cast_request(payload)
    end

    test "missing discriminator returns :no_value_for_discriminator" do
      payload = %{"subject" => "x", "channel" => %{"to" => "a@b.com"}}

      assert {:error, [error]} = cast_request(payload)
      assert error.reason == :no_value_for_discriminator
      assert error.name == "object_type"
    end

    test "unknown discriminator value returns :invalid_discriminator_value" do
      payload = %{"subject" => "x", "channel" => %{"object_type" => "carrier_pigeon"}}

      assert {:error, [error]} = cast_request(payload)
      assert error.reason == :invalid_discriminator_value
    end

    test "valid type with missing fields yields focused :missing_field (not :one_of wall)" do
      payload = %{"subject" => "x", "channel" => %{"object_type" => "email", "body" => "hi"}}

      assert {:error, errors} = cast_request(payload)

      assert Enum.all?(errors, fn e ->
               match?([:channel, _], e.path) and e.reason == :missing_field
             end)

      missing = errors |> Enum.map(& &1.name) |> MapSet.new()
      assert MapSet.subset?(MapSet.new([:to, :from]), missing)

      refute Enum.any?(errors, &(&1.name in [:phone_number, :url, :method]))
    end

    test "empty discriminator string returns :no_value_for_discriminator" do
      payload = %{"subject" => "x", "channel" => %{"object_type" => ""}}

      assert {:error, [error]} = cast_request(payload)
      assert error.reason == :no_value_for_discriminator
    end
  end

  # ------------------------------------------------------------------
  # 3. Mapper :from_ecto (outbound, response path)
  # ------------------------------------------------------------------

  describe "Mapper outbound injection (:from_ecto)" do
    test "emits string key \"object_type\" for %EmailChannel{}" do
      notification = %Notification{
        id: "851b18d7-0c88-4095-9969-cbe385926420",
        subject: "hi",
        channel: %EmailChannel{to: "a@x", from: "b@x", body: "hello"}
      }

      assert %{
               "id" => "851b18d7-0c88-4095-9969-cbe385926420",
               "subject" => "hi",
               "channel" => channel
             } = ExOpenApiUtils.Mapper.to_map(notification)

      assert channel["object_type"] == "email"
      assert channel["to"] == "a@x"
      assert channel["from"] == "b@x"
      assert channel["body"] == "hello"
    end

    test "emits \"sms\" for %SmsChannel{}" do
      notification = %Notification{
        subject: "code",
        channel: %SmsChannel{phone_number: "+1555", body: "4242"}
      }

      assert %{"channel" => %{"object_type" => "sms"}} =
               ExOpenApiUtils.Mapper.to_map(notification)
    end

    test "emits \"webhook\" for %WebhookChannel{}" do
      notification = %Notification{
        subject: "event",
        channel: %WebhookChannel{url: "https://hooks.example.com/abc", method: "POST"}
      }

      assert %{"channel" => %{"object_type" => "webhook"}} =
               ExOpenApiUtils.Mapper.to_map(notification)
    end

    test "variant's own Mapper.to_map/1 output contains NO discriminator" do
      email_map = ExOpenApiUtils.Mapper.to_map(%EmailChannel{to: "a", from: "b", body: "c"})
      refute Map.has_key?(email_map, "object_type")

      sms_map = ExOpenApiUtils.Mapper.to_map(%SmsChannel{phone_number: "+1", body: "c"})
      refute Map.has_key?(sms_map, "object_type")

      webhook_map = ExOpenApiUtils.Mapper.to_map(%WebhookChannel{url: "u", method: "GET"})
      refute Map.has_key?(webhook_map, "object_type")
    end

    test "nil channel leaves the map unchanged (no injection)" do
      notification = %Notification{subject: "none", channel: nil}
      result = ExOpenApiUtils.Mapper.to_map(notification)
      assert result["channel"] == nil
    end
  end

  # ------------------------------------------------------------------
  # 4. Mapper :from_open_api (inbound, request path)
  # ------------------------------------------------------------------

  describe "Mapper inbound injection (:from_open_api)" do
    test "emits atom key :__type__ for %EmailChannelRequest{}" do
      request = %NotificationRequest{
        subject: "hi",
        channel: %EmailChannelRequest{to: "a@x", from: "b@x", body: "hello"}
      }

      assert %{subject: "hi", channel: channel} = ExOpenApiUtils.Mapper.to_map(request)
      assert channel[:__type__] == "email"
      assert channel[:to] == "a@x"
    end

    test "emits :__type__ for %SmsChannelRequest{}" do
      request = %NotificationRequest{
        subject: "code",
        channel: %SmsChannelRequest{phone_number: "+1555", body: "4242"}
      }

      assert %{channel: %{__type__: "sms"}} = ExOpenApiUtils.Mapper.to_map(request)
    end

    test "emits :__type__ for %WebhookChannelRequest{}" do
      request = %NotificationRequest{
        subject: "event",
        channel: %WebhookChannelRequest{url: "https://hooks.example.com/abc", method: "POST"}
      }

      assert %{channel: %{__type__: "webhook"}} = ExOpenApiUtils.Mapper.to_map(request)
    end

    test "variant's own request Mapper output contains NO discriminator" do
      result = ExOpenApiUtils.Mapper.to_map(%EmailChannelRequest{to: "a", from: "b", body: "c"})
      refute Map.has_key?(result, :__type__)
      refute Map.has_key?(result, "__type__")
    end
  end

  # ------------------------------------------------------------------
  # 5. GH-24 regression lock — full round-trip
  # ------------------------------------------------------------------

  describe "full round-trip (GH-24 regression lock)" do
    test "email: wire JSON -> Cast -> shadowed cast -> %EmailChannel{}" do
      payload = %{
        "subject" => "Receipt",
        "channel" => %{
          "object_type" => "email",
          "to" => "buyer@example.com",
          "from" => "store@example.com",
          "body" => "thanks"
        }
      }

      assert {:ok, %NotificationRequest{} = request} =
               cast_request(payload)

      changeset = Notification.changeset(%Notification{}, request)
      assert changeset.valid?
      assert %EmailChannel{to: "buyer@example.com"} = Ecto.Changeset.get_change(changeset, :channel)
    end

    test "sms: wire JSON -> Cast -> shadowed cast -> %SmsChannel{}" do
      payload = %{
        "subject" => "Code",
        "channel" => %{
          "object_type" => "sms",
          "phone_number" => "+15551234567",
          "body" => "4242"
        }
      }

      assert {:ok, request} = cast_request(payload)
      changeset = Notification.changeset(%Notification{}, request)
      assert changeset.valid?
      assert %SmsChannel{phone_number: "+15551234567"} =
               Ecto.Changeset.get_change(changeset, :channel)
    end

    test "webhook: wire JSON -> Cast -> shadowed cast -> %WebhookChannel{}" do
      payload = %{
        "subject" => "Event",
        "channel" => %{
          "object_type" => "webhook",
          "url" => "https://hooks.example.com/123",
          "method" => "POST"
        }
      }

      assert {:ok, request} = cast_request(payload)
      changeset = Notification.changeset(%Notification{}, request)
      assert changeset.valid?
      assert %WebhookChannel{method: "POST"} = Ecto.Changeset.get_change(changeset, :channel)
    end
  end

  # ------------------------------------------------------------------
  # 6. Cross-name bridge (discriminator propertyName != type_field_name)
  # ------------------------------------------------------------------

  describe "cross-name bridge (propertyName \"kind\" vs type_field_name :event_type)" do
    test "AnalyticsRequest schema uses \"kind\" as the wire discriminator" do
      channel = AnalyticsRequest.schema().properties[:event]
      assert channel.discriminator.propertyName == "kind"
    end

    test "outbound emits \"kind\" (wire) for %ClickEvent{}" do
      analytics = %Analytics{
        user_id: "851b18d7-0c88-4095-9969-cbe385926420",
        event: %ClickEvent{selector: "#submit-btn"}
      }

      assert %{"event" => event_map} = ExOpenApiUtils.Mapper.to_map(analytics)
      assert event_map["kind"] == "click"
      refute Map.has_key?(event_map, "event_type")
    end

    test "inbound emits :event_type (atom, Ecto-side) for %ClickEventRequest{}" do
      request = %AnalyticsRequest{
        user_id: "851b18d7-0c88-4095-9969-cbe385926420",
        event: %ClickEventRequest{selector: "#submit"}
      }

      assert %{event: event_map} = ExOpenApiUtils.Mapper.to_map(request)
      assert event_map[:event_type] == "click"
      refute Map.has_key?(event_map, :kind)
    end

    test "full round-trip dispatches via Ecto-side type_field_name" do
      payload = %{
        "user_id" => "851b18d7-0c88-4095-9969-cbe385926420",
        "event" => %{"kind" => "click", "selector" => "#submit"}
      }

      assert {:ok, request} = cast_request(payload, "AnalyticsRequest")
      changeset = Analytics.changeset(%Analytics{}, request)
      assert changeset.valid?
      assert %ClickEvent{selector: "#submit"} = Ecto.Changeset.get_change(changeset, :event)
    end

    test "pageview variant round-trips" do
      payload = %{
        "user_id" => "851b18d7-0c88-4095-9969-cbe385926420",
        "event" => %{"kind" => "pageview", "url" => "https://example.com/"}
      }

      assert {:ok, request} = cast_request(payload, "AnalyticsRequest")
      changeset = Analytics.changeset(%Analytics{}, request)
      assert changeset.valid?
      assert %PageViewEvent{url: "https://example.com/"} =
               Ecto.Changeset.get_change(changeset, :event)
    end

    test "invalid discriminator on cross-named field still surfaces \"kind\"" do
      payload = %{
        "user_id" => "851b18d7-0c88-4095-9969-cbe385926420",
        "event" => %{"kind" => "nope"}
      }

      assert {:error, [error]} = cast_request(payload, "AnalyticsRequest")
      assert error.reason == :invalid_discriminator_value
      assert error.name == "kind"
    end
  end

  # ------------------------------------------------------------------
  # 7. Reflection helper
  # ------------------------------------------------------------------

  describe "__ex_open_api_utils_schemas__/0 reflection helper" do
    test "parent Notification exposes its own schema index" do
      assert [%{title: "Notification", request_module: req, response_module: res}] =
               Notification.__ex_open_api_utils_schemas__()

      assert req == NotificationRequest
      assert res == NotificationResponse
    end

    test "each variant exposes its own schema index" do
      assert [%{title: "EmailChannel"}] = EmailChannel.__ex_open_api_utils_schemas__()
      assert [%{title: "SmsChannel"}] = SmsChannel.__ex_open_api_utils_schemas__()
      assert [%{title: "WebhookChannel"}] = WebhookChannel.__ex_open_api_utils_schemas__()
    end
  end

  # ------------------------------------------------------------------
  # 8. Compile-time consistency checks
  # ------------------------------------------------------------------

  describe "compile-time consistency checks" do
    test "missing polymorphic_embeds_one field raises" do
      code = """
      defmodule Test.PolyCheck.Missing do
        use ExOpenApiUtils
        alias OpenApiSpex.Discriminator

        open_api_property(
          key: :channel,
          schema: %Schema{
            type: :object,
            writeOnly: true,
            oneOf: [ExOpenApiUtilsTest.OpenApiSchema.EmailChannelRequest],
            discriminator: %Discriminator{
              propertyName: "object_type",
              mapping: %{"email" => ExOpenApiUtilsTest.OpenApiSchema.EmailChannelRequest}
            }
          }
        )

        open_api_property(
          key: :channel,
          schema: %Schema{
            type: :object,
            readOnly: true,
            oneOf: [ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse],
            discriminator: %Discriminator{
              propertyName: "object_type",
              mapping: %{"email" => ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse}
            }
          }
        )

        polymorphic_embed_discriminator(key: :channel, type_field_name: :__type__)

        @primary_key {:id, :binary_id, autogenerate: true}
        schema "missing_polymorphic_embed" do
          field :subject, :string
        end

        open_api_schema(title: "MissingPoly", description: "x", properties: [:channel])
      end
      """

      assert_raise CompileError, ~r/no matching polymorphic_embeds_one :channel/, fn ->
        Code.compile_string(code)
      end
    end

    test "missing writeOnly open_api_property raises" do
      code = """
      defmodule Test.PolyCheck.NoWrite do
        use ExOpenApiUtils
        alias OpenApiSpex.Discriminator

        open_api_property(
          key: :channel,
          schema: %Schema{
            type: :object,
            readOnly: true,
            oneOf: [ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse],
            discriminator: %Discriminator{
              propertyName: "object_type",
              mapping: %{"email" => ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse}
            }
          }
        )

        polymorphic_embed_discriminator(key: :channel, type_field_name: :__type__)

        import PolymorphicEmbed

        @primary_key {:id, :binary_id, autogenerate: true}
        schema "no_write_polymorphic_embed" do
          polymorphic_embeds_one :channel,
            types: [email: ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel],
            type_field_name: :__type__,
            on_type_not_found: :raise,
            on_replace: :update
        end

        open_api_schema(title: "NoWrite", description: "x", properties: [:channel])
      end
      """

      assert_raise CompileError, ~r/requires a writeOnly open_api_property/, fn ->
        Code.compile_string(code)
      end
    end

    test "type_field_name mismatch raises" do
      code = """
      defmodule Test.PolyCheck.TypeFieldMismatch do
        use ExOpenApiUtils
        alias OpenApiSpex.Discriminator

        open_api_property(
          key: :channel,
          schema: %Schema{
            type: :object,
            writeOnly: true,
            oneOf: [ExOpenApiUtilsTest.OpenApiSchema.EmailChannelRequest],
            discriminator: %Discriminator{
              propertyName: "object_type",
              mapping: %{"email" => ExOpenApiUtilsTest.OpenApiSchema.EmailChannelRequest}
            }
          }
        )

        open_api_property(
          key: :channel,
          schema: %Schema{
            type: :object,
            readOnly: true,
            oneOf: [ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse],
            discriminator: %Discriminator{
              propertyName: "object_type",
              mapping: %{"email" => ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse}
            }
          }
        )

        polymorphic_embed_discriminator(key: :channel, type_field_name: :wrong_field)

        import PolymorphicEmbed

        @primary_key {:id, :binary_id, autogenerate: true}
        schema "type_field_mismatch_polymorphic_embed" do
          polymorphic_embeds_one :channel,
            types: [email: ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel],
            type_field_name: :__type__,
            on_type_not_found: :raise,
            on_replace: :update
        end

        open_api_schema(title: "Mismatch", description: "x", properties: [:channel])
      end
      """

      assert_raise CompileError, ~r/type_field_name/, fn ->
        Code.compile_string(code)
      end
    end

    test "wire value set mismatch raises" do
      code = """
      defmodule Test.PolyCheck.WireMismatch do
        use ExOpenApiUtils
        alias OpenApiSpex.Discriminator

        open_api_property(
          key: :channel,
          schema: %Schema{
            type: :object,
            writeOnly: true,
            oneOf: [ExOpenApiUtilsTest.OpenApiSchema.EmailChannelRequest],
            discriminator: %Discriminator{
              propertyName: "object_type",
              mapping: %{"email" => ExOpenApiUtilsTest.OpenApiSchema.EmailChannelRequest}
            }
          }
        )

        open_api_property(
          key: :channel,
          schema: %Schema{
            type: :object,
            readOnly: true,
            oneOf: [ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse],
            discriminator: %Discriminator{
              propertyName: "object_type",
              mapping: %{"email" => ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse}
            }
          }
        )

        polymorphic_embed_discriminator(key: :channel, type_field_name: :__type__)

        import PolymorphicEmbed

        @primary_key {:id, :binary_id, autogenerate: true}
        schema "wire_mismatch_polymorphic_embed" do
          polymorphic_embeds_one :channel,
            types: [
              email: ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel,
              sms: ExOpenApiUtilsTest.PolymorphicDiscriminator.SmsChannel
            ],
            type_field_name: :__type__,
            on_type_not_found: :raise,
            on_replace: :update
        end

        open_api_schema(title: "WireMismatch", description: "x", properties: [:channel])
      end
      """

      assert_raise CompileError, ~r/wire value sets must match/, fn ->
        Code.compile_string(code)
      end
    end

    test "discriminator propertyName disagreement raises" do
      code = """
      defmodule Test.PolyCheck.PropertyNameMismatch do
        use ExOpenApiUtils
        alias OpenApiSpex.Discriminator

        open_api_property(
          key: :channel,
          schema: %Schema{
            type: :object,
            writeOnly: true,
            oneOf: [ExOpenApiUtilsTest.OpenApiSchema.EmailChannelRequest],
            discriminator: %Discriminator{
              propertyName: "object_type",
              mapping: %{"email" => ExOpenApiUtilsTest.OpenApiSchema.EmailChannelRequest}
            }
          }
        )

        open_api_property(
          key: :channel,
          schema: %Schema{
            type: :object,
            readOnly: true,
            oneOf: [ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse],
            discriminator: %Discriminator{
              propertyName: "kind",
              mapping: %{"email" => ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse}
            }
          }
        )

        polymorphic_embed_discriminator(key: :channel, type_field_name: :__type__)

        import PolymorphicEmbed

        @primary_key {:id, :binary_id, autogenerate: true}
        schema "property_mismatch_polymorphic_embed" do
          polymorphic_embeds_one :channel,
            types: [email: ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel],
            type_field_name: :__type__,
            on_type_not_found: :raise,
            on_replace: :update
        end

        open_api_schema(title: "PropertyMismatch", description: "x", properties: [:channel])
      end
      """

      assert_raise CompileError, ~r/share the same discriminator.propertyName/, fn ->
        Code.compile_string(code)
      end
    end

    test "oneOf and mapping values out of sync raises" do
      code = """
      defmodule Test.PolyCheck.OneOfMappingDrift do
        use ExOpenApiUtils
        alias OpenApiSpex.Discriminator

        open_api_property(
          key: :channel,
          schema: %Schema{
            type: :object,
            writeOnly: true,
            oneOf: [
              ExOpenApiUtilsTest.OpenApiSchema.EmailChannelRequest,
              ExOpenApiUtilsTest.OpenApiSchema.SmsChannelRequest
            ],
            discriminator: %Discriminator{
              propertyName: "object_type",
              mapping: %{
                "email" => ExOpenApiUtilsTest.OpenApiSchema.EmailChannelRequest
              }
            }
          }
        )

        open_api_property(
          key: :channel,
          schema: %Schema{
            type: :object,
            readOnly: true,
            oneOf: [ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse],
            discriminator: %Discriminator{
              propertyName: "object_type",
              mapping: %{"email" => ExOpenApiUtilsTest.OpenApiSchema.EmailChannelResponse}
            }
          }
        )

        polymorphic_embed_discriminator(key: :channel, type_field_name: :__type__)

        import PolymorphicEmbed

        @primary_key {:id, :binary_id, autogenerate: true}
        schema "oneof_drift_polymorphic_embed" do
          polymorphic_embeds_one :channel,
            types: [email: ExOpenApiUtilsTest.PolymorphicDiscriminator.EmailChannel],
            type_field_name: :__type__,
            on_type_not_found: :raise,
            on_replace: :update
        end

        open_api_schema(title: "OneOfDrift", description: "x", properties: [:channel])
      end
      """

      assert_raise CompileError, ~r/oneOf entries and discriminator.mapping values/, fn ->
        Code.compile_string(code)
      end
    end

    test "macro rejects non-atom :key" do
      assert_raise ArgumentError, ~r/:key must be an atom/, fn ->
        defmodule Test.PolyCheck.BadKey do
          use ExOpenApiUtils
          polymorphic_embed_discriminator(key: "channel", type_field_name: :__type__)
        end
      end
    end

    test "macro rejects non-atom :type_field_name" do
      assert_raise ArgumentError, ~r/:type_field_name must be an atom/, fn ->
        defmodule Test.PolyCheck.BadTypeField do
          use ExOpenApiUtils
          polymorphic_embed_discriminator(key: :channel, type_field_name: "__type__")
        end
      end
    end
  end
end
