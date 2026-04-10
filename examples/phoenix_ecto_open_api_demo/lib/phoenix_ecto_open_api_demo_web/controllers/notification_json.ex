defmodule PhoenixEctoOpenApiDemoWeb.NotificationJSON do
  @moduledoc """
  JSON renderer for notifications.

  The interesting part is `render_channel/1`: when we serialize a notification,
  the `:channel` field holds an `%Email{}`, `%Sms{}`, or `%Webhook{}` variant
  struct. We pattern-match on the struct module to emit the correct
  `__type__` value inline so that:

    1. The wire format matches what the OpenAPI spec describes (a variant
       schema with `__type__` locked by enum).
    2. Clients can `switch (channel.__type__)` without a second API call.
    3. The same JSON can be round-tripped back through
       `PolymorphicEmbed.cast_polymorphic_embed/3` on the next request.
  """
  alias PhoenixEctoOpenApiDemo.NotificationContext.Email
  alias PhoenixEctoOpenApiDemo.NotificationContext.Notification
  alias PhoenixEctoOpenApiDemo.NotificationContext.Sms
  alias PhoenixEctoOpenApiDemo.NotificationContext.Webhook

  @doc "Renders a list of notifications."
  def index(%{notifications: notifications}) do
    for notification <- notifications, do: data(notification)
  end

  @doc "Renders a single notification."
  def show(%{notification: notification}) do
    data(notification)
  end

  defp data(%Notification{} = notification) do
    %{
      id: notification.id,
      subject: notification.subject,
      channel: render_channel(notification.channel)
    }
  end

  defp render_channel(%Email{to: to, from: from, body: body}) do
    %{"__type__" => "email", "to" => to, "from" => from, "body" => body}
  end

  defp render_channel(%Sms{phone_number: phone, body: body}) do
    %{"__type__" => "sms", "phone_number" => phone, "body" => body}
  end

  defp render_channel(%Webhook{url: url, method: method}) do
    %{"__type__" => "webhook", "url" => url, "method" => method}
  end
end
