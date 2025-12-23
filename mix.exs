defmodule ExOpenApiUtils.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_open_api_utils,
      version: "0.10.0",
      elixir: "~> 1.18",
      description: "Elixir utilities for OpenAPI 3.2 schema generation from Ecto schemas",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,
      package: [
        links: %{"GitHub" => "https://github.com/v3-dot-cash/ex_open_api_utils"},
        licenses: ["MIT"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.39.3"},
      {:open_api_spex, "~> 3.22"},
      {:ecto, "~> 3.13"},
      {:inflex, "~> 2.1"},
      {:ymlr, "~> 5.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
