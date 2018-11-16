defmodule Helix.Session.State.Session do

  alias Helix.Session.State.Session.Shard, as: SessionShard

  def fetch(session_id),
    do: SessionShard.dispatch(session_id, :fetch, [session_id])

  def fetch_server(session_id, server_id) do
    SessionShard.dispatch(session_id, :fetch_server, [session_id, server_id])
  end

  def save(session_id, session),
    do: SessionShard.dispatch(session_id, :save, [session_id, session])
end
