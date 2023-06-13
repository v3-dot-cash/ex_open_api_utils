defmodule PhoenixEctoOpenApiDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      PhoenixEctoOpenApiDemoWeb.Telemetry,
      # Start the Ecto repository
      PhoenixEctoOpenApiDemo.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: PhoenixEctoOpenApiDemo.PubSub},
      # Start Finch
      {Finch, name: PhoenixEctoOpenApiDemo.Finch},
      # Start the Endpoint (http/https)
      PhoenixEctoOpenApiDemoWeb.Endpoint
      # Start a worker by calling: PhoenixEctoOpenApiDemo.Worker.start_link(arg)
      # {PhoenixEctoOpenApiDemo.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixEctoOpenApiDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhoenixEctoOpenApiDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
