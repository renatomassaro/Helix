defmodule Helix.Cache.Local.Shard.Worker do

  use GenServer

  @initial_state %{
    server: %{},
    tunnel: %{},
    connection: %{},
    entity: %{},
    entity_server: %{}
  }

  @objects [:server, :tunnel, :connection]
  @object_timeout %{
    server: 10 * 60_000,
    tunnel: 25 * 60_000,
    connection: 25 * 60_000
  }

  # Client

  def start_link(shard_id),
    do: GenServer.start_link(__MODULE__, [], name: shard_id)

  for type <- @objects do
    def unquote(:"get_#{type}")(shard_id, object_id),
      do: GenServer.call(shard_id, {:get, unquote(type), to_string(object_id)})

    def unquote(:"put_#{type}")(shard_id, object_id, nil),
      do: unquote(:"put_#{type}")(shard_id, object_id, :nx)
    def unquote(:"put_#{type}")(shard_id, object_id, object) do
      GenServer.cast(
        shard_id, {:put, unquote(type), to_string(object_id), object}
      )
    end
  end

  # Server

  def init(_),
    do: {:ok, @initial_state}

  def handle_call({:get, type, object_id}, _, state) do
    {:reply, state[type][object_id], state}
  end

  def handle_cast({:put, type, object_id, object}, state) do
    new_state =
      Map.replace!(
        state,
        type,
        Map.put(state[type], object_id, object)
      )

    pid = self()
    spawn fn ->
      Process.send_after(pid, {:clear, type, object_id}, get_timeout(type))
    end

    {:noreply, new_state}
  end

  def handle_info({:clear, type, object_id}, state) do
    new_state = Map.replace!(state, type, Map.drop(state[type], [object_id]))
    {:noreply, new_state}
  end

  defp get_timeout(type),
    do: @object_timeout[type]
end
