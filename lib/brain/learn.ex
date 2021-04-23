defmodule AutonomousCar.Brain.Learn do

  alias AutonomousCar.Brain.{Memory,Model}

  require Axon
  import Nx.Defn

  def learning(state, batch_size) do
    if Memory.count(state.memory_pid) != batch_size do
      state.model_fit
    else
      IO.inspect(label: "Training ->")

      memories =
        state.memory_pid
        |> Memory.list()
        |> Enum.shuffle

      train_samples = memories
        |> Enum.map(fn x -> x.state_initial end)
        |> Nx.tensor()
        |> Nx.to_batched_list(batch_size)

      train_labels = generate_train_labels(memories, state)
        |> Nx.tensor()
        |> Nx.to_batched_list(batch_size)

      params = Model.pull(state.model_pid)

      {new_params, _} =
        Model.model
        |> AutonomousCar.Brain.Training.step({params, Nx.tensor(0.0)}, :mean_squared_error, Axon.Optimizers.adamw(0.005))
        |> AutonomousCar.Brain.Training.train(train_samples, train_labels, epochs: 1)

      Model.push(new_params, state.model_pid)

      state.memory_pid |> Memory.reset()

      true
    end
  end

  defp generate_train_labels([], _), do: []

  defp generate_train_labels([mem | samples], state) do
    pred_initial = get_values(mem.state_initial, state) |> Nx.to_flat_list()
    vr = calc_r(mem.reward, 0.99, get_values(mem.state_final, state))
    labels = List.replace_at(pred_initial, mem.action, Nx.to_scalar(vr))
    [labels | generate_train_labels(samples, state)]
  end

  defp get_values(s, state) do
    inputs = Nx.tensor(s) |> Nx.new_axis(0)

    params = state.model_pid |> Model.pull
    Model.model |> Axon.predict(params, inputs)
  end

  defn calc_r(reward, gamma, values) do
    reward + (gamma * Nx.reduce_max(values))
  end
end
