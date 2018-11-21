defmodule Helix.MQ.Router do
  use GenServer

  @registry_name :mq_router

  def start_link,
    do: GenServer.start_link(__MODULE__, [], name: @registry_name)

  def subscribe(queue, callback),
    do: GenServer.cast(@registry_name, {:subscribe, queue, callback})

  def dispatch(queue, message),
    do: GenServer.cast(@registry_name, {:dispatch, queue, message})

  def init(_),
    do: {:ok, %{queues: %{}}}

  def handle_cast({:subscribe, queue, callback}, state) do
    queues = Map.put(state.queues, queue, callback)
    {:noreply, %{state| queues: queues}}
  end

  def handle_cast({:dispatch, queue, msg}, state) do
    case state.queues[queue] do
      callback when is_function(callback) ->
        spawn fn -> callback.(msg) end

      nil ->
        IO.puts "Unregistered queue: #{inspect queue}"
    end

    {:noreply, state}
  end
end
