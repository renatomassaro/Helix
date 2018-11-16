defmodule Helix.Session.State.Session do

  use GenServer

  alias Helix.Server.Model.Server

  @registry_name :session_state

  @initial_state %{}

  # Client API

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @registry_name)
  end

  def fetch(session_id) do
    GenServer.call(@registry_name, {:fetch, session_id})
  end

  def fetch_server(session_id, server_id = %Server.ID{}),
    do: fetch_server(session_id, to_string(server_id))
  def fetch_server(session_id, server_id) do
    GenServer.call(@registry_name, {:fetch_server, session_id, server_id})
  end

  def save(session_id, session) do
    GenServer.call(@registry_name, {:save, session_id, session})
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
