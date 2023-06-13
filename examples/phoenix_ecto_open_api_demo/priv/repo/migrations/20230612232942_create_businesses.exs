defmodule PhoenixEctoOpenApiDemo.Repo.Migrations.CreateBusinesses do
  use Ecto.Migration

  def change do
    create table(:businesses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :tenant_id, references(:tenants, on_delete: :nothing, type: :binary_id)

      timestamps()
    end

    create index(:businesses, [:tenant_id])
  end
end
