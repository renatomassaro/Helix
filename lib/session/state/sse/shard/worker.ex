defmodule Helix.Session.State.SSE.Shard.Worker do

  use GenServer

  def start_link(shard_id),
    do: GenServer.start_link(__MODULE__, [], name: shard_id)

  def get(shard_id, session_id),
    do: GenServer.call(shard_id, {:get, session_id})

  def put(shard_id, session_id, pid),
    do: GenServer.call(shard_id, {:put, session_id, pid})

  def remove(shard_id, session_id),
    do: GenServer.call(shard_id, {:remove, session_id})

  # Callbacks

  def init(_),
    do: {:ok, %{}}

  def handle_call({:get, session_id}, _from, state) do
    result =
      case state[session_id] do
        pid when is_pid(pid) ->
          {:ok, pid}

        nil ->
          {:error, :nxpid}
      end

    {:reply, result, state}
  end

  def handle_call({:put, session_id, pid}, _from, state),
    do: {:reply, :ok, Map.put(state, session_id, pid)}

  def handle_call({:remove, session_id}, _from, state),
    do: {:reply, :ok, Map.drop(state, [session_id])}
end