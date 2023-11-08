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
      {:scenic, "~> 0.11.2"},
      {:scenic_driver_local, "~> 0.11.0"},
      {:math, "~> 0.7.0"},
      {:nx, "~> 0.6.2"},
      {:axon, "~> 0.6.0"}
    ]
  end
end
