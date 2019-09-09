defmodule Helix.Session.State.Supervisor do

  use Supervisor

  alias Helix.Session.State.Session.Shard.Supervisor, as: SessionShardSupervisor
  alias Helix.Session.State.SSE.Shard.Supervisor, as: SSEShardSupervisor
  alias Helix.Session.State.SSE.PubSub, as: SSEPubSub

  @doc false
  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  @doc false
  def init(_) do
    children = [
      supervisor(SessionShardSupervisor, []),
      supervisor(SSEShardSupervisor, []),
      worker(SSEPubSub, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end