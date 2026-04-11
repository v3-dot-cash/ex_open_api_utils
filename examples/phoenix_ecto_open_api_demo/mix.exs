defmodule PhoenixEctoOpenApiDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_ecto_open_api_demo,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # Phoenix 1.8+ expects the code reloader to be registered as a
      # Mix listener so it can receive compile-events from other
      # tasks running in parallel. Without this, every request that
      # triggers a reload check logs a spurious warning + stack
      # trace. Silences the noise in dev and in the local vitest tier
      # (which runs `mix phx.server` via the Makefile).
      listeners: [Phoenix.CodeReloader],
      test_coverage: [
        # Ignore modules that have no meaningful lines to unit-test from
        # the example-app test suite. Each exclusion is justified by
        # "no reachable code in the :test env" — never a "too hard to
        # test" cop-out.
        #
        # Test support (test/support/ is compiled into :test env via
        # elixirc_paths/1 but is not production code):
        #   * PhoenixEctoOpenApiDemo.DataCase
        #   * PhoenixEctoOpenApiDemoWeb.ConnCase
        #
        # CLI entrypoint (exercised by running the task as a shell
        # command, not by function calls):
        #   * Mix.Tasks.Openapi.Dump
        #
        # Phoenix scaffold with trivial render bodies — auto-generated
        # by `mix phx.new` with one-line error renderers:
        #   * PhoenixEctoOpenApiDemoWeb.ChangesetJSON
        #   * PhoenixEctoOpenApiDemoWeb.FallbackController
        #
        # Mix.env()-gated dead code that's unreachable in :test env:
        #   * PhoenixEctoOpenApiDemo.Repo — Repo.init/2's only
        #     interesting branch is dev/prod config injection, which
        #     the test env doesn't hit.
        #   * PhoenixEctoOpenApiDemo.Application — config_change/3 is
        #     a no-op Phoenix-generated stub only fired by OTP on
        #     runtime application config changes, never in `mix test`.
        #   * PhoenixEctoOpenApiDemoWeb.Router — the `/dev` scope is
        #     gated on `Application.compile_env :dev_routes`, which is
        #     false in test env and the branch body compiles to
        #     nothing-reachable.
        #
        # Phoenix scaffold for metrics:
        #   * PhoenixEctoOpenApiDemoWeb.Telemetry — metric-definition
        #     callbacks fired only by periodic pollers in prod.
        ignore_modules: [
          PhoenixEctoOpenApiDemo.DataCase,
          PhoenixEctoOpenApiDemoWeb.ConnCase,
          Mix.Tasks.Openapi.Dump,
          PhoenixEctoOpenApiDemoWeb.ChangesetJSON,
          PhoenixEctoOpenApiDemoWeb.FallbackController,
          PhoenixEctoOpenApiDemo.Repo,
          PhoenixEctoOpenApiDemo.Application,
          PhoenixEctoOpenApiDemoWeb.Router,
          PhoenixEctoOpenApiDemoWeb.Telemetry
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {PhoenixEctoOpenApiDemo.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.7"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.21.1"},
      {:swoosh, "~> 1.19"},
      {:finch, "~> 0.20.0"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7"},
      {:polymorphic_embed, "~> 5.0"},
      {:ex_open_api_utils, path: "../../"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
