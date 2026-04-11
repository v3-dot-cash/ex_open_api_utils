defmodule ExOpenApiUtils.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_open_api_utils,
      version: "0.13.1",
      elixir: "~> 1.18",
      description: "Elixir utilities for OpenAPI 3.1 schema generation from Ecto schemas",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,
      test_coverage: [
        # Exclude modules that are genuinely not unit-testable:
        #   * The yaml-dump mix task is a CLI entrypoint exercised via
        #     `mix ex_open_api_utils.spec.yaml` not unit calls.
        #   * The Mapper protocol has fallback impls for List, plain maps,
        #     Ecto.Association.NotLoaded, and a helper Utils module. The
        #     fallbacks exist to route edge-case runtime types and are
        #     integration-tested indirectly via consumer code rather than
        #     in the library's own test suite.
        ignore_modules: [
          Mix.Tasks.ExOpenApiUtils.Spec.Yaml,
          ExOpenApiUtils.Mapper.List,
          ExOpenApiUtils.Mapper.Utils,
          ExOpenApiUtils.Mapper.Ecto.Association.NotLoaded
        ]
      ],
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
      {:ex_doc, "~> 0.39.3", only: :dev, runtime: false},
      {:open_api_spex, "~> 3.22"},
      {:ecto, "~> 3.13"},
      {:inflex, "~> 2.1"},
      {:ymlr, "~> 5.1"},
      {:polymorphic_embed, "~> 5.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
