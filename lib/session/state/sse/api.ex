defmodule Helix.Session.State.SSE.API do

  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Session.Query.Session, as: SessionQuery
  alias Helix.Session.State.SSE, as: SSEState
  alias Helix.Session.State.SSE.Monitor, as: SSEMonitor

  defdelegate fetch_sse(session_id),
    to: SSEState,
    as: :get

  defdelegate get_all(merge_opts),
    to: SSEState

  defdelegate put(session_id, conn_pid),
    to: SSEState

  defdelegate remove(session_id),
    to: SSEState

  def has_sse_active?(session_id) do
    case fetch_sse(session_id) do
      {:ok, _pid} ->
        true

      {:error, :nxpid} ->
        SessionQuery.is_sse_active?(session_id)
    end
  end

  def link_sse(session_id, node_name, conn_pid) do
    SessionAction.link_sse(session_id, node_name)

    put(session_id, conn_pid)
  end

  defdelegate get_process_name(session_id),
    to: SSEState
end
