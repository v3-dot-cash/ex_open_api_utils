defmodule Mix.Tasks.Openapi.Dump do
  @moduledoc """
  Dumps the resolved OpenAPI spec to `priv/static/openapi.json`.

  Used by the local vitest integration tier's hey-api SDK generator:
  `make vitest-generate-sdk` runs this task first, then points hey-api at
  the resulting file to emit a typed TypeScript client for the tests.

  Run via `mix openapi.dump`. The output path is always
  `priv/static/openapi.json` relative to the current working directory.
  """
  @shortdoc "Dump OpenAPI spec to priv/static/openapi.json"
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    spec = PhoenixEctoOpenApiDemoWeb.ApiSpec.spec()
    json = Jason.encode!(spec, pretty: true)

    path = Path.join([File.cwd!(), "priv", "static", "openapi.json"])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, json)

    Mix.shell().info("Wrote #{path}")
  end
end
