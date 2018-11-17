defmodule Helix.Session.State.SSE do

  alias Helix.Session.State.SSE.Shard, as: SSEShard

  def get(session_id),
    do: SSEShard.dispatch(session_id, :get, [session_id])

  def put(session_id, pid),
    do: SSEShard.dispatch(session_id, :put, [session_id, pid])

  def remove(session_id),
    do: SSEShard.dispatch(session_id, :remove, [session_id])

  def get_pid(session_id),
    do: SSEShard.dispatch(session_id, :get_pid, [])

  def get_process_name(session_id),
    do: SSEShard.get_shard_id(session_id)
end
