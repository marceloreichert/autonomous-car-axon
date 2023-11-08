defmodule AutonomousCar do
  @moduledoc """
  Starter application using the Scenic framework.
  """

  def start(_type, _args) do
    children = [
      {Scenic, [main_viewport_config()]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def main_viewport_config() do
    [
      name: :main_viewport,
      size: {1200, 600},
      default_scene: {AutonomousCar.Scene.Environment, nil},
      drivers: [
        [
          module: Scenic.Driver.Local,
          name: :local
        ]
      ]
    ]
  end
end
