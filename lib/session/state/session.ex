defmodule Helix.Session.State.Session do

  alias Helix.Session.State.Session.Shard, as: SessionShard

  def get(session_id),
    do: SessionShard.dispatch(session_id, :get, [session_id])

  def get_server(session_id, server_id),
    do: SessionShard.dispatch(session_id, :get_server, [session_id, server_id])

  def save(session_id, session),
    do: SessionShard.dispatch(session_id, :save, [session_id, session])

  def delete(session_id),
    do: SessionShard.dispatch(session_id, :delete, [session_id])
end
