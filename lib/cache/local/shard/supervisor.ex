defmodule Helix.Cache.Local.Shard.Supervisor do

  use Supervisor

  alias Helix.Cache.Local.Shard, as: CacheShard
  alias Helix.Cache.Local.Shard.Worker, as: CacheShardWorker

  @doc false
  def start_link,
    do: Supervisor.start_link(__MODULE__, [])

  @doc false
  def init(_) do
    CacheShard.get_shard_list()
    |> Enum.map(&(worker(CacheShardWorker, [&1], id: &1)))
    |> supervise(strategy: :one_for_one)
  end
end
