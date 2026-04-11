defmodule PhoenixEctoOpenApiDemoWeb.NotificationControllerTest do
  @moduledoc """
  End-to-end tests for the polymorphic-embed backed `Notification` resource.

  Every test that exercises create/update/show goes through the full Phoenix
  pipeline with `OpenApiSpex.Plug.CastAndValidate` on the request side, and
  asserts that the response body conforms to `NotificationResponse` via
  `OpenApiSpex.TestAssertions.assert_schema/3` AND does a deep field-level
  comparison on the response payload. The assert_schema call is the GH-21
  regression lock (schema round-trips through Cast.cast with the full
  discriminator dispatch path); the deep field assertions are the GH-24
  regression lock (the wire format on the response side must carry the
  discriminator inline for each variant).
  """
  use PhoenixEctoOpenApiDemoWeb.ConnCase

  import OpenApiSpex.TestAssertions
  import PhoenixEctoOpenApiDemo.NotificationContextFixtures

  alias PhoenixEctoOpenApiDemo.NotificationContext
  alias PhoenixEctoOpenApiDemo.NotificationContext.Email
  alias PhoenixEctoOpenApiDemo.NotificationContext.Notification
  alias PhoenixEctoOpenApiDemo.NotificationContext.Sms
  alias PhoenixEctoOpenApiDemo.NotificationContext.Webhook

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

    test "returns a mixed list where each channel carries object_type inline", %{conn: conn} do
      email_notification_fixture()
      sms_notification_fixture()
      webhook_notification_fixture()

      conn = get(conn, ~p"/api/notifications")
      body = json_response(conn, 200)

      assert length(body) == 3

      for item <- body do
        assert Map.has_key?(item["channel"], "object_type")
      end

      object_types = body |> Enum.map(& &1["channel"]["object_type"]) |> Enum.sort()
      assert object_types == ["email", "sms", "webhook"]

      email_item = Enum.find(body, &(&1["channel"]["object_type"] == "email"))
      assert email_item["channel"]["to"] == "buyer@example.com"
      assert email_item["channel"]["from"] == "store@example.com"
      assert email_item["channel"]["body"] == "Tracking: 1Z999AA10123456784"
      assert_schema(email_item, "NotificationResponse", @api_spec)

      sms_item = Enum.find(body, &(&1["channel"]["object_type"] == "sms"))
      assert sms_item["channel"]["phone_number"] == "+15551234567"
      assert sms_item["channel"]["body"] == "Your code is 4242"
      assert_schema(sms_item, "NotificationResponse", @api_spec)

      webhook_item = Enum.find(body, &(&1["channel"]["object_type"] == "webhook"))
      assert webhook_item["channel"]["url"] == "https://hooks.example.com/abc"
      assert webhook_item["channel"]["method"] == "POST"
      assert_schema(webhook_item, "NotificationResponse", @api_spec)
    end
  end

  describe "create email notification" do
    test "returns 201 with object_type inline and conforming to NotificationResponse", %{
      conn: conn
    } do
      conn = post(conn, ~p"/api/notifications", @email_attrs)
      body = json_response(conn, 201)

      assert %{
               "id" => id,
               "subject" => "Your order has shipped",
               "channel" => %{
                 "object_type" => "email",
                 "to" => "buyer@example.com",
                 "from" => "store@example.com",
                 "body" => "Tracking: 1Z999AA10123456784"
               }
             } = body

      assert is_binary(id)
      assert_schema(body, "NotificationResponse", @api_spec)

      persisted = NotificationContext.get_notification!(id)
      assert %Notification{channel: %Email{} = channel} = persisted
      assert channel.to == "buyer@example.com"
      assert channel.from == "store@example.com"
      assert channel.body == "Tracking: 1Z999AA10123456784"
    end

    test "returns 422 when required email field is missing", %{conn: conn} do
      invalid = %{
        subject: "x",
        channel: %{object_type: "email", to: "a@b"}
      }

      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 when discriminator is missing (:no_value_for_discriminator)", %{conn: conn} do
      invalid = %{
        subject: "x",
        channel: %{to: "a@b", from: "c@d", body: "e"}
      }

      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 when discriminator is bogus (:invalid_discriminator_value)", %{conn: conn} do
      invalid = %{
        subject: "x",
        channel: %{object_type: "carrier_pigeon"}
      }

      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "create sms notification" do
    test "returns 201 with object_type=sms and conforming to NotificationResponse", %{conn: conn} do
      conn = post(conn, ~p"/api/notifications", @sms_attrs)
      body = json_response(conn, 201)

      assert %{
               "id" => id,
               "subject" => "Verification code",
               "channel" => %{
                 "object_type" => "sms",
                 "phone_number" => "+15551234567",
                 "body" => "Your code is 4242"
               }
             } = body

      assert is_binary(id)
      assert_schema(body, "NotificationResponse", @api_spec)

      assert %Notification{channel: %Sms{phone_number: "+15551234567"}} =
               NotificationContext.get_notification!(id)
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
    test "returns 201 with object_type=webhook and conforming to NotificationResponse", %{
      conn: conn
    } do
      conn = post(conn, ~p"/api/notifications", @webhook_attrs)
      body = json_response(conn, 201)

      assert %{
               "id" => id,
               "subject" => "Order event",
               "channel" => %{
                 "object_type" => "webhook",
                 "url" => "https://hooks.example.com/abc",
                 "method" => "POST"
               }
             } = body

      assert is_binary(id)
      assert_schema(body, "NotificationResponse", @api_spec)

      assert %Notification{channel: %Webhook{url: "https://hooks.example.com/abc", method: "POST"}} =
               NotificationContext.get_notification!(id)
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
    test "shows an email notification with object_type inline", %{conn: conn} do
      notification = email_notification_fixture()

      conn = get(conn, ~p"/api/notifications/#{notification.id}")
      body = json_response(conn, 200)

      assert body["id"] == notification.id
      assert body["channel"]["object_type"] == "email"
      assert body["channel"]["to"] == "buyer@example.com"
      assert_schema(body, "NotificationResponse", @api_spec)
    end

    test "shows an sms notification with object_type inline", %{conn: conn} do
      notification = sms_notification_fixture()

      conn = get(conn, ~p"/api/notifications/#{notification.id}")
      body = json_response(conn, 200)

      assert body["channel"]["object_type"] == "sms"
      assert body["channel"]["phone_number"] == "+15551234567"
      assert_schema(body, "NotificationResponse", @api_spec)
    end

    test "shows a webhook notification with object_type inline", %{conn: conn} do
      notification = webhook_notification_fixture()

      conn = get(conn, ~p"/api/notifications/#{notification.id}")
      body = json_response(conn, 200)

      assert body["channel"]["object_type"] == "webhook"
      assert body["channel"]["method"] == "POST"
      assert_schema(body, "NotificationResponse", @api_spec)
    end

    test "returns 404 for a non-existent id", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/api/notifications/851b18d7-0c88-4095-9969-cbe385926420")
      end
    end
  end

  describe "update notification" do
    test "updates only the subject", %{conn: conn} do
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

      assert body["id"] == notification.id
      assert body["subject"] == "Updated subject"
      assert body["channel"]["object_type"] == "email"
      assert_schema(body, "NotificationResponse", @api_spec)
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

      assert body["id"] == notification.id
      assert body["channel"]["object_type"] == "sms"
      assert body["channel"]["phone_number"] == "+15551234567"
      refute Map.has_key?(body["channel"], "to")
      assert_schema(body, "NotificationResponse", @api_spec)

      assert %Notification{channel: %Sms{}} = NotificationContext.get_notification!(notification.id)
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

      assert body["channel"]["object_type"] == "webhook"
      assert body["channel"]["url"] == "https://hooks.example.com/new"
      assert_schema(body, "NotificationResponse", @api_spec)

      assert %Notification{channel: %Webhook{}} =
               NotificationContext.get_notification!(notification.id)
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
