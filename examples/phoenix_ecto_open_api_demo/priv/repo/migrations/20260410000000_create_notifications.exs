defmodule PhoenixEctoOpenApiDemo.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :subject, :string, null: false
      add :channel, :map, null: false

      timestamps()
    end
  end
end
