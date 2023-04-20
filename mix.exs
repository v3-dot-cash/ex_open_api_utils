defmodule ExOpenApiUtils.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_open_api_utils,
      version: "0.4.1",
      elixir: "~> 1.14",
      description: "Elixir Utilities for open api 3.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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
      {:ex_doc, "~> 0.29.4"},
      {:open_api_spex, "~> 3.16"},
      {:ecto, "~> 3.9.2"},
      {:inflex, "~> 2.1"}

      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
