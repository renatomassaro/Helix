defmodule Helix.Session.State.Supervisor do

  use Supervisor

  alias Helix.Session.State.Session.Shard.Supervisor, as: SessionShardSupervisor

  @doc false
  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  @doc false
  def init(_) do
    children = [
      supervisor(SessionShardSupervisor, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
