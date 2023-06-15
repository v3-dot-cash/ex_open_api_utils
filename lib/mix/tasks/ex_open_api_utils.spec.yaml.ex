defmodule Mix.Tasks.ExOpenApiUtils.Spec.Yaml do
  use Mix.Task
  require Mix.Generator

  @default_filename "openapi.yaml"
  @dialyzer {:nowarn_function, encoder: 0}

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, strict: [start_app: :boolean])

    Keyword.get(opts, :start_app, true) |> maybe_start_app()
    OpenApiSpex.ExportSpec.call(argv, &encode/2, @default_filename)
  end

  defp maybe_start_app(true), do: Mix.Task.run("app.start")
  defp maybe_start_app(_), do: Mix.Task.run("app.config", preload_modules: true)

  defp encode(spec, opts) do
    spec
    |> encoder().encode(opts)
    |> case do
      {:ok, yaml} ->
        yaml

      {:error, error} ->
        Mix.raise("could not encode #{inspect(spec)}, error: #{inspect(error)}.")
    end
  end

  defp encoder do
    OpenApiSpex.OpenApi.yaml_encoder() ||
      Mix.raise(
        "could not load YAML encoder, please add one of supported encoders to dependencies."
      )
  end
end
