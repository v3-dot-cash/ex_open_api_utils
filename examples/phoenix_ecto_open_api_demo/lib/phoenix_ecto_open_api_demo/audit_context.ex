defmodule PhoenixEctoOpenApiDemo.AuditContext do
  @moduledoc """
  Context module for polymorphic audit events.

  Deliberately minimal (no `list_/update_/delete_` helpers) — this context
  exists as a paranoia fixture for the GH-27 bytecode persistence
  regression lock, not as a full CRUD demo.
  """
  alias PhoenixEctoOpenApiDemo.AuditContext.AuditEvent
  alias PhoenixEctoOpenApiDemo.Repo

  def get_audit_event!(id), do: Repo.get!(AuditEvent, id)

  def create_audit_event(attrs) do
    %AuditEvent{}
    |> AuditEvent.changeset(attrs)
    |> Repo.insert()
  end
end
