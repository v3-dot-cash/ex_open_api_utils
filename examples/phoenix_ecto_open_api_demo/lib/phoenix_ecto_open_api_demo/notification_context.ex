defmodule PhoenixEctoOpenApiDemo.NotificationContext do
  @moduledoc """
  Context module for outbound notifications with polymorphic channels.

  This mirrors `PhoenixEctoOpenApiDemo.BusinessContext` but demonstrates the
  polymorphic embed pattern: a single `:channel` field that can be one of
  Email / Sms / Webhook at runtime, described on the OpenAPI side via
  `ExOpenApiUtils.Polymorphic.one_of/1`.
  """
  import Ecto.Query, warn: false

  alias PhoenixEctoOpenApiDemo.NotificationContext.Notification
  alias PhoenixEctoOpenApiDemo.Repo

  @doc """
  Returns the list of notifications.

  The list contains notifications with *different* channel variants —
  this is where `oneOf + discriminator` pays off most: client code can
  switch on `__type__` to branch rendering.
  """
  def list_notifications do
    Repo.all(Notification)
  end

  @doc "Gets a single notification. Raises `Ecto.NoResultsError` if not found."
  def get_notification!(id), do: Repo.get!(Notification, id)

  @doc """
  Creates a notification.

  `attrs` is the raw payload map — it must include `"channel" => %{"__type__" => ...}`
  so `PolymorphicEmbed.cast_polymorphic_embed/3` can pick the right variant.
  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a notification."
  def update_notification(%Notification{} = notification, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a notification."
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking notification changes.
  """
  def change_notification(%Notification{} = notification, attrs \\ %{}) do
    Notification.changeset(notification, attrs)
  end
end
