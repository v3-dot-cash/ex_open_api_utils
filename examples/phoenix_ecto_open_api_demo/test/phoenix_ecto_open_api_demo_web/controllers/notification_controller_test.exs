defmodule PhoenixEctoOpenApiDemoWeb.NotificationControllerTest do
  @moduledoc """
  End-to-end tests for the polymorphic-embed backed `Notification` resource.

  Every create/update/show test:

    1. Goes through the full Phoenix pipeline with
       `OpenApiSpex.Plug.CastAndValidate` on the request side — the request
       body is cast into a typed `%NotificationRequest{channel: %*Request{}}`
       struct via discriminator dispatch before the controller runs.

    2. Takes the raw JSON response body and feeds it back through
       `OpenApiSpex.Cast.cast/4` against the resolved
       `NotificationResponse` schema in `@api_spec.components.schemas`.
       The call uses `read_write_scope: :read` so required `writeOnly`
       fields are skipped on the response side. On success it returns a
       real `%NotificationResponseSchema{}` struct whose `:channel` is the
       correct variant struct (`%EmailResponse{}`, `%SmsResponse{}`, or
       `%WebhookResponse{}`) dispatched from the oneOf.

    3. Does a full deep pattern-match on the cast struct — every variant
       field asserted by name and value — and separately verifies the
       persisted Ecto variant struct hydrated from JSONB matches the same
       values verbatim.

  The response-side `Cast.cast` call is the GH-21 regression lock (the
  focused-cast-errors path runs on every test), and the deep channel
  checks + persistence round-trips are the GH-24 regression lock.
  """
  use PhoenixEctoOpenApiDemoWeb.ConnCase

  import PhoenixEctoOpenApiDemo.NotificationContextFixtures

  alias OpenApiSpex.Cast
  alias PhoenixEctoOpenApiDemo.NotificationContext
  alias PhoenixEctoOpenApiDemo.NotificationContext.Email
  alias PhoenixEctoOpenApiDemo.NotificationContext.Notification
  alias PhoenixEctoOpenApiDemo.NotificationContext.Sms
  alias PhoenixEctoOpenApiDemo.NotificationContext.Webhook

  # Auto-generated OpenApiSpex response submodules. They are real Elixir
  # structs (OpenApiSpex.schema/1 sets x-struct to the module itself), so
  # Cast.cast returns typed struct values we can pattern-match on.
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.EmailResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.NotificationResponse, as: NotificationResponseSchema
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.SmsResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.WebhookResponse

  @api_spec PhoenixEctoOpenApiDemoWeb.ApiSpec.spec()

  @email_attrs %{
    subject: "Your order has shipped",
    channel: %{
      object_type: "email",
      to: "buyer@example.com",
      from: "store@example.com",
      body: "Tracking: 1Z999AA10123456784"
    }
  }

  @sms_attrs %{
    subject: "Verification code",
    channel: %{
      object_type: "sms",
      phone_number: "+15551234567",
      body: "Your code is 4242"
    }
  }

  @webhook_attrs %{
    subject: "Order event",
    channel: %{
      object_type: "webhook",
      url: "https://hooks.example.com/abc",
      method: "POST"
    }
  }

  setup %{conn: conn} do
    {:ok,
     conn:
       conn
       |> put_req_header("accept", "application/json")
       |> put_req_header("content-type", "application/json")}
  end

  describe "index" do
    test "returns empty list when no notifications exist", %{conn: conn} do
      conn = get(conn, ~p"/api/notifications")
      assert json_response(conn, 200) == []
    end

    test "returns a mixed list where each channel casts to its variant struct", %{conn: conn} do
      email_notification_fixture()
      sms_notification_fixture()
      webhook_notification_fixture()

      conn = get(conn, ~p"/api/notifications")
      body = json_response(conn, 200)
      assert length(body) == 3

      # Cast each item individually against NotificationResponse so the
      # oneOf dispatch produces a concrete variant struct for every row.
      schemas = @api_spec.components.schemas
      notification_schema = Map.fetch!(schemas, "NotificationResponse")

      cast_items =
        Enum.map(body, fn item ->
          assert {:ok, cast} =
                   Cast.cast(notification_schema, item, schemas, read_write_scope: :read)

          cast
        end)

      by_variant =
        Enum.group_by(cast_items, fn
          %NotificationResponseSchema{channel: %EmailResponse{}} -> :email
          %NotificationResponseSchema{channel: %SmsResponse{}} -> :sms
          %NotificationResponseSchema{channel: %WebhookResponse{}} -> :webhook
        end)

      assert length(by_variant[:email]) == 1
      assert length(by_variant[:sms]) == 1
      assert length(by_variant[:webhook]) == 1

      assert [
               %NotificationResponseSchema{
                 id: email_id,
                 subject: "Your order has shipped",
                 channel: %EmailResponse{
                   to: "buyer@example.com",
                   from: "store@example.com",
                   body: "Tracking: 1Z999AA10123456784"
                 }
               }
             ] = by_variant[:email]

      assert is_binary(email_id)

      assert [
               %NotificationResponseSchema{
                 subject: "Verification code",
                 channel: %SmsResponse{
                   phone_number: "+15551234567",
                   body: "Your code is 4242"
                 }
               }
             ] = by_variant[:sms]

      assert [
               %NotificationResponseSchema{
                 subject: "Order event",
                 channel: %WebhookResponse{
                   url: "https://hooks.example.com/abc",
                   method: "POST"
                 }
               }
             ] = by_variant[:webhook]
    end
  end

  describe "create email notification" do
    test "returns 201, cast body is %NotificationResponseSchema{channel: %EmailResponse{}}", %{
      conn: conn
    } do
      conn = post(conn, ~p"/api/notifications", @email_attrs)
      body = json_response(conn, 201)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")

      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      # Deep pattern match on the cast struct — every variant field checked
      # by name, variant struct asserted, nothing from other variants
      # allowed through.
      assert %NotificationResponseSchema{
               id: id,
               subject: "Your order has shipped",
               channel: %EmailResponse{
                 to: "buyer@example.com",
                 from: "store@example.com",
                 body: "Tracking: 1Z999AA10123456784"
               }
             } = cast

      assert is_binary(id)
      assert {:ok, _} = Ecto.UUID.cast(id)

      # Persistence round-trip: the Ecto variant struct hydrated from JSONB
      # must contain every field verbatim.
      assert %Notification{
               id: ^id,
               subject: "Your order has shipped",
               channel: %Email{
                 to: "buyer@example.com",
                 from: "store@example.com",
                 body: "Tracking: 1Z999AA10123456784"
               }
             } = NotificationContext.get_notification!(id)
    end

    test "returns 422 when required email field is missing", %{conn: conn} do
      invalid = %{subject: "x", channel: %{object_type: "email", to: "a@b"}}
      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 when discriminator is missing (:no_value_for_discriminator)", %{conn: conn} do
      invalid = %{subject: "x", channel: %{to: "a@b", from: "c@d", body: "e"}}
      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 when discriminator is bogus (:invalid_discriminator_value)", %{conn: conn} do
      invalid = %{subject: "x", channel: %{object_type: "carrier_pigeon"}}
      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "create sms notification" do
    test "returns 201, cast body is %NotificationResponseSchema{channel: %SmsResponse{}}", %{
      conn: conn
    } do
      conn = post(conn, ~p"/api/notifications", @sms_attrs)
      body = json_response(conn, 201)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")

      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: id,
               subject: "Verification code",
               channel: %SmsResponse{
                 phone_number: "+15551234567",
                 body: "Your code is 4242"
               }
             } = cast

      assert is_binary(id)
      assert {:ok, _} = Ecto.UUID.cast(id)

      assert %Notification{
               id: ^id,
               subject: "Verification code",
               channel: %Sms{
                 phone_number: "+15551234567",
                 body: "Your code is 4242"
               }
             } = NotificationContext.get_notification!(id)
    end

    test "returns 422 when phone_number missing", %{conn: conn} do
      invalid = %{subject: "x", channel: %{object_type: "sms", body: "hi"}}
      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 when body missing", %{conn: conn} do
      invalid = %{subject: "x", channel: %{object_type: "sms", phone_number: "+15551234567"}}
      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "create webhook notification" do
    test "returns 201, cast body is %NotificationResponseSchema{channel: %WebhookResponse{}}", %{
      conn: conn
    } do
      conn = post(conn, ~p"/api/notifications", @webhook_attrs)
      body = json_response(conn, 201)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")

      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: id,
               subject: "Order event",
               channel: %WebhookResponse{
                 url: "https://hooks.example.com/abc",
                 method: "POST"
               }
             } = cast

      assert is_binary(id)
      assert {:ok, _} = Ecto.UUID.cast(id)

      assert %Notification{
               id: ^id,
               subject: "Order event",
               channel: %Webhook{
                 url: "https://hooks.example.com/abc",
                 method: "POST"
               }
             } = NotificationContext.get_notification!(id)
    end

    test "returns 422 when method is not one of the enum", %{conn: conn} do
      invalid = %{
        subject: "x",
        channel: %{
          object_type: "webhook",
          url: "https://hooks.example.com/abc",
          method: "TELEPORT"
        }
      }

      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "show notification" do
    test "shows an email notification, cast.channel is %EmailResponse{}", %{conn: conn} do
      notification = email_notification_fixture()

      conn = get(conn, ~p"/api/notifications/#{notification.id}")
      body = json_response(conn, 200)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")
      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: notification_id,
               subject: "Your order has shipped",
               channel: %EmailResponse{
                 to: "buyer@example.com",
                 from: "store@example.com",
                 body: "Tracking: 1Z999AA10123456784"
               }
             } = cast

      assert notification_id == notification.id
    end

    test "shows an sms notification, cast.channel is %SmsResponse{}", %{conn: conn} do
      notification = sms_notification_fixture()

      conn = get(conn, ~p"/api/notifications/#{notification.id}")
      body = json_response(conn, 200)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")
      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: notification_id,
               subject: "Verification code",
               channel: %SmsResponse{
                 phone_number: "+15551234567",
                 body: "Your code is 4242"
               }
             } = cast

      assert notification_id == notification.id
    end

    test "shows a webhook notification, cast.channel is %WebhookResponse{}", %{conn: conn} do
      notification = webhook_notification_fixture()

      conn = get(conn, ~p"/api/notifications/#{notification.id}")
      body = json_response(conn, 200)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")
      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: notification_id,
               subject: "Order event",
               channel: %WebhookResponse{
                 url: "https://hooks.example.com/abc",
                 method: "POST"
               }
             } = cast

      assert notification_id == notification.id
    end

    test "returns 404 for a non-existent id", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/api/notifications/851b18d7-0c88-4095-9969-cbe385926420")
      end
    end
  end

  describe "update notification" do
    test "updates only the subject, cast.channel still %EmailResponse{}", %{conn: conn} do
      notification = email_notification_fixture()

      update_attrs = %{
        subject: "Updated subject",
        channel: %{
          object_type: "email",
          to: "buyer@example.com",
          from: "store@example.com",
          body: "Tracking: 1Z999AA10123456784"
        }
      }

      conn = put(conn, ~p"/api/notifications/#{notification}", update_attrs)
      body = json_response(conn, 200)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")
      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: id,
               subject: "Updated subject",
               channel: %EmailResponse{
                 to: "buyer@example.com",
                 from: "store@example.com",
                 body: "Tracking: 1Z999AA10123456784"
               }
             } = cast

      assert id == notification.id
    end

    test "switches channel variant from email to sms (on_replace: :update)", %{conn: conn} do
      notification = email_notification_fixture()

      update_attrs = %{
        subject: "Now over SMS",
        channel: %{
          object_type: "sms",
          phone_number: "+15551234567",
          body: "Your code is 4242"
        }
      }

      conn = put(conn, ~p"/api/notifications/#{notification}", update_attrs)
      body = json_response(conn, 200)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")
      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      # The channel must have cast into the new variant, not the original.
      assert %NotificationResponseSchema{
               id: id,
               subject: "Now over SMS",
               channel: %SmsResponse{
                 phone_number: "+15551234567",
                 body: "Your code is 4242"
               }
             } = cast

      assert id == notification.id

      assert %Notification{
               id: ^id,
               channel: %Sms{
                 phone_number: "+15551234567",
                 body: "Your code is 4242"
               }
             } = NotificationContext.get_notification!(id)
    end

    test "switches channel variant from sms to webhook", %{conn: conn} do
      notification = sms_notification_fixture()

      update_attrs = %{
        subject: "Now over webhook",
        channel: %{
          object_type: "webhook",
          url: "https://hooks.example.com/new",
          method: "POST"
        }
      }

      conn = put(conn, ~p"/api/notifications/#{notification}", update_attrs)
      body = json_response(conn, 200)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")
      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: id,
               subject: "Now over webhook",
               channel: %WebhookResponse{
                 url: "https://hooks.example.com/new",
                 method: "POST"
               }
             } = cast

      assert id == notification.id

      assert %Notification{
               id: ^id,
               channel: %Webhook{
                 url: "https://hooks.example.com/new",
                 method: "POST"
               }
             } = NotificationContext.get_notification!(id)
    end

    test "returns 422 when update is invalid", %{conn: conn} do
      notification = email_notification_fixture()

      invalid = %{
        subject: "x",
        channel: %{object_type: "email", to: "only-to"}
      }

      conn = put(conn, ~p"/api/notifications/#{notification}", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "delete notification" do
    test "deletes the notification", %{conn: conn} do
      notification = webhook_notification_fixture()

      conn = delete(conn, ~p"/api/notifications/#{notification}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/notifications/#{notification}")
      end
    end
  end
end
