defmodule Helix.Session.State.Session.Shard.Worker do

  use GenServer

  alias Helix.Server.Model.Server

  @initial_state %{}

  # Client API

  def start_link(shard_id) do
    GenServer.start_link(__MODULE__, [], name: shard_id)
  end

  def fetch(shard_id, session_id) do
    IO.puts "fetching on shard #{inspect shard_id} (#{inspect session_id})"
    GenServer.call(shard_id, {:fetch, session_id})
  end

  def fetch_server(shard_id, session_id, server_id = %Server.ID{}),
    do: fetch_server(shard_id, session_id, to_string(server_id))
  def fetch_server(shard_id, session_id, server_id) do
    IO.puts "fetching s on shard #{inspect shard_id} (#{inspect session_id})"
    GenServer.call(shard_id, {:fetch_server, session_id, server_id})
  end

  def save(shard_id, session_id, session) do
    IO.puts "Saving on shard #{inspect shard_id}"
    GenServer.call(shard_id, {:save, session_id, session})
  end

  # Callbacks

  def init(_),
    do: {:ok, @initial_state}

  def handle_call({:fetch, session_id}, _from, state) do
    result =
      case state[session_id] do
        session = %{} ->
          {:ok, session, %{}}

        nil ->
          {:error, :nxsession}
      end

    {:reply, result, state}
  end

  def handle_call({:fetch_server, session_id, server_id}, _from, state) do
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
    {:reply, :ok, Map.put(state, session_id, session)}
  end
end
