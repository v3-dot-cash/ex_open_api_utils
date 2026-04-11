defmodule PhoenixEctoOpenApiDemo.AuditContextFixtures do
  @moduledoc """
  Test helpers for creating `PhoenixEctoOpenApiDemo.AuditContext` entities.

  Fixture attribute maps use string keys throughout so that the test-file
  bytecode never accidentally references the wire discriminator atom as a
  literal. The bytecode persistence regression lock depends on the
  library's Mapper impl being the only compiled artifact that carries
  `:audit_kind` — an accidental atom literal elsewhere would mask the bug
  by rescuing the atom into the runtime atom table.
  """

  alias PhoenixEctoOpenApiDemo.AuditContext

  @doc "Creates an audit event with a user-login payload."
  def user_login_audit_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "actor" => "api-token-42",
        "payload" => %{
          "__audit_type__" => "user_login",
          "user_id" => "u_123",
          "ip_address" => "10.0.0.1"
        }
      })

    {:ok, audit_event} = AuditContext.create_audit_event(attrs)
    audit_event
  end

  @doc "Creates an audit event with a data-export payload."
  def data_export_audit_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "actor" => "api-token-42",
        "payload" => %{
          "__audit_type__" => "data_export",
          "resource" => "users",
          "row_count" => 42
        }
      })

    {:ok, audit_event} = AuditContext.create_audit_event(attrs)
    audit_event
  end
end
