defmodule Helix.Session.State.SSE.Monitor do

  use GenServer

  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Session.State.SSE, as: SSEState

  @registry_name :sse_monitor

  # def start_link(_) do
  #   GenServer.start_link(__MODULE__, [], name: @registry_name)
  # end

  def start_and_monitor(session_id, sse_name, conn_pid) do
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    GenServer.call(pid, {:save, session_id, sse_name, conn_pid})
  end

  @doc """
  If it's terminating, it's either because the SSE stream was closed or it ended
  abruptly (crashed). In either case, we have to remove the Conn PID from the
  SSEState and make sure this node is no longer listed at the Database as a SSE
  streaming endpoint.
  """
  def terminate(reason, state) do
    # Terminating
    IO.puts "Terminating"
    SSEState.remove(state.session_id)
    SessionAction.unlink_sse(state.session_id)
  end

  #

  def init(_) do
    Process.flag(:trap_exit, true)

    {:ok, %{}}
  end

  def handle_call({:save, session_id, sse_name, conn_pid}, _from, _state) do
    state =
      %{
        sse_name: sse_name,
        session_id: session_id,
        conn_pid: conn_pid
      }

    monitor_sse(state)

    {:reply, :ok, state}
  end

  def handle_info({:DOWN, _, _, _, _}, state) do
    :timer.sleep(Enum.random(10..99))

    monitor_sse(state)
    SSEState.put(state.session_id, state.conn_pid)

    {:noreply, state}
  end

  defp monitor_sse(state) do
    state
    |> get_sse_pid()
    |> Process.monitor()
  end

  defp get_sse_pid(%{sse_name: sse_name}),
    do: Process.whereis(sse_name)
end
