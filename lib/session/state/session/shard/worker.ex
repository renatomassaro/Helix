defmodule Helix.Session.State.Session.Shard.Worker do

  use GenServer

  alias Helix.Server.Model.Server

  @initial_state %{}

  @session_ttl 600_000  # 10m

  # Client API

  def start_link(shard_id) do
    GenServer.start_link(__MODULE__, [], name: shard_id)
  end

  def get(shard_id, session_id) do
    GenServer.call(shard_id, {:get, session_id})
  end

  def get_server(shard_id, session_id, server_id = %Server.ID{}),
    do: get_server(shard_id, session_id, to_string(server_id))
  def get_server(shard_id, session_id, server_id) do
    GenServer.call(shard_id, {:get_server, session_id, server_id})
  end

  def save(shard_id, session_id, session) do
    GenServer.call(shard_id, {:save, session_id, session})
  end

  def delete(shard_id, session_id) do
    GenServer.call(shard_id, {:delete, session_id})
  end

  # Callbacks

  def init(_),
    do: {:ok, @initial_state}

  def handle_call({:get, session_id}, _from, state) do
    result =
      case state[session_id] do
        session = %{} ->
          {:ok, session, %{}}

        nil ->
          {:error, :nxsession}
      end

    {:reply, result, state}
  end

  def handle_call({:get_server, session_id, server_id}, _from, state) do
    result =
      with \
        session = %{} <- state[session_id] || {:error, :nxsession},
        context = %{} <- session.servers[server_id] || {:error, :nxauth}
      do
        {:ok, session, context}
      else
        error = {:error, reason} ->
          error
      end

    {:reply, result, state}
  end

  def handle_call({:save, session_id, session}, _from, state) do
    Process.send_after(self(), {:reset, session_id}, @session_ttl)

    {:reply, :ok, Map.put(state, session_id, session)}
  end

  def handle_call({:delete, session_id}, _from, state) do
    {:reply, :ok, Map.drop(state, [session_id])}
  end

  def handle_info({:reset, session_id}, state) do
    {:noreply, Map.drop(state, [session_id])}
  end
end
