defmodule AutonomousCar.Scene.Environment do
  use Scenic.Scene

  alias Scenic.Graph
  alias Scenic.ViewPort

  alias AutonomousCar.Objects.Car
  alias AutonomousCar.Brain.{Memory,Model,Learn}

  import Scenic.Primitives
  require Axon
  import Nx.Defn

  @batch_size 150

  # Initial parameters for the game scene!
  def init(_arg, opts) do
    viewport = opts[:viewport]

    # Initializes the graph
    graph = Graph.build(theme: :dark)

    # Calculate the transform that centers the car in the viewport
    {:ok, %ViewPort.Status{size: {viewport_width, viewport_height}}} = ViewPort.info(viewport)

    # start a very simple animation timer
    {:ok, timer} = :timer.send_interval(60, :frame)

    # Start neural network
    {:ok, model_pid} = Model.start_link()

    # start memory
    {:ok, memory_pid} = Memory.start_link()

    # Init model params
    Model.model
    |> Axon.init()
    |> Model.push(model_pid)

    car_coords = {trunc(viewport_width / 2), trunc(viewport_height / 2)}
    goal_coords = {20,20}
    car_velocity = {6,0}

    state = %{
      viewport: viewport,
      viewport_width: viewport_width,
      viewport_height: viewport_height,
      graph: graph,
      frame_count: 0,
      model_pid: model_pid,
      model_fit: false,
      memory_pid: memory_pid,
      distance: Scenic.Math.Vector2.distance(car_coords, goal_coords),
      action: 0,
      reward: 0,
      objects: %{
        goal: %{coords: goal_coords},
        car: %{
          dimension: %{width: 20, height: 10},
          coords: car_coords,
          velocity: car_velocity,
          angle: 0,
          orientation: 0,
          orientation_rad: 0,
          orientation_grad: 0,
          signal: %{
            left: 0,
            center: 0,
            right: 0
          }
        }
      }
    }

    graph =
      graph
      |> draw_objects(state.objects)
      |> draw_vector(car_coords, goal_coords, :blue)

    state = put_in(state, [:graph], graph)

    IO.puts("\n")
    IO.puts("--STARTED--")

    {:ok, state, push: graph}
  end

  def handle_info(:frame, %{frame_count: frame_count} = state) do
    IO.puts("\n")

    sensor_center = Graph.get(state.graph, :sensor_center)
    %{transforms: %{translate: sensor_center}} = List.first(sensor_center)

    car_object = Graph.get(state.graph, :car)
    %{transforms: %{rotate: car_rotate, pin: car_coords}} = List.first(car_object)

    car_look_goal = Graph.get(state.graph, :base)
    %{data: {car_look_goal_from, car_look_goal_to}} = List.first(car_look_goal)

    car_look_forward = Graph.get(state.graph, :velocity)
    %{data: {car_look_forward_from, car_look_forward_to}} = List.first(car_look_forward)

    {car_x, car_y} = car_coords

    v_car_look_goal = Scenic.Math.Vector2.sub(car_look_goal_from, car_look_goal_to)
    v_car_look_goal_normalized = Scenic.Math.Vector2.normalize(v_car_look_goal)

    v_car_look_forward = Scenic.Math.Vector2.sub(car_look_forward_from, car_look_forward_to)
    v_car_look_forward_rotate = AutonomousCar.Math.Vector.rotate(v_car_look_forward, state.objects.car.angle)
    v_car_look_forward_normalized = Scenic.Math.Vector2.normalize(v_car_look_forward_rotate)

    orientation = Scenic.Math.Vector2.dot(v_car_look_goal_normalized, v_car_look_forward_normalized)
    orientation_rad = Math.acos(orientation)
    orientation_grad = (180 / :math.pi) * orientation_rad

    distance = Scenic.Math.Vector2.distance(car_coords, {20,20})

    signals =
      cond do
        car_x + 20 >= state.viewport_width -> {1,1,1}
        car_x <= 20 -> {1,1,1}
        car_y + 20 >= state.viewport_height -> {1,1,1}
        car_y <= 20 -> {1,1,1}
        true -> {0,0,0}
      end
    {signal_left, signal_center, signal_right} = signals

    state_final = [signal_left, signal_center, signal_right, orientation, -orientation]

    Memory.push(state.memory_pid, %{
      state_initial: [
        state.objects.car.signal.left,
        state.objects.car.signal.center,
        state.objects.car.signal.right,
        state.objects.car.orientation,
        -state.objects.car.orientation],
      action: state.action,
      reward: state.reward,
      state_final: state_final,
      frame_count: frame_count,
      distance: state.distance
    })

    IO.inspect(state_final, label: "State -> ")

    prob_actions =
      case state.model_fit do
        true ->
          if Nx.random_uniform(1) |> Nx.to_scalar <= 0.3 do
            Axon.predict(Model.model, Model.pull(state.model_pid), Nx.tensor(state_final))
          else
            get_random_values
          end
        _ -> get_random_values
      end

    IO.inspect(prob_actions, label: "Probs -> ")

    action =
      Nx.argmax(prob_actions)
      |> Nx.to_scalar()

    IO.puts("Action -> #{action}")

    state =
      state
      |> Car.update_angle(action)
      |> Car.move()

    {car_x, car_y} = state.objects.car.coords

    distance = Scenic.Math.Vector2.distance(state.objects.car.coords, state.objects.goal.coords)

    reward =
      case {car_x, car_y, distance} do
        {car_x, car_y, distance} when car_x <= 20 ->
          -1
        {car_x, car_y, distance} when car_x + 20 >= state.viewport_width ->
          -1
        {car_x, car_y, distance} when car_y <= 20 ->
          -1
        {car_x, car_y, distance} when car_y + 20 >= state.viewport_height ->
          -1
        {car_x, car_y, distance} when distance < state.distance ->
          0.4
        _ ->
          -0.5
      end

    IO.puts("Reward -> #{reward}")

    # ----------------------------------------------
    graph =
      Graph.build(theme: :dark)
      |> draw_objects(state.objects)
      |> draw_vector(sensor_center, state.objects.goal.coords, :blue)
      |> draw_model_fit(state.model_fit)
    # ----------------------------------------------

    model_fit = Learn.learning(state, @batch_size)

    # See if goal is get it
    goal_coords =
      cond do
        distance < 50 && state.objects.goal.coords == {20,20} ->
          {state.viewport_width - 20, state.viewport_height - 20}

        distance < 50 && state.objects.goal.coords != {20,20} ->
          {20,20}

        distance > 50 ->
          state.objects.goal.coords
      end

    new_state =
      state
      |> update_in([:frame_count], &(&1 + 1))
      |> put_in([:objects, :goal, :coords], goal_coords)
      |> put_in([:objects, :car, :signal, :left], signal_left)
      |> put_in([:objects, :car, :signal, :center], signal_center)
      |> put_in([:objects, :car, :signal, :right], signal_right)
      |> put_in([:objects, :car, :orientation], orientation)
      |> put_in([:objects, :car, :orientation_rad], orientation_rad)
      |> put_in([:objects, :car, :orientation_grad], orientation_grad)
      |> put_in([:action], action)
      |> put_in([:distance], distance)
      |> put_in([:reward], reward)
      |> put_in([:model_fit], model_fit)
      |> put_in([:graph], graph)

    {:noreply, new_state, push: graph}
  end

  defp get_random_values do
    Nx.random_uniform({3})
  end

  defp draw_vector(graph, from, to, color) do
    # graph |> line( {from, to}, stroke: {1, color}, cap: :round, id: :base )
    graph |> line( {from, to}, cap: :round, id: :base )
  end

  defp draw_model_fit(graph, model_fit) do
    if model_fit do
      graph |> circle(5, fill: :green, translate: {10,10})
    else
      graph |> circle(5, fill: :red, translate: {10,10})
    end
  end

  defp draw_objects(graph, object_map) do
    Enum.reduce(object_map, graph, fn {object_type, object_data}, graph ->
      draw_object(graph, object_type, object_data)
    end)
  end

  defp draw_object(graph, :goal, data) do
    %{coords: coords} = data
    graph |> circle(10, fill: :yellow, translate: coords)
  end

  defp draw_object(graph, :car, data) do
    %{width: width, height: height} = data.dimension

    {x, y} = data.coords

    angle_radians = data.angle |> degrees_to_radians

    new_graph =
      graph
      |> group(fn(g) ->
        g
        |> rect({width, height}, [fill: :white, translate: {x, y}])
        |> circle(4, fill: :red, translate: {x + 22, y - 5}, id: :sensor_left)
        |> circle(4, fill: :green, translate: {x + 28, y + 5}, id: :sensor_center)
        |> circle(4, fill: :blue, translate: {x + 22, y + 15}, id: :sensor_right)
        |> line({ {x + 28, y + 5}, {x + 28 + 10, y + 5} }, cap: :round, id: :velocity )
      end, rotate: angle_radians, pin: {x, y}, id: :car)
  end

  defp degrees_to_radians(angle) do
    angle * (Math.pi / 180)
  end
end
