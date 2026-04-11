defmodule PhoenixEctoOpenApiDemoWeb.NotificationJSON do
  @moduledoc """
  JSON renderer for notifications. `ExOpenApiUtils.Mapper.to_map/1` handles
  everything — including injecting the wire discriminator
  (`"channel_type" => "email"` / `"sms"` / `"webhook"`) into the channel
  map at render time, which is what makes the wire format line up with
  the `oneOf + discriminator` spec the `NotificationResponse` submodule
  declares.
  """

  def index(%{notifications: notifications}) do
    Enum.map(notifications, &ExOpenApiUtils.Mapper.to_map/1)
  end

  def show(%{notification: notification}) do
    ExOpenApiUtils.Mapper.to_map(notification)
  end
end
