defmodule PhoenixEctoOpenApiDemo.Repo do
  use Ecto.Repo,
    otp_app: :phoenix_ecto_open_api_demo,
    adapter: Ecto.Adapters.Postgres
end
