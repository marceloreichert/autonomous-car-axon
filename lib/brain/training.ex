defmodule AutonomousCar.Brain.Training do
  require Axon
  require Axon.Updates

  def step({params, _update_state}, objective_fn, {init_update_fn, update_fn})
      when is_function(objective_fn, 3) and is_function(init_update_fn, 1) and
      is_function(update_fn, 3) do
    optim_params = init_update_fn.(params)

    step_fn = fn model_state, input, target ->
      {params, update_state} = model_state

      {batch_loss, gradients} =
        Nx.Defn.Kernel.value_and_grad(params, &objective_fn.(&1, input, target))

      {updates, new_update_state} = update_fn.(gradients, update_state, params)
      {{Axon.Updates.apply_updates(params, updates), new_update_state}, batch_loss}
    end

    {{params, optim_params}, step_fn}
  end

  def step(%Axon{} = model, model_state, loss, optimizer) when is_function(loss, 2) do
    {_init_fn, predict_fn} = Axon.compile(model)

    objective_fn = fn params, input, target ->
      preds = predict_fn.(params, input)
      loss.(target, preds)
    end

    step(model_state, objective_fn, optimizer)
  end

  def step(%Axon{} = model, model_state, loss, optimizer) when is_atom(loss) do
    loss_fn = &apply(Axon.Losses, loss, [&1, &2, [reduction: :mean]])
    step(model, model_state, loss_fn, optimizer)
  end

  def train({model_state, step_fn}, inputs, targets, opts \\ []) do
    epochs = opts[:epochs] || 5
    compiler = opts[:compiler] || Nx.Defn.Evaluator

    for epoch <- 1..epochs, reduce: model_state do
      model_state ->
        {time, {model_state, avg_loss}} =
          :timer.tc(&train_epoch/6, [
            step_fn,
            model_state,
            inputs,
            targets,
            compiler,
            epoch
          ])

        epoch_avg_loss =
          avg_loss
          |> Nx.backend_transfer()
          |> Nx.to_scalar()

        IO.puts("\n")
        IO.puts("Epoch #{epoch} Time: #{time / 1_000_000}s")
        IO.puts("Epoch #{epoch} Loss: #{epoch_avg_loss}")
        model_state
    end
  end

  ## Helpers

  defp train_epoch(step_fn, model_state, inputs, targets, compiler, epoch) do
    total_batches = Enum.count(inputs)

    dataset =
      inputs
      |> Enum.zip(targets)
      |> Enum.with_index()

    for {{inp, tar}, i} <- dataset, reduce: {model_state, Nx.tensor(0.0)} do
      {model_state, state} ->
        {model_state, batch_loss} =
          Nx.Defn.jit(step_fn, [model_state, inp, tar], compiler: compiler)

        avg_loss =
          state
          |> Nx.multiply(i)
          |> Nx.add(Nx.backend_transfer(batch_loss))
          |> Nx.divide(i + 1)

        IO.write(
          "\rEpoch #{epoch}, batch #{i + 1} of #{total_batches} - " <>
            "Average Loss: #{Nx.to_scalar(avg_loss)}"
        )

        {model_state, avg_loss}
    end
  end
end
