defmodule AutonomousCar.Math.Vector do
  import Math

  def rotate({x, y} = vector, angle) do
    angle = degrees_to_radians(angle)
    {x * cos(angle) - y * sin(angle), x * sin(angle) + y * cos(angle)}
  end

  def degrees_to_radians(angle) do
    angle * (Math.pi / 180)
  end
end
