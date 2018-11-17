defmodule Helix.Session.State.SSE.API do

  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Session.State.SSE, as: SSEState
  alias Helix.Session.State.SSE.Monitor, as: SSEMonitor

  def fetch_sse(session_id) do
    SSEState.get(session_id)
  end

  def link_sse(session_id, node_name, conn_pid) do
    session_id
    |> SessionAction.link_sse(node_name)
    |> IO.inspect()

    SSEState.put(session_id, conn_pid)
    sse_name = SSEState.get_process_name(session_id)

    SSEMonitor.start_and_monitor(session_id, sse_name, conn_pid)
  end

  def close(session_id) do
    IO.puts "olarrr"

    session_id
    |> SSEState.get()
    |> elem(1)
    |> send(:close)
  end
end
