defmodule AutonomousCar.Objects.Car do

  def move(%{objects: %{car: car}} = state) do
    car_angle = car.angle
    car_velocity_rotate = AutonomousCar.Math.Vector.rotate(car.velocity, car_angle)
    new_coords = Scenic.Math.Vector2.add(car.coords, car_velocity_rotate)

    # Keep car inside environment
    new_new_coords =
      with {car_coords_x, car_coords_y} <- new_coords,
           viewport_width <- state.viewport_width,
           viewport_height <- state.viewport_height do

        car_coords_x = if car_coords_x + 20 >= viewport_width, do: viewport_width - 20, else: car_coords_x
        car_coords_x = if car_coords_x <= 20, do: 20, else: car_coords_x

        car_coords_y = if car_coords_y + 20 >= viewport_height, do: viewport_height - 20, else: car_coords_y
        car_coords_y = if car_coords_y <= 20, do: 20, else: car_coords_y

        {car_coords_x, car_coords_y}
      end

    car_angle = if new_new_coords != new_coords, do: car_angle + 20, else: car_angle

    state
    |> put_in([:objects, :car, :angle], car_angle)
    |> put_in([:objects, :car, :last_coords], car.coords)
    |> put_in([:objects, :car, :coords], new_new_coords)
  end

  def update_angle(state, action) do
    rotation = action?(action)

    state
    |> put_in([:objects, :car, :angle], state.objects.car.angle + rotation)
  end

  defp action?(0), do: -20
  defp action?(2), do: 20
  defp action?(_), do: 0
end
