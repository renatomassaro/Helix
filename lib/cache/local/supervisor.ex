defmodule Helix.Cache.Local.Supervisor do

  use Supervisor

  alias Helix.Cache.Local.Shard.Supervisor, as: LocalCacheShardSupervisor

  @doc false
  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  @doc false
  def init(_) do
    children = [
      supervisor(LocalCacheShardSupervisor, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
