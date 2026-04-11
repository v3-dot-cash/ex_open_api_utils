defmodule PhoenixEctoOpenApiDemo.NotificationContext do
  @moduledoc """
  Context module for outbound notifications with polymorphic channels.

  Demonstrates the polymorphic embed pattern: a single `:channel` field
  that hydrates into one of `Email` / `Sms` / `Webhook` at runtime.
  """
  import Ecto.Query, warn: false

  alias PhoenixEctoOpenApiDemo.NotificationContext.Notification
  alias PhoenixEctoOpenApiDemo.Repo

  def list_notifications do
    Repo.all(Notification)
  end

  def get_notification!(id), do: Repo.get!(Notification, id)

  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  def update_notification(%Notification{} = notification, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Repo.update()
  end

  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end
end
