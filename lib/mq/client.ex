defmodule Helix.MQ.Client do

  use GenServer

  @registry_name :mq_client

  def start_link,
    do: GenServer.start_link(__MODULE__, [], name: @registry_name)

  def publish(node_id, payload),
    do: GenServer.cast(@registry_name, {:publish, node_id, payload})

  def register_node(node_id, ip, port),
    do: GenServer.call(@registry_name, {:register_node, node_id, ip, port})
  def unregister_node(node_id, ip, port),
    do: GenServer.call(@registry_name, {:register_node, node_id, ip, port})

  def init(_),
    do: {:ok, %{}}

  def handle_call({:register_node, node_id, ip, port}, _, state) do
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary])
    node_info = %{socket: socket, ip: ip, port: port}

    {:reply, :ok, Map.put(state, node_id, node_info)}
  end

  def handle_call({:unregister_node, node_id}, _, state),
    do: {:reply, :ok, Map.drop(state, [node_id])}

  def handle_cast({:publish, node_id, payload}, state) do
    case state[node_id][:socket] do
      socket when is_port(socket) ->
        :gen_tcp.send(socket, payload)

      nil ->
        IO.puts "Node #{inspect node_id} not found."
    end

    {:noreply, state}
  end
end
