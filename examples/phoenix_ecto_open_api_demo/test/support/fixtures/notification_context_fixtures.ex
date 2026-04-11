defmodule PhoenixEctoOpenApiDemo.NotificationContextFixtures do
  @moduledoc """
  Test helpers for creating `PhoenixEctoOpenApiDemo.NotificationContext`
  entities. Each fixture exercises a different polymorphic channel variant.
  """

  alias PhoenixEctoOpenApiDemo.NotificationContext

  @doc "Creates a notification with an email channel."
  def email_notification_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        subject: "Your order has shipped",
        channel: %{
          __type__: "email",
          to: "buyer@example.com",
          from: "store@example.com",
          body: "Tracking: 1Z999AA10123456784"
        }
      })

    {:ok, notification} = NotificationContext.create_notification(attrs)
    notification
  end

  @doc "Creates a notification with an SMS channel."
  def sms_notification_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        subject: "Verification code",
        channel: %{
          __type__: "sms",
          phone_number: "+15551234567",
          body: "Your code is 4242"
        }
      })

    {:ok, notification} = NotificationContext.create_notification(attrs)
    notification
  end

  @doc "Creates a notification with a webhook channel."
  def webhook_notification_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        subject: "Order event",
        channel: %{
          __type__: "webhook",
          url: "https://hooks.example.com/abc",
          method: "POST"
        }
      })

    {:ok, notification} = NotificationContext.create_notification(attrs)
    notification
  end
end
