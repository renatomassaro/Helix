defmodule Helix.MQ.Protocol do

  use GenServer

  alias Helix.MQ

  @behaviour :ranch_protocol

  def start_link(ref, socket, transport, _opts) do
    pid = :proc_lib.spawn_link(__MODULE__, :init, [ref, socket, transport])
    {:ok, pid}
  end

  def init(ref, socket, transport) do
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [{:active, true}])
    :gen_server.enter_loop(
      __MODULE__, [], %{socket: socket, transport: transport}
    )
  end

  def handle_info({:tcp, _socket, payload}, state) do
    %{queue: queue, data: data} = Poison.decode!(payload)
    MQ.Router.dispatch(queue, data)

    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, state) do
    state.transport.close(socket)
    {:stop, :normal, state}
  end
end
