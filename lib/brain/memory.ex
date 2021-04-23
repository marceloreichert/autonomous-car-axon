defmodule AutonomousCar.Brain.Memory do
  use GenServer

  def init(pid) do
    {:ok, pid}
  end

  def handle_cast({:push, item}, state) do
    {:noreply, [item | state]}
  end

  def handle_call(:list, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:count, _from, state) do
    {:reply, Enum.count(state), state}
  end

  def handle_cast(:reset, state) do
    {:noreply, state = []}
  end

  # Public API
  def start_link() do
    GenServer.start_link(AutonomousCar.Brain.Memory, [])
  end

  def push(pid, item) do
    GenServer.cast(pid, {:push, item})
  end

  def list(pid) do
    GenServer.call(pid, :list)
  end

  def count(pid) do
    GenServer.call(pid, :count)
  end

  def reset(pid) do
    GenServer.cast(pid, :reset)
  end
end
