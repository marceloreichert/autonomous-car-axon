defmodule AutonomousCar.MixProject do
  use Mix.Project

  def project do
    [
      app: :autonomous_car,
      version: "0.1.0",
      elixir: "~> 1.11",
      build_embedded: true,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {AutonomousCar, []},
      extra_applications: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:scenic, "~> 0.10"},
      {:scenic_driver_glfw, "~> 0.10"},
      {:math, "~> 0.3.0"},
      {:nx, "~> 0.1.0-dev", github: "elixir-nx/nx", branch: "main", sparse: "nx", override: true},
      {:axon, "~> 0.1.0-dev", github: "elixir-nx/axon", branch: "main"}
    ]
  end
end
