defmodule PhoenixEctoOpenApiDemo.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :destination, :map, null: false

      timestamps()
    end
  end
end
