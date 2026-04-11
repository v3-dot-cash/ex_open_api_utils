defmodule PhoenixEctoOpenApiDemo.Repo.Migrations.CreateAuditEvents do
  use Ecto.Migration

  def change do
    create table(:audit_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :actor, :string, null: false
      add :payload, :map, null: false

      timestamps()
    end
  end
end
