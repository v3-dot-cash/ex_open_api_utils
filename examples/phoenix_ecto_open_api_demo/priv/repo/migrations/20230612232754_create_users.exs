defmodule PhoenixEctoOpenApiDemo.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :tenant_id, references(:tenants, on_delete: :nothing, type: :binary_id)

      timestamps()
    end

    create index(:users, [:tenant_id])
  end
end
