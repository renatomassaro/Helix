defmodule Helix.Session.State.SSE.Shard.Worker do

  use GenServer

  def start_link(shard_id) do
    GenServer.start_link(__MODULE__, [], name: shard_id)
  end

  def get(shard_id, session_id) do
    IO.puts "getting on shard #{inspect shard_id} (#{inspect session_id})"
    GenServer.call(shard_id, {:get, session_id})
  end

  def get_all(shard_id) do
    GenServer.call(shard_id, :get_all)
  end

  def put(shard_id, session_id, pid) do
    IO.puts "putting on shard #{inspect shard_id} (#{inspect session_id})"
    GenServer.call(shard_id, {:put, session_id, pid})
  end

  def remove(shard_id, session_id) do
    GenServer.call(shard_id, {:remove, session_id})
  end

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

  def handle_call(:get_all, _from, state) do

    {:reply, state, state}
  end

  def handle_call({:put, session_id, pid}, _from, state) do
    IO.puts "Adding..."
    {:reply, :ok, Map.put(state, session_id, pid)}
  end

  def handle_call({:remove, session_id}, _from, state) do
    {:reply, :ok, Map.drop(state, [session_id])}
  end
end
